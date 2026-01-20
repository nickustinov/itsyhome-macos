//
//  MacOSController.swift
//  macOSBridge
//
//  Main controller for the macOS menu bar
//

import Foundation
import AppKit

@objc(MacOSController)
public class MacOSController: NSObject, iOS2Mac, NSMenuDelegate {
    
    // MARK: - Properties
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = NSMenu()
    
    @objc public weak var iOSBridge: Mac2iOS?
    
    // MARK: - Initialization
    
    @objc public required override init() {
        super.init()
        setupStatusItem()
        setupMenu()
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "house", accessibilityDescription: "HomeBar")
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
            self.updateMenuItems(for: identifier, value: value)
        }
    }
    
    @objc public func setReachability(accessoryIdentifier: UUID, isReachable: Bool) {
        // Update menu items for this accessory's reachability
        DispatchQueue.main.async {
            self.updateAccessoryReachability(accessoryIdentifier, isReachable: isReachable)
        }
    }
    
    @objc public func showError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "HomeBar Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - Menu Building
    
    private func rebuildMenu(with data: MenuData) {
        mainMenu.removeAllItems()
        
        // Home selector (if multiple homes)
        if data.homes.count > 1 {
            addHomeSelector(homes: data.homes, selectedId: data.selectedHomeId)
            mainMenu.addItem(NSMenuItem.separator())
        }
        
        // Scenes
        if data.scenes.count > 0 {
            addScenes(data.scenes)
            mainMenu.addItem(NSMenuItem.separator())
        }
        
        if data.rooms.count == 0 && data.accessories.count == 0 {
            let emptyItem = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            mainMenu.addItem(emptyItem)
        } else {
            addRoomsAndAccessories(rooms: data.rooms, accessories: data.accessories)
        }
        
        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()
    }
    
    private func addHomeSelector(homes: [HomeData], selectedId: String?) {
        let homeItem = NSMenuItem(title: "Home", action: nil, keyEquivalent: "")
        homeItem.image = NSImage(systemSymbolName: "house", accessibilityDescription: nil)
        
        let submenu = NSMenu()
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
    
    private func addScenes(_ scenes: [SceneData]) {
        let scenesItem = NSMenuItem(title: "Scenes", action: nil, keyEquivalent: "")
        scenesItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        
        let submenu = NSMenu()
        for scene in scenes {
            let item = NSMenuItem(title: scene.name, action: #selector(executeScene(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scene.uniqueIdentifier
            item.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            submenu.addItem(item)
        }
        scenesItem.submenu = submenu
        mainMenu.addItem(scenesItem)
    }
    
    private func addRoomsAndAccessories(rooms: [RoomData], accessories: [AccessoryData]) {
        // Group accessories by room
        var accessoriesByRoom: [String: [AccessoryData]] = [:]
        var noRoomAccessories: [AccessoryData] = []
        
        for accessory in accessories {
            if let roomId = accessory.roomIdentifier {
                accessoriesByRoom[roomId, default: []].append(accessory)
            } else {
                noRoomAccessories.append(accessory)
            }
        }
        
        // Add rooms
        for room in rooms {
            guard let roomAccessories = accessoriesByRoom[room.uniqueIdentifier], !roomAccessories.isEmpty else {
                continue
            }
            
            let roomItem = NSMenuItem(title: room.name, action: nil, keyEquivalent: "")
            roomItem.image = iconForRoom(room.name)
            
            let submenu = NSMenu()
            for accessory in roomAccessories.sorted(by: { $0.name < $1.name }) {
                addAccessoryItems(to: submenu, accessory: accessory)
            }
            roomItem.submenu = submenu
            mainMenu.addItem(roomItem)
        }
        
        // Add accessories without room
        if !noRoomAccessories.isEmpty {
            let otherItem = NSMenuItem(title: "Other", action: nil, keyEquivalent: "")
            otherItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
            
            let submenu = NSMenu()
            for accessory in noRoomAccessories.sorted(by: { $0.name < $1.name }) {
                addAccessoryItems(to: submenu, accessory: accessory)
            }
            otherItem.submenu = submenu
            mainMenu.addItem(otherItem)
        }
    }
    
    private func addAccessoryItems(to menu: NSMenu, accessory: AccessoryData) {
        for service in accessory.services {
            if let item = createMenuItemForService(service) {
                menu.addItem(item)
            }
        }
    }

    private func createMenuItemForService(_ service: ServiceData) -> NSMenuItem? {
        switch service.serviceType {
        case ServiceTypes.lightbulb:
            return LightMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.switch, ServiceTypes.outlet:
            return SwitchMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.thermostat:
            return ThermostatMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.heaterCooler:
            return ACMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.lock:
            return LockMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.windowCovering:
            return BlindMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor, ServiceTypes.motionSensor:
            return SensorMenuItem(serviceData: service, bridge: iOSBridge)

        default:
            // Fallback to basic menu item for unknown types
            let item = NSMenuItem(title: service.name, action: nil, keyEquivalent: "")
            item.image = iconForServiceType(service.serviceType)
            return item
        }
    }
    
    private func iconForServiceType(_ type: String) -> NSImage? {
        switch type {
        case ServiceTypes.lightbulb:
            return NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        case ServiceTypes.switch, ServiceTypes.outlet:
            return NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        case ServiceTypes.thermostat:
            return NSImage(systemSymbolName: "thermometer", accessibilityDescription: nil)
        case ServiceTypes.heaterCooler:
            return NSImage(systemSymbolName: "air.conditioner.horizontal", accessibilityDescription: nil)
        case ServiceTypes.lock:
            return NSImage(systemSymbolName: "lock", accessibilityDescription: nil)
        case ServiceTypes.windowCovering:
            return NSImage(systemSymbolName: "blinds.horizontal.closed", accessibilityDescription: nil)
        case ServiceTypes.temperatureSensor:
            return NSImage(systemSymbolName: "thermometer", accessibilityDescription: nil)
        case ServiceTypes.humiditySensor:
            return NSImage(systemSymbolName: "humidity", accessibilityDescription: nil)
        case ServiceTypes.motionSensor:
            return NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: nil)
        default:
            return NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
        }
    }
    
    private func addFooterItems() {
        let reloadItem = NSMenuItem(title: "Reload", action: #selector(reload(_:)), keyEquivalent: "r")
        reloadItem.target = self
        reloadItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        mainMenu.addItem(reloadItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit HomeBar", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        mainMenu.addItem(quitItem)
    }
    
    // MARK: - Menu Updates
    
    private func updateMenuItems(for characteristicId: UUID, value: Any) {
        updateMenuItemsRecursively(in: mainMenu, characteristicId: characteristicId, value: value)
    }
    
    private func updateMenuItemsRecursively(in menu: NSMenu, characteristicId: UUID, value: Any) {
        for item in menu.items {
            if let updatable = item as? CharacteristicUpdatable {
                updatable.updateValue(for: characteristicId, value: value)
            }
            if let submenu = item.submenu {
                updateMenuItemsRecursively(in: submenu, characteristicId: characteristicId, value: value)
            }
        }
    }
    
    private func updateAccessoryReachability(_ accessoryId: UUID, isReachable: Bool) {
        // Update reachability state in menu items
    }
    
    // MARK: - Actions
    
    @objc private func selectHome(_ sender: NSMenuItem) {
        if let uuidString = sender.representedObject as? String, let uuid = UUID(uuidString: uuidString) {
            iOSBridge?.selectedHomeIdentifier = uuid
        }
    }
    
    @objc private func executeScene(_ sender: NSMenuItem) {
        if let uuidString = sender.representedObject as? String, let uuid = UUID(uuidString: uuidString) {
            iOSBridge?.executeScene(identifier: uuid)
        }
    }
    
    @objc private func reload(_ sender: Any?) {
        iOSBridge?.reloadHomeKit()
    }
    
    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - NSMenuDelegate
    
    public func menuWillOpen(_ menu: NSMenu) {
        if menu == mainMenu {
            // Refresh characteristic values when menu opens
            refreshCharacteristics()
        }
    }
    
    private func refreshCharacteristics() {
        // Request fresh values for visible characteristics
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
    
    // MARK: - Helpers
    
    private func iconForRoom(_ name: String) -> NSImage? {
        let lowercased = name.lowercased()
        
        let symbolName: String
        if lowercased.contains("living") {
            symbolName = "sofa"
        } else if lowercased.contains("bedroom") || lowercased.contains("bed") {
            symbolName = "bed.double"
        } else if lowercased.contains("kitchen") {
            symbolName = "refrigerator"
        } else if lowercased.contains("bath") {
            symbolName = "shower"
        } else if lowercased.contains("office") || lowercased.contains("study") {
            symbolName = "desktopcomputer"
        } else if lowercased.contains("garage") {
            symbolName = "car"
        } else if lowercased.contains("garden") || lowercased.contains("outdoor") {
            symbolName = "leaf"
        } else if lowercased.contains("dining") {
            symbolName = "fork.knife"
        } else if lowercased.contains("hall") || lowercased.contains("corridor") {
            symbolName = "door.left.hand.open"
        } else {
            symbolName = "square.split.bottomrightquarter"
        }
        
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }
}

// MARK: - Protocols for menu items

protocol CharacteristicUpdatable {
    func updateValue(for characteristicId: UUID, value: Any)
}

protocol CharacteristicRefreshable {
    var characteristicIdentifiers: [UUID] { get }
}
