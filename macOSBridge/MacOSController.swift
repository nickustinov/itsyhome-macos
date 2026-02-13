//
//  MacOSController.swift
//  macOSBridge
//
//  Main controller for the macOS menu bar
//

import Foundation
import AppKit
import Combine

final class StayOpenMenu: NSMenu {

    var isTrackingSuspended = false

    override func cancelTracking() {
        if isTrackingSuspended {
            return
        }
        super.cancelTracking()
    }
}

@objc(MacOSController)
public class MacOSController: NSObject, iOS2Mac, NSMenuDelegate, PlatformPickerDelegate, SmartHomePlatformDelegate {

    // MARK: - Properties

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = StayOpenMenu()
    var menuBuilder: MenuBuilder!
    var actionEngine: ActionEngine!
    var currentMenuData: MenuData?
    var menuIsOpen = false
    var needsRebuild = false
    private var proStatusCancellable: AnyCancellable?
    var pinnedStatusItems: [String: PinnedStatusItem] = [:]
    private let cameraPanelManager = CameraPanelManager()
    private var platformPickerController: PlatformPickerWindowController?
    private var homeAssistantPlatform: HomeAssistantPlatform?
    private var homeAssistantBridge: HomeAssistantBridge?
    private var lastErrorMessage: String?
    private var lastErrorTime: Date?

    @objc public weak var iOSBridge: Mac2iOS?

    /// Returns the appropriate bridge based on the selected platform
    var activeBridge: Mac2iOS? {
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            return homeAssistantBridge
        }
        return iOSBridge
    }

    // MARK: - Initialization

    @objc public required override init() {
        super.init()
        StartupLogger.log("MacOSController init start")
        menuBuilder = MenuBuilder(bridge: nil)
        actionEngine = ActionEngine(bridge: nil)
        cameraPanelManager.delegate = self
        setupStatusItem()
        StartupLogger.log("Status item created")
        setupMenu()
        StartupLogger.log("Initial menu set up")
        setupNotifications()
        swizzleCatalystWindowOrdering()
        Task { @MainActor in _ = ProManager.shared }
        StartupLogger.log("MacOSController init complete")

        // Show platform picker if needed
        if PlatformManager.shared.needsOnboarding {
            DispatchQueue.main.async { [weak self] in
                self?.showPlatformPicker()
            }
        }
    }

    private func showPlatformPicker() {
        platformPickerController = PlatformPickerWindowController()
        platformPickerController?.delegate = self
        platformPickerController?.showWindow(nil)
    }

    // MARK: - PlatformPickerDelegate

    func platformPickerDidSelectHomeKit() {
        StartupLogger.log("User selected HomeKit")
        PlatformManager.shared.selectHomeKit()
        platformPickerController = nil
        // Restart to initialize HomeKit (it was skipped at startup when platform was .none)
        restartApp()
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", path]
        task.launch()
        NSApp.terminate(nil)
    }

    func platformPickerDidSelectHomeAssistant() {
        StartupLogger.log("User selected Home Assistant")
        PlatformManager.shared.selectHomeAssistant()
        platformPickerController = nil
        // Show settings to configure Home Assistant, navigate to HA section
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.openSettings(nil)
            // Navigate to Home Assistant section (index 1 when HA is selected)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: SettingsView.navigateToSectionNotification,
                    object: nil,
                    userInfo: ["index": 1]
                )
                // Focus the server URL field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HomeAssistantSectionFocusServerURL"),
                        object: nil
                    )
                }
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalCharacteristicChange(_:)),
            name: .characteristicDidChangeLocally,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHomeAssistantCredentialsChanged),
            name: NSNotification.Name("HomeAssistantCredentialsChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlatformDidChange),
            name: .platformDidChange,
            object: nil
        )

        HotkeyManager.shared.onHotkeyTriggered = { [weak self] favouriteId in
            self?.handleHotkeyForFavourite(favouriteId)
        }

        // Re-check camera status when Pro status changes
        Task { @MainActor in
            proStatusCancellable = ProManager.shared.$isPro
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateCameraStatusVisibility()
                }
        }

        // Connect to Home Assistant if already configured
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            if HAAuthManager.shared.isConfigured {
                connectToHomeAssistant()
            } else {
                // HA selected but not configured - open settings to configure
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.openSettingsToHomeAssistant()
                }
            }
        }
    }

    /// Swizzle makeKeyAndOrderFront: on NSWindow so the hidden 1×1 Catalyst
    /// window is never ordered into the window list. Mission Control only shows
    /// ordered windows, so this prevents the phantom empty window when
    /// "Group windows by application" is enabled.
    private func swizzleCatalystWindowOrdering() {
        let original = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.makeKeyAndOrderFront(_:)))
        let replacement = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.itsyhome_makeKeyAndOrderFront(_:)))
        if let original, let replacement {
            method_exchangeImplementations(original, replacement)
        }
    }

    private func openSettingsToHomeAssistant() {
        openSettings(nil)
        // Navigate to Home Assistant section
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: SettingsView.navigateToSectionNotification,
                object: nil,
                userInfo: ["index": 1]
            )
            // Focus the server URL field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("HomeAssistantSectionFocusServerURL"),
                    object: nil
                )
            }
        }
    }

    @objc private func handleHomeAssistantCredentialsChanged() {
        if HAAuthManager.shared.isConfigured {
            connectToHomeAssistant()
        } else {
            disconnectFromHomeAssistant()
        }
    }

    @objc private func handlePlatformDidChange() {
        updateStatusItemIcon()
        setupMenu()  // Refresh menu for the new platform
    }

    private func connectToHomeAssistant() {
        guard PlatformManager.shared.selectedPlatform == .homeAssistant else { return }
        guard HAAuthManager.shared.isConfigured else { return }

        StartupLogger.log("Connecting to Home Assistant...")

        if homeAssistantPlatform == nil {
            homeAssistantPlatform = HomeAssistantPlatform()
            homeAssistantPlatform?.delegate = self
            homeAssistantBridge = HomeAssistantBridge(platform: homeAssistantPlatform!)
        }

        Task {
            do {
                try await homeAssistantPlatform?.connect()
                StartupLogger.log("Connected to Home Assistant")
            } catch {
                StartupLogger.error("Failed to connect to Home Assistant: \(error)")
                await MainActor.run {
                    showError(message: "Failed to connect to Home Assistant: \(error.localizedDescription)")
                }
            }
        }
    }

    private func disconnectFromHomeAssistant() {
        homeAssistantPlatform?.disconnect()
        homeAssistantPlatform = nil
        homeAssistantBridge = nil
        StartupLogger.log("Disconnected from Home Assistant")
    }

    // MARK: - SmartHomePlatformDelegate

    public func platformDidUpdateMenuData(_ platform: SmartHomePlatform, jsonString: String) {
        StartupLogger.log("Received menu data from \(platform.platformType) (\(jsonString.count) chars)")
        // Bypass the HomeKit check - this is from Home Assistant
        processMenuJSON(jsonString)
    }

    public func platformDidUpdateCharacteristic(_ platform: SmartHomePlatform, identifier: UUID, value: Any) {
        updateCharacteristic(identifier: identifier, value: value)
    }

    public func platformDidUpdateReachability(_ platform: SmartHomePlatform, accessoryIdentifier: UUID, isReachable: Bool) {
        setReachability(accessoryIdentifier: accessoryIdentifier, isReachable: isReachable)
    }

    public func platformDidEncounterError(_ platform: SmartHomePlatform, message: String) {
        // Check for alarm code errors - notify UI to handle gracefully
        if message.lowercased().contains("alarm code") || message.lowercased().contains("invalid") && message.lowercased().contains("code") {
            NotificationCenter.default.post(name: .alarmCommandFailed, object: nil, userInfo: ["message": message])
            return  // Don't show generic error dialog for alarm code issues
        }
        showError(message: message)
    }

    public func platformDidDisconnect(_ platform: SmartHomePlatform) {
        // Reset menu to loading state without showing a popup
        DispatchQueue.main.async { [weak self] in
            self?.currentMenuData = nil
            self?.setupMenu()  // This will show "Loading Home Assistant..."
        }
    }

    public func platformDidReceiveDoorbellEvent(_ platform: SmartHomePlatform, cameraIdentifier: UUID) {
        showCameraPanelForDoorbell(cameraIdentifier: cameraIdentifier)
    }

    // MARK: - Platform-agnostic action helpers

    func executeScene(identifier: UUID) {
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            homeAssistantPlatform?.executeScene(identifier: identifier)
        } else {
            iOSBridge?.executeScene(identifier: identifier)
        }
    }

    func readCharacteristic(identifier: UUID) {
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            homeAssistantPlatform?.readCharacteristic(identifier: identifier)
        } else {
            iOSBridge?.readCharacteristic(identifier: identifier)
        }
    }

    func writeCharacteristic(identifier: UUID, value: Any) {
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            homeAssistantPlatform?.writeCharacteristic(identifier: identifier, value: value)
        } else {
            iOSBridge?.writeCharacteristic(identifier: identifier, value: value)
        }
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            return homeAssistantPlatform?.getCharacteristicValue(identifier: identifier)
        } else {
            return iOSBridge?.getCharacteristicValue(identifier: identifier)
        }
    }

    private func updateCameraStatusVisibility() {
        guard let data = currentMenuData else { return }
        let camerasEnabled = PreferencesManager.shared.camerasEnabled
        let isPro = ProStatusCache.shared.isPro
        let shouldShow = data.hasCameras && camerasEnabled && isPro
        cameraPanelManager.setupCameraStatusItem(hasCameras: shouldShow)
    }

    @objc private func handleLocalCharacteristicChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let characteristicId = userInfo["characteristicId"] as? UUID,
              let value = userInfo["value"] else {
            return
        }
        updateMenuItems(for: characteristicId, value: value, isLocalChange: true)
    }

    @objc private func preferencesDidChange() {
        // Immediately update camera status item visibility
        if let data = currentMenuData {
            let camerasEnabled = PreferencesManager.shared.camerasEnabled
            let shouldShow = data.hasCameras && camerasEnabled && ProStatusCache.shared.isPro
            if !shouldShow {
                cameraPanelManager.dismissCameraPanel()
            }
            cameraPanelManager.setupCameraStatusItem(hasCameras: shouldShow)
        }

        // Update pinned status items
        syncPinnedStatusItems()

        if menuIsOpen {
            needsRebuild = true
            return
        }
        if let data = currentMenuData {
            rebuildMenu(with: data)
        }
        HotkeyManager.shared.registerShortcuts()
    }

    private func setupStatusItem() {
        statusItem.autosaveName = "com.itsyhome.main"
        updateStatusItemIcon()
        statusItem.menu = mainMenu
        mainMenu.delegate = self
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem.button else { return }
        let pluginBundle = Bundle(for: MacOSController.self)

        // Use HA icon when Home Assistant is selected, otherwise use HomeKit icon
        let iconName = PlatformManager.shared.selectedPlatform == .homeAssistant ? "HAMenuBarIcon" : "MenuBarIcon"

        if let icon = pluginBundle.image(forResource: iconName) {
            icon.isTemplate = true
            button.image = icon
        } else {
            button.image = PhosphorIcon.fill("house")
        }
    }

    private func setupMenu() {
        mainMenu.removeAllItems()

        let loadingText: String
        switch PlatformManager.shared.selectedPlatform {
        case .homeAssistant:
            loadingText = "Connecting to Home Assistant..."
        case .homeKit:
            loadingText = "Loading HomeKit..."
        case .none:
            loadingText = "Select a platform in Settings..."
        }

        let loadingItem = NSMenuItem(title: loadingText, action: nil, keyEquivalent: "")
        loadingItem.isEnabled = false
        mainMenu.addItem(loadingItem)

        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()
    }

    // MARK: - iOS2Mac Protocol

    @objc public func reloadMenuWithJSON(_ jsonString: String) {
        // This method is called by HomeKit via iOS2Mac protocol
        // Ignore HomeKit data if Home Assistant is selected
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            StartupLogger.log("Ignoring HomeKit JSON (\(jsonString.count) chars) - Home Assistant is selected")
            return
        }

        StartupLogger.log("Received HomeKit JSON (\(jsonString.count) chars)")
        processMenuJSON(jsonString)
    }

    /// Process menu JSON from either HomeKit or Home Assistant
    private func processMenuJSON(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            StartupLogger.error("Failed to convert JSON string to data")
            return
        }

        do {
            let menuData = try JSONDecoder().decode(MenuData.self, from: jsonData)
            StartupLogger.log("Decoded: \(menuData.homes.count) homes, \(menuData.rooms.count) rooms, \(menuData.accessories.count) accessories, \(menuData.scenes.count) scenes")
            DispatchQueue.main.async {
                self.rebuildMenu(with: menuData)
            }
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                StartupLogger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                StartupLogger.error("Type mismatch for \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                StartupLogger.error("Value not found for \(type): \(context.debugDescription)")
            case .dataCorrupted(let context):
                StartupLogger.error("Data corrupted: \(context.debugDescription)")
            @unknown default:
                StartupLogger.error("Unknown decoding error: \(decodingError)")
            }
        } catch {
            StartupLogger.error("Failed to decode menu JSON: \(error)")
        }
    }

    @objc public func updateCharacteristic(identifier: UUID, value: Any) {
        DispatchQueue.main.async {
            self.updateMenuItems(for: identifier, value: value, isLocalChange: false)
        }
    }

    @objc public func setReachability(accessoryIdentifier: UUID, isReachable: Bool) {
        DispatchQueue.main.async {
            self.updateAccessoryReachability(accessoryIdentifier, isReachable: isReachable)
        }
    }

    @objc public func showError(message: String) {
        StartupLogger.error("showError called: \(message)")

        // Rate-limit: don't show same error again within 60 seconds
        let now = Date()
        if let lastMsg = lastErrorMessage, let lastTime = lastErrorTime,
           lastMsg == message, now.timeIntervalSince(lastTime) < 60 {
            return
        }
        lastErrorMessage = message
        lastErrorTime = now

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Itsyhome error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc public func executeCommand(_ command: String) -> Bool {
        guard ProStatusCache.shared.isPro else {
            DispatchQueue.main.async {
                self.showProRequiredAlert()
            }
            return false
        }

        switch ActionParser.parse(command) {
        case .success(let parsed):
            let result = actionEngine.execute(target: parsed.target, action: parsed.action)
            return result == .success
        case .failure:
            return false
        }
    }

    @objc public func configureCameraPanel() {
        // No longer used — macOS side polls instead
    }

    @objc public func resizeCameraPanel(width: CGFloat, height: CGFloat, aspectRatio: CGFloat, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraPanelManager.resizeCameraPanel(width: width, height: height, aspectRatio: aspectRatio, animated: animated)
        }
    }

    @objc public func setCameraPanelPinned(_ pinned: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraPanelManager.setCameraPinned(pinned)
        }
    }

    @objc public func notifyStreamStarted(cameraIdentifier: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraPanelManager.setActiveCameraId(cameraIdentifier)
        }
    }

    @objc public func dismissCameraPanel() {
        DispatchQueue.main.async { [weak self] in
            self?.cameraPanelManager.dismissCameraPanel()
        }
    }

    @objc public func showCameraPanelForDoorbell(cameraIdentifier: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  ProStatusCache.shared.isPro,
                  PreferencesManager.shared.camerasEnabled else { return }

            if PreferencesManager.shared.doorbellSound {
                NSSound(named: "Glass")?.play()
            }

            guard PreferencesManager.shared.doorbellNotifications else { return }
            self.cameraPanelManager.showForDoorbell()
        }
    }

    private func showProRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Itsyhome Pro required"
        alert.informativeText = "Deeplinks are a Pro feature. Upgrade to Itsyhome Pro to control your devices from Shortcuts, Alfred, and other automation tools."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Upgrade")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            SettingsWindowController.shared.showWindow(nil)
            SettingsWindowController.shared.selectTab(index: 2) // Pro tab
        }
    }

    // MARK: - Menu Building

    func rebuildMenu(with data: MenuData) {
        StartupLogger.log("rebuildMenu start — \(data.rooms.count) rooms, \(data.accessories.count) accessories, \(data.scenes.count) scenes")
        currentMenuData = data
        mainMenu.removeAllItems()

        PreferencesManager.shared.currentHomeId = data.selectedHomeId
        PreferencesManager.shared.currentHomeName = data.homes.first(where: { $0.uniqueIdentifier == data.selectedHomeId })?.name
        CloudSyncManager.shared.updateMenuData(data)
        HotkeyManager.shared.registerShortcuts()

        menuBuilder.bridge = activeBridge
        StartupLogger.log("Building menu items...")
        menuBuilder.buildMenu(into: mainMenu, with: data)
        StartupLogger.log("Menu items built — \(mainMenu.items.count) items")

        actionEngine.bridge = activeBridge
        actionEngine.updateMenuData(data)
        actionEngine.onCharacteristicWrite = { [weak self] characteristicId, value in
            self?.updateMenuItems(for: characteristicId, value: value, isLocalChange: true)
        }

        WebhookServer.shared.configure(actionEngine: actionEngine)
        WebhookServer.shared.rebuildCharacteristicIndex(from: data)
        let camerasEnabled = PreferencesManager.shared.camerasEnabled
        let isPro = ProStatusCache.shared.isPro
        let shouldShow = data.hasCameras && camerasEnabled && isPro
        cameraPanelManager.setupCameraStatusItem(hasCameras: shouldShow)

        // Broadcast camera data for CameraViewController (HA mode)
        NSLog("[CameraDebug] MacOSController: platform=%@ cameras=%d hasCameras=%d camerasEnabled=%d isPro=%d shouldShow=%d",
              PlatformManager.shared.selectedPlatform == .homeAssistant ? "HA" : "HK",
              data.cameras.count, data.hasCameras ? 1 : 0, camerasEnabled ? 1 : 0, isPro ? 1 : 0, shouldShow ? 1 : 0)
        if PlatformManager.shared.selectedPlatform == .homeAssistant && !data.cameras.isEmpty {
            NSLog("[CameraDebug] MacOSController: posting HACameraDataUpdated with %d cameras", data.cameras.count)

            // Encode as JSON — CameraData is compiled into separate modules so direct type casting won't work
            if let camerasJSON = try? JSONEncoder().encode(data.cameras),
               let menuDataJSON = try? JSONEncoder().encode(data) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("HACameraDataUpdated"),
                    object: nil,
                    userInfo: ["camerasJSON": camerasJSON, "menuDataJSON": menuDataJSON]
                )
            }
        }

        // Update pinned status items
        StartupLogger.log("Syncing pinned status items...")
        syncPinnedStatusItems()
        StartupLogger.log("Pinned items synced — \(pinnedStatusItems.count) items")

        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()

        refreshCharacteristics()
        StartupLogger.log("rebuildMenu complete")
    }

    private func addFooterItems() {
        if let data = currentMenuData, data.homes.count > 1 {
            addHomeSelector(homes: data.homes, selectedId: data.selectedHomeId)
        }

        let settingsIcon = PhosphorIcon.regular("gear")
        let settingsItem = menuBuilder.createActionItem(title: "Settings...", icon: settingsIcon) { [weak self] in
            self?.openSettings(nil)
        }
        mainMenu.addItem(settingsItem)

        mainMenu.addItem(NSMenuItem.separator())

        let refreshIcon = PhosphorIcon.regular("arrows-clockwise")
        let refreshItem = menuBuilder.createActionItem(title: "Refresh", icon: refreshIcon) { [weak self] in
            self?.refreshHomeKit(nil)
        }
        mainMenu.addItem(refreshItem)

        let quitItem = menuBuilder.createActionItem(title: "Quit", icon: nil) { [weak self] in
            self?.quit(nil)
        }
        mainMenu.addItem(quitItem)
    }

    private func addHomeSelector(homes: [HomeData], selectedId: String?) {
        let homeIcon = PhosphorIcon.regular("house")
        let homeItem = menuBuilder.createSubmenuItem(title: "Home", icon: homeIcon)

        let submenu = StayOpenMenu()
        for home in homes {
            let isSelected = home.uniqueIdentifier == selectedId
            let icon: NSImage? = isSelected ? PhosphorIcon.check : PhosphorIcon.icon("house", filled: home.isPrimary)
            let item = menuBuilder.createActionItem(title: home.name, icon: icon) { [weak self] in
                if let uuid = UUID(uuidString: home.uniqueIdentifier) {
                    SettingsWindowController.shared.close()
                    self?.iOSBridge?.selectedHomeIdentifier = uuid
                }
            }
            submenu.addItem(item)
        }
        homeItem.submenu = submenu
        mainMenu.addItem(homeItem)
    }

    // MARK: - Actions

    @objc private func selectHome(_ sender: NSMenuItem) {
        if let uuidString = sender.representedObject as? String, let uuid = UUID(uuidString: uuidString) {
            SettingsWindowController.shared.close()
            iOSBridge?.selectedHomeIdentifier = uuid
        }
    }

    @objc private func openSettings(_ sender: Any?) {
        cameraPanelManager.dismissCameraPanel()
        if let data = currentMenuData {
            SettingsWindowController.shared.configure(with: data)
        }
        SettingsWindowController.shared.showWindow(nil)
    }

    @objc private func refreshHomeKit(_ sender: Any?) {
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            // Reconnect if disconnected, otherwise just reload
            if homeAssistantPlatform?.isConnected == true {
                homeAssistantPlatform?.reloadData()
            } else {
                connectToHomeAssistant()
            }
        } else {
            iOSBridge?.reloadHomeKit()
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        if menu == mainMenu {
            menuIsOpen = true
            if cameraPanelManager.isPanelVisible && !cameraPanelManager.isPinned {
                cameraPanelManager.dismissCameraPanel()
            }
            // Close any open thermostat popovers
            NotificationCenter.default.post(name: PinnedStatusItem.closeAllPanelsNotification, object: nil)
            refreshCharacteristics()
        }
    }

    public func menuDidClose(_ menu: NSMenu) {
        if menu == mainMenu {
            menuIsOpen = false
            if needsRebuild {
                needsRebuild = false
                if let data = currentMenuData {
                    rebuildMenu(with: data)
                }
                HotkeyManager.shared.registerShortcuts()
            }
        }
    }
}

// MARK: - PinnedStatusItemDelegate

extension MacOSController: PinnedStatusItemDelegate {
    func pinnedStatusItemNeedsMenuBuilder(_ item: PinnedStatusItem) -> MenuBuilder? {
        return menuBuilder
    }

    func pinnedStatusItemNeedsMenuData(_ item: PinnedStatusItem) -> MenuData? {
        return currentMenuData
    }

    func pinnedStatusItem(_ item: PinnedStatusItem, readCharacteristic characteristicId: UUID) {
        readCharacteristic(identifier: characteristicId)
    }

    func pinnedStatusItem(_ item: PinnedStatusItem, getCachedValue characteristicId: UUID) -> Any? {
        return getCharacteristicValue(identifier: characteristicId)
    }
}

// MARK: - CameraPanelManagerDelegate

extension MacOSController: CameraPanelManagerDelegate {
    func cameraPanelManagerOpenCameraWindow(_ manager: CameraPanelManager) {
        activeBridge?.openCameraWindow()
    }

    func cameraPanelManagerSetCameraWindowHidden(_ manager: CameraPanelManager, hidden: Bool) {
        activeBridge?.setCameraWindowHidden(hidden)
    }
}

// MARK: - Swizzled window ordering

extension NSWindow {
    @objc func itsyhome_makeKeyAndOrderFront(_ sender: Any?) {
        // Block the hidden 1×1 Catalyst window from being ordered into the
        // window list. This prevents Mission Control from showing it as an
        // empty phantom window when "Group windows by application" is on.
        if frame.size.width <= 1 || frame.size.height <= 1 {
            return
        }
        // Calls through to the original (swapped) implementation
        itsyhome_makeKeyAndOrderFront(sender)
    }
}
