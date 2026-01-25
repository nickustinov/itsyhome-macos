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
public class MacOSController: NSObject, iOS2Mac, NSMenuDelegate {

    // MARK: - Properties

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = StayOpenMenu()
    private var menuBuilder: MenuBuilder!
    private var actionEngine: ActionEngine!
    private var currentMenuData: MenuData?
    private var menuIsOpen = false
    private var needsRebuild = false
    private var proStatusCancellable: AnyCancellable?
    private var pinnedStatusItems: [String: PinnedStatusItem] = [:]
    private let cameraPanelManager = CameraPanelManager()

    @objc public weak var iOSBridge: Mac2iOS?

    // MARK: - Initialization

    @objc public required override init() {
        super.init()
        menuBuilder = MenuBuilder(bridge: nil)
        actionEngine = ActionEngine(bridge: nil)
        cameraPanelManager.delegate = self
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

        // Re-check camera status when Pro status changes
        Task { @MainActor in
            proStatusCancellable = ProManager.shared.$isPro
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateCameraStatusVisibility()
                }
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

    // MARK: - Pinned status items

    private func syncPinnedStatusItems() {
        guard let data = currentMenuData else { return }

        let pinnedIds = PreferencesManager.shared.pinnedItemIds

        // Build lookup maps
        let allServices = data.accessories.flatMap { $0.services }
        let serviceLookup = Dictionary(uniqueKeysWithValues: allServices.map { ($0.uniqueIdentifier, $0) })
        let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0) })
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let deviceGroups = PreferencesManager.shared.deviceGroups

        // Build services by room
        var servicesByRoom: [String: [ServiceData]] = [:]
        for service in allServices {
            if let roomId = service.roomIdentifier {
                servicesByRoom[roomId, default: []].append(service)
            }
        }

        // Determine which pinned items are valid
        var validPinnedItems: [String: PinnedItemType] = [:]
        for pinId in pinnedIds {
            if pinId == PreferencesManager.scenesSectionPinId {
                // Scenes section pin
                let visibleScenes = data.scenes.filter { !PreferencesManager.shared.isHidden(sceneId: $0.uniqueIdentifier) }
                if !visibleScenes.isEmpty {
                    validPinnedItems[pinId] = .scenesSection(visibleScenes)
                }
            } else if pinId.hasPrefix("room:") {
                // Room pin
                let roomId = String(pinId.dropFirst(5))
                if let room = roomLookup[roomId], let services = servicesByRoom[roomId], !services.isEmpty {
                    validPinnedItems[pinId] = .room(room, services)
                }
            } else if pinId.hasPrefix("scene:") {
                // Scene pin
                let sceneId = String(pinId.dropFirst(6))
                if let scene = sceneLookup[sceneId] {
                    validPinnedItems[pinId] = .scene(scene)
                }
            } else if pinId.hasPrefix("group:") {
                // Group pin
                let groupId = String(pinId.dropFirst(6))
                if let group = deviceGroups.first(where: { $0.id == groupId }) {
                    let services = group.resolveServices(in: data)
                    if !services.isEmpty {
                        validPinnedItems[pinId] = .group(group, services)
                    }
                }
            } else {
                // Service pin
                if let service = serviceLookup[pinId] {
                    validPinnedItems[pinId] = .service(service)
                }
            }
        }

        // Remove status items that are no longer valid
        for (itemId, _) in pinnedStatusItems {
            if validPinnedItems[itemId] == nil {
                pinnedStatusItems.removeValue(forKey: itemId)
            }
        }

        // Create status items for newly pinned items
        for (itemId, itemType) in validPinnedItems {
            if pinnedStatusItems[itemId] == nil {
                let itemName: String
                switch itemType {
                case .service(let service):
                    itemName = service.name
                case .room(let room, _):
                    itemName = room.name
                case .scene(let scene):
                    itemName = scene.name
                case .scenesSection:
                    itemName = "Scenes"
                case .group(let group, _):
                    itemName = group.name
                }

                let statusItem = PinnedStatusItem(itemId: itemId, itemName: itemName, itemType: itemType)
                statusItem.delegate = self
                pinnedStatusItems[itemId] = statusItem

                // Request initial values for the characteristics
                for charId in statusItem.characteristicIdentifiers {
                    iOSBridge?.readCharacteristic(identifier: charId)
                }
            }
        }
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

    @objc public func resizeCameraPanel(width: CGFloat, height: CGFloat, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraPanelManager.resizeCameraPanel(width: width, height: height, animated: animated)
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
        let isPro = ProStatusCache.shared.isPro
        let shouldShow = data.hasCameras && camerasEnabled && isPro
        cameraPanelManager.setupCameraStatusItem(hasCameras: shouldShow)

        // Update pinned status items
        syncPinnedStatusItems()

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

        // Update pinned status items
        updatePinnedStatusItems(for: characteristicId, value: value)
    }

    private func updatePinnedStatusItems(for characteristicId: UUID, value: Any) {
        // Update all pinned status items that have this characteristic
        for (_, statusItem) in pinnedStatusItems {
            if statusItem.characteristicIdentifiers.contains(characteristicId) {
                statusItem.updateValue(for: characteristicId, value: value)
            }
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
        cameraPanelManager.dismissCameraPanel()
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
            if cameraPanelManager.isPanelVisible {
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

// MARK: - PinnedStatusItemDelegate

extension MacOSController: PinnedStatusItemDelegate {
    func pinnedStatusItemNeedsMenuBuilder(_ item: PinnedStatusItem) -> MenuBuilder? {
        return menuBuilder
    }

    func pinnedStatusItemNeedsMenuData(_ item: PinnedStatusItem) -> MenuData? {
        return currentMenuData
    }

    func pinnedStatusItem(_ item: PinnedStatusItem, readCharacteristic characteristicId: UUID) {
        iOSBridge?.readCharacteristic(identifier: characteristicId)
    }

    func pinnedStatusItem(_ item: PinnedStatusItem, getCachedValue characteristicId: UUID) -> Any? {
        return iOSBridge?.getCharacteristicValue(identifier: characteristicId)
    }
}

// MARK: - CameraPanelManagerDelegate

extension MacOSController: CameraPanelManagerDelegate {
    func cameraPanelManagerOpenCameraWindow(_ manager: CameraPanelManager) {
        iOSBridge?.openCameraWindow()
    }

    func cameraPanelManagerSetCameraWindowHidden(_ manager: CameraPanelManager, hidden: Bool) {
        iOSBridge?.setCameraWindowHidden(hidden)
    }
}
