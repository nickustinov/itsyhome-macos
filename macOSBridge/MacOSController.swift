//
//  MacOSController.swift
//  macOSBridge
//
//  Main controller for the macOS menu bar
//

import Foundation
import AppKit

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
public class MacOSController: NSObject, iOS2Mac, NSMenuDelegate {

    // MARK: - Properties

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var cameraStatusItem: NSStatusItem?
    let mainMenu = StayOpenMenu()
    private var menuBuilder: MenuBuilder!
    private var actionEngine: ActionEngine!
    private var currentMenuData: MenuData?
    private var menuIsOpen = false
    private var needsRebuild = false
    private var clickOutsideMonitor: Any?
    private var localClickMonitor: Any?
    private var cameraPanelWindow: NSWindow?
    private var cameraPanelSize: NSSize = NSSize(width: 300, height: 300)
    private var isCameraPanelOpening = false
    private var pendingCameraPanelShow = false

    @objc public weak var iOSBridge: Mac2iOS?

    // MARK: - Initialization

    @objc public required override init() {
        super.init()
        menuBuilder = MenuBuilder(bridge: nil)
        actionEngine = ActionEngine(bridge: nil)
        setupStatusItem()
        setupMenu()
        setupNotifications()
        Task { @MainActor in _ = ProManager.shared }
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

        HotkeyManager.shared.onHotkeyTriggered = { [weak self] favouriteId in
            self?.handleHotkeyForFavourite(favouriteId)
        }
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
                dismissCameraPanel()
            }
            setupCameraStatusItem(hasCameras: shouldShow)
        }

        if menuIsOpen {
            needsRebuild = true
            return
        }
        if let data = currentMenuData {
            rebuildMenu(with: data)
        }
        HotkeyManager.shared.registerShortcuts()
    }

    private func handleHotkeyForFavourite(_ favouriteId: String) {
        guard let data = currentMenuData else { return }

        if let scene = data.scenes.first(where: { $0.uniqueIdentifier == favouriteId }),
           let sceneUUID = UUID(uuidString: scene.uniqueIdentifier) {
            iOSBridge?.executeScene(identifier: sceneUUID)
            return
        }

        if let group = PreferencesManager.shared.deviceGroups.first(where: { $0.id == favouriteId }) {
            for service in group.resolveServices(in: data) {
                toggleService(service)
            }
            return
        }

        for accessory in data.accessories {
            for service in accessory.services {
                if service.uniqueIdentifier == favouriteId {
                    toggleService(service)
                    return
                }
            }
        }
    }

    private func toggleService(_ service: ServiceData) {
        if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Bool ?? false
            iOSBridge?.writeCharacteristic(identifier: id, value: !current)
            return
        }

        if let idString = service.activeId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 0
            iOSBridge?.writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0)
            return
        }

        if let idString = service.lockTargetStateId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 1
            iOSBridge?.writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0)
            return
        }

        if let idString = service.targetPositionId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 0
            iOSBridge?.writeCharacteristic(identifier: id, value: current > 50 ? 0 : 100)
            return
        }

        if let idString = service.targetDoorStateId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 1
            iOSBridge?.writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0)
            return
        }

        if let idString = service.targetHeatingCoolingStateId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 0
            iOSBridge?.writeCharacteristic(identifier: id, value: current == 0 ? 3 : 0)
            return
        }

        if let idString = service.brightnessId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 0
            iOSBridge?.writeCharacteristic(identifier: id, value: current > 0 ? 0 : 100)
            return
        }

        if let idString = service.securitySystemTargetStateId, let id = UUID(uuidString: idString) {
            let current = iOSBridge?.getCharacteristicValue(identifier: id) as? Int ?? 3
            iOSBridge?.writeCharacteristic(identifier: id, value: current == 3 ? 0 : 3)
            return
        }
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            let pluginBundle = Bundle(for: MacOSController.self)
            if let icon = pluginBundle.image(forResource: "MenuBarIcon") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "house.fill", accessibilityDescription: "Itsyhome")
            }
        }
        statusItem.menu = mainMenu
        mainMenu.delegate = self
    }

    private func setupMenu() {
        mainMenu.removeAllItems()

        let loadingItem = NSMenuItem(title: "Loading HomeKit...", action: nil, keyEquivalent: "")
        loadingItem.isEnabled = false
        mainMenu.addItem(loadingItem)

        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()
    }

    // MARK: - iOS2Mac Protocol

    @objc public func reloadMenuWithJSON(_ jsonString: String) {
        print("Received JSON (\(jsonString.count) chars)")
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return
        }

        do {
            let menuData = try JSONDecoder().decode(MenuData.self, from: jsonData)
            print("Decoded: \(menuData.homes.count) homes, \(menuData.rooms.count) rooms, \(menuData.accessories.count) accessories")
            DispatchQueue.main.async {
                self.rebuildMenu(with: menuData)
            }
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("Type mismatch for \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("Value not found for \(type): \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
        } catch {
            print("Failed to decode menu JSON: \(error)")
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

    private func setupCameraStatusItem(hasCameras: Bool) {
        if hasCameras {
            if cameraStatusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = item.button {
                    let pluginBundle = Bundle(for: MacOSController.self)
                    if let icon = pluginBundle.image(forResource: "CameraMenuBarIcon") {
                        icon.isTemplate = true
                        button.image = icon
                    } else {
                        button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Cameras")
                        button.image?.isTemplate = true
                    }
                    button.action = #selector(cameraStatusItemClicked)
                    button.target = self
                }
                cameraStatusItem = item
            }
        } else {
            if let item = cameraStatusItem {
                NSStatusBar.system.removeStatusItem(item)
                cameraStatusItem = nil
            }
        }
    }


    @objc private func cameraStatusItemClicked() {
        if let existing = cameraPanelWindow, existing.isVisible {
            dismissCameraPanel()
            return
        }

        if cameraPanelWindow != nil {
            showCameraPanel()
            return
        }

        if isCameraPanelOpening {
            return
        }

        isCameraPanelOpening = true
        pendingCameraPanelShow = true
        iOSBridge?.openCameraWindow()
        setupCameraPanelWindow()
    }

    private func showCameraPanel() {
        guard let panel = cameraPanelWindow,
              cameraStatusItem?.button?.window != nil else { return }
        positionCameraPanelWithSize(panel, width: cameraPanelSize.width, height: cameraPanelSize.height)
        iOSBridge?.setCameraWindowHidden(false)
        panel.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        setupClickOutsideMonitor()
        // Re-apply highlight after mouse event completes (system resets it on mouseUp)
        DispatchQueue.main.async {
            self.cameraStatusItem?.button?.highlight(true)
        }
    }

    private var cameraPanelPollTimer: DispatchSourceTimer?
    private var cameraWindowObserver: NSObjectProtocol?

    private func setupCameraPanelWindow() {
        // Register notification observer to catch window as early as possible
        cameraWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let window = notification.object as? NSWindow,
                  window.title == "Cameras",
                  self.cameraPanelWindow == nil else { return }
            self.configureCameraPanelWindow(window)
        }

        // Also poll aggressively (every 5ms) as a fallback
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.cameraPanelWindow == nil else {
                self?.stopCameraPanelPolling()
                return
            }
            if let window = NSApp.windows.first(where: { $0.title == "Cameras" }) {
                self.configureCameraPanelWindow(window)
            }
        }
        timer.resume()
        cameraPanelPollTimer = timer

        // Safety timeout — stop polling after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.stopCameraPanelPolling()
        }
    }

    private func stopCameraPanelPolling() {
        cameraPanelPollTimer?.cancel()
        cameraPanelPollTimer = nil
        if let observer = cameraWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            cameraWindowObserver = nil
        }
    }

    private func configureCameraPanelWindow(_ cameraWindow: NSWindow) {
        stopCameraPanelPolling()

        // Immediately hide to prevent flash
        cameraWindow.alphaValue = 0
        cameraWindow.orderOut(nil)

        cameraPanelWindow = cameraWindow

        cameraWindow.titlebarAppearsTransparent = true
        cameraWindow.titleVisibility = .hidden
        cameraWindow.toolbar = nil
        cameraWindow.standardWindowButton(.closeButton)?.isHidden = true
        cameraWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        cameraWindow.standardWindowButton(.zoomButton)?.isHidden = true
        cameraWindow.styleMask.insert(.fullSizeContentView)

        cameraWindow.isMovable = false
        cameraWindow.level = .popUpMenu
        cameraWindow.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        cameraWindow.hasShadow = true
        cameraWindow.isOpaque = false

        cameraWindow.contentView?.wantsLayer = true
        cameraWindow.contentView?.layer?.cornerRadius = 10
        cameraWindow.contentView?.layer?.masksToBounds = true

        // Window stays hidden — will be shown by showCameraPanel() on user click
        isCameraPanelOpening = false
        if pendingCameraPanelShow {
            pendingCameraPanelShow = false
            showCameraPanel()
        }
    }

    @objc public func resizeCameraPanel(width: CGFloat, height: CGFloat, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cameraPanelSize = NSSize(width: width, height: height)
            guard let window = self.cameraPanelWindow, window.isVisible else { return }
            self.positionCameraPanelWithSize(window, width: width, height: height, animate: animated)
        }
    }

    private func positionCameraPanelWithSize(_ window: NSWindow, width: CGFloat, height: CGFloat, animate: Bool = false) {
        guard let button = cameraStatusItem?.button,
              let buttonWindow = button.window else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        let x = screenRect.midX - width / 2
        let y = screenRect.minY - height - 4

        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: animate)
    }

    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()

        let dismissCheck: () -> Void = { [weak self] in
            guard let self = self else { return }
            let screenPoint = NSEvent.mouseLocation
            if let panel = self.cameraPanelWindow, panel.frame.contains(screenPoint) {
                return
            }
            if let button = self.cameraStatusItem?.button, let btnWindow = button.window {
                let btnRect = button.convert(button.bounds, to: nil)
                let btnScreenRect = btnWindow.convertToScreen(btnRect)
                if btnScreenRect.contains(screenPoint) {
                    return
                }
            }
            self.dismissCameraPanel()
        }

        // Catch clicks outside the app
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            dismissCheck()
        }

        // Catch clicks on other windows within the app (e.g. settings window)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.cameraPanelWindow?.isVisible == true else { return event }
            // Ignore clicks on the camera panel itself or its status bar button
            if event.window == self.cameraPanelWindow { return event }
            if event.window == self.cameraStatusItem?.button?.window { return event }
            self.dismissCameraPanel()
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }

    private func dismissCameraPanel() {
        removeClickOutsideMonitor()
        cameraPanelWindow?.orderOut(nil)
        iOSBridge?.setCameraWindowHidden(true)
        cameraStatusItem?.button?.highlight(false)
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

    private func rebuildMenu(with data: MenuData) {
        currentMenuData = data
        mainMenu.removeAllItems()

        PreferencesManager.shared.currentHomeId = data.selectedHomeId
        PreferencesManager.shared.currentHomeName = data.homes.first(where: { $0.uniqueIdentifier == data.selectedHomeId })?.name
        CloudSyncManager.shared.updateMenuData(data)
        HotkeyManager.shared.registerShortcuts()

        menuBuilder.bridge = iOSBridge
        menuBuilder.buildMenu(into: mainMenu, with: data)

        actionEngine.bridge = iOSBridge
        actionEngine.updateMenuData(data)

        WebhookServer.shared.configure(actionEngine: actionEngine)
        let camerasEnabled = PreferencesManager.shared.camerasEnabled
        setupCameraStatusItem(hasCameras: data.hasCameras && camerasEnabled && ProStatusCache.shared.isPro)

        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()

        refreshCharacteristics()
    }

    private func addFooterItems() {
        if let data = currentMenuData, data.homes.count > 1 {
            addHomeSelector(homes: data.homes, selectedId: data.selectedHomeId)
        }

        let settingsIcon = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        let settingsItem = menuBuilder.createActionItem(title: "Settings...", icon: settingsIcon) { [weak self] in
            self?.openSettings(nil)
        }
        mainMenu.addItem(settingsItem)

        mainMenu.addItem(NSMenuItem.separator())

        let refreshIcon = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
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
        let homeIcon = NSImage(systemSymbolName: "house", accessibilityDescription: nil)
        let homeItem = menuBuilder.createSubmenuItem(title: "Home", icon: homeIcon)

        let submenu = StayOpenMenu()
        for home in homes {
            let isSelected = home.uniqueIdentifier == selectedId
            let iconName = isSelected ? "checkmark" : (home.isPrimary ? "house.fill" : "house")
            let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
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

    // MARK: - Menu Updates

    private func updateMenuItems(for characteristicId: UUID, value: Any, isLocalChange: Bool) {
        updateMenuItemsRecursively(in: mainMenu, characteristicId: characteristicId, value: value, isLocalChange: isLocalChange)

        for sceneItem in menuBuilder.sceneMenuItems {
            sceneItem.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
        }
    }

    private func updateMenuItemsRecursively(in menu: NSMenu, characteristicId: UUID, value: Any, isLocalChange: Bool) {
        for item in menu.items {
            if let updatable = item as? CharacteristicUpdatable {
                updatable.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
            }
            if let submenu = item.submenu {
                updateMenuItemsRecursively(in: submenu, characteristicId: characteristicId, value: value, isLocalChange: isLocalChange)
            }
        }
    }

    private func updateAccessoryReachability(_ accessoryId: UUID, isReachable: Bool) {
        guard let menuData = currentMenuData,
              let accessory = menuData.accessories.first(where: { $0.uniqueIdentifier == accessoryId.uuidString }) else {
            return
        }

        let serviceIds = Set(accessory.services.compactMap { UUID(uuidString: $0.uniqueIdentifier) })
        updateReachabilityRecursively(in: mainMenu, serviceIds: serviceIds, isReachable: isReachable)
    }

    private func updateReachabilityRecursively(in menu: NSMenu, serviceIds: Set<UUID>, isReachable: Bool) {
        for item in menu.items {
            if let reachabilityItem = item as? ReachabilityUpdatable,
               serviceIds.contains(reachabilityItem.serviceIdentifier) {
                reachabilityItem.setReachable(isReachable)
            }
            if let submenu = item.submenu {
                updateReachabilityRecursively(in: submenu, serviceIds: serviceIds, isReachable: isReachable)
            }
        }
    }

    // MARK: - Actions

    @objc private func selectHome(_ sender: NSMenuItem) {
        if let uuidString = sender.representedObject as? String, let uuid = UUID(uuidString: uuidString) {
            SettingsWindowController.shared.close()
            iOSBridge?.selectedHomeIdentifier = uuid
        }
    }

    @objc private func openSettings(_ sender: Any?) {
        dismissCameraPanel()
        if let data = currentMenuData {
            SettingsWindowController.shared.configure(with: data)
        }
        SettingsWindowController.shared.showWindow(nil)
    }

    @objc private func refreshHomeKit(_ sender: Any?) {
        iOSBridge?.reloadHomeKit()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        if menu == mainMenu {
            menuIsOpen = true
            if cameraPanelWindow?.isVisible == true {
                dismissCameraPanel()
            }
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

    private func refreshCharacteristics() {
        refreshCharacteristicsRecursively(in: mainMenu)
    }

    private func refreshCharacteristicsRecursively(in menu: NSMenu) {
        for item in menu.items {
            if let refreshable = item as? CharacteristicRefreshable {
                for id in refreshable.characteristicIdentifiers {
                    iOSBridge?.readCharacteristic(identifier: id)
                }
            }
            if let submenu = item.submenu {
                refreshCharacteristicsRecursively(in: submenu)
            }
        }
    }
}
