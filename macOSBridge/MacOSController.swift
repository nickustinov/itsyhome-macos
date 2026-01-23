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
    let mainMenu = StayOpenMenu()
    private var menuBuilder: MenuBuilder!
    private var actionEngine: ActionEngine!
    private var currentMenuData: MenuData?

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

        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()

        refreshCharacteristics()
    }

    private func addFooterItems() {
        if let data = currentMenuData, data.homes.count > 1 {
            addHomeSelector(homes: data.homes, selectedId: data.selectedHomeId)
        }

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        mainMenu.addItem(settingsItem)

        mainMenu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(
            title: "Refresh",
            action: #selector(refreshHomeKit(_:)),
            keyEquivalent: ""
        )
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        mainMenu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "")
        quitItem.target = self
        mainMenu.addItem(quitItem)
    }

    private func addHomeSelector(homes: [HomeData], selectedId: String?) {
        let homeItem = NSMenuItem(title: "Home", action: nil, keyEquivalent: "")
        homeItem.image = NSImage(systemSymbolName: "house", accessibilityDescription: nil)

        let submenu = StayOpenMenu()
        for home in homes {
            let item = NSMenuItem(title: home.name, action: #selector(selectHome(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = home.uniqueIdentifier
            item.image = NSImage(systemSymbolName: home.isPrimary ? "house.fill" : "house", accessibilityDescription: nil)
            if home.uniqueIdentifier == selectedId {
                item.state = .on
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
            refreshCharacteristics()
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
