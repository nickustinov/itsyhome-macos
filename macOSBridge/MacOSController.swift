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
    private var sceneMenuItems: [SceneMenuItem] = []
    private var currentMenuData: MenuData?

    @objc public weak var iOSBridge: Mac2iOS?

    // MARK: - Initialization
    
    @objc public required override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )
    }

    @objc private func preferencesDidChange() {
        if let data = currentMenuData {
            rebuildMenu(with: data)
        }
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            // Load custom icon from this plugin's bundle
            let pluginBundle = Bundle(for: MacOSController.self)
            if let icon = pluginBundle.image(forResource: "MenuBarIcon") {
                icon.isTemplate = true
                button.image = icon
            } else {
                // Fallback to SF Symbol
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
            alert.messageText = "Itsyhome error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Menu Building
    
    private func rebuildMenu(with data: MenuData) {
        currentMenuData = data
        mainMenu.removeAllItems()
        sceneMenuItems = []

        // Home selector (if multiple homes)
        if data.homes.count > 1 {
            addHomeSelector(homes: data.homes, selectedId: data.selectedHomeId)
            mainMenu.addItem(NSMenuItem.separator())
        }

        // Favourites section (before Scenes) - unified order
        let hasFavourites = addFavouritesSection(from: data)
        if hasFavourites {
            mainMenu.addItem(NSMenuItem.separator())
        }

        // Scenes (if not hidden)
        let preferences = PreferencesManager.shared
        if data.scenes.count > 0 && !preferences.hideScenesSection {
            addScenes(data.scenes)
            mainMenu.addItem(NSMenuItem.separator())
        }

        // Filter hidden services and rooms from accessories
        let filteredAccessories = filterHiddenServices(from: data.accessories)
        let visibleRooms = data.rooms.filter { !preferences.isHidden(roomId: $0.uniqueIdentifier) }

        if visibleRooms.count == 0 && filteredAccessories.count == 0 {
            let emptyItem = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            mainMenu.addItem(emptyItem)
        } else {
            addRoomsAndAccessories(rooms: visibleRooms, accessories: filteredAccessories)
        }

        mainMenu.addItem(NSMenuItem.separator())
        addFooterItems()
    }

    // MARK: - Favourites

    /// Add favourites in unified order (scenes and services mixed)
    /// Returns true if any favourites were added
    @discardableResult
    private func addFavouritesSection(from data: MenuData) -> Bool {
        let preferences = PreferencesManager.shared

        // Build lookup maps
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let allServices = data.accessories.flatMap { $0.services }
        let serviceLookup = Dictionary(uniqueKeysWithValues: allServices.map { ($0.uniqueIdentifier, $0) })

        var addedAny = false

        // Add items in unified order
        for id in preferences.orderedFavouriteIds {
            if let scene = sceneLookup[id] {
                let item = SceneMenuItem(sceneData: scene, bridge: iOSBridge)
                mainMenu.addItem(item)
                sceneMenuItems.append(item)
                addedAny = true
            } else if let service = serviceLookup[id] {
                if let item = createMenuItemForService(service) {
                    mainMenu.addItem(item)
                    addedAny = true
                }
            }
        }

        return addedAny
    }

    private func filterHiddenServices(from accessories: [AccessoryData]) -> [AccessoryData] {
        let preferences = PreferencesManager.shared
        return accessories.map { accessory in
            let filteredServices = accessory.services.filter { service in
                !preferences.isHidden(serviceId: service.uniqueIdentifier)
            }
            return AccessoryData(
                uniqueIdentifier: UUID(uuidString: accessory.uniqueIdentifier)!,
                name: accessory.name,
                roomIdentifier: accessory.roomIdentifier.flatMap { UUID(uuidString: $0) },
                services: filteredServices,
                isReachable: accessory.isReachable
            )
        }
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
        let preferences = PreferencesManager.shared
        let visibleScenes = scenes.filter { !preferences.isHidden(sceneId: $0.uniqueIdentifier) }

        guard !visibleScenes.isEmpty else { return }

        if preferences.scenesDisplayMode == .grid {
            // Grid view - use ScenesGridMenuItem
            let gridItem = ScenesGridMenuItem(scenes: visibleScenes, bridge: iOSBridge)
            mainMenu.addItem(gridItem)
        } else {
            // List view - use submenu with SceneMenuItems
            let scenesItem = NSMenuItem(title: "Scenes", action: nil, keyEquivalent: "")
            scenesItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)

            let submenu = NSMenu()
            for scene in visibleScenes {
                let item = SceneMenuItem(sceneData: scene, bridge: iOSBridge)
                submenu.addItem(item)
                sceneMenuItems.append(item)
            }

            scenesItem.submenu = submenu
            mainMenu.addItem(scenesItem)
        }
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
            addServicesGroupedByType(to: submenu, accessories: roomAccessories)
            roomItem.submenu = submenu
            mainMenu.addItem(roomItem)
        }

        // Add accessories without room
        if !noRoomAccessories.isEmpty {
            let otherItem = NSMenuItem(title: "Other", action: nil, keyEquivalent: "")
            otherItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)

            let submenu = NSMenu()
            addServicesGroupedByType(to: submenu, accessories: noRoomAccessories)
            otherItem.submenu = submenu
            mainMenu.addItem(otherItem)
        }
    }

    private func addServicesGroupedByType(to menu: NSMenu, accessories: [AccessoryData]) {
        // Collect all services from all accessories
        var servicesByType: [String: [ServiceData]] = [:]
        var temperatureSensors: [ServiceData] = []
        var humiditySensors: [ServiceData] = []

        // Types to exclude from main list (sensors shown in footer, motion/smoke not supported)
        let excludedTypes: Set<String> = [
            ServiceTypes.temperatureSensor,
            ServiceTypes.humiditySensor,
            ServiceTypes.motionSensor
        ]

        for accessory in accessories {
            for service in accessory.services {
                if service.serviceType == ServiceTypes.temperatureSensor {
                    temperatureSensors.append(service)
                } else if service.serviceType == ServiceTypes.humiditySensor {
                    humiditySensors.append(service)
                } else if !excludedTypes.contains(service.serviceType) {
                    servicesByType[service.serviceType, default: []].append(service)
                }
            }
        }

        // Define type order priority
        let typeOrder: [String] = [
            ServiceTypes.lightbulb,
            ServiceTypes.switch,
            ServiceTypes.outlet,
            ServiceTypes.fan,
            ServiceTypes.heaterCooler,
            ServiceTypes.thermostat,
            ServiceTypes.windowCovering,
            ServiceTypes.lock,
            ServiceTypes.garageDoorOpener,
            ServiceTypes.contactSensor
        ]

        // Sort types by priority (known types first, then unknown)
        let sortedTypes = servicesByType.keys.sorted { type1, type2 in
            let index1 = typeOrder.firstIndex(of: type1) ?? Int.max
            let index2 = typeOrder.firstIndex(of: type2) ?? Int.max
            return index1 < index2
        }

        var isFirstGroup = true
        for serviceType in sortedTypes {
            guard let services = servicesByType[serviceType] else { continue }

            // Add separator between groups
            if !isFirstGroup {
                menu.addItem(NSMenuItem.separator())
            }
            isFirstGroup = false

            // Sort services by name within group
            let sortedServices = services.sorted { $0.name < $1.name }

            for service in sortedServices {
                if let item = createMenuItemForService(service) {
                    menu.addItem(item)
                }
            }
        }

        // Add sensor summary footer if there are any sensors
        if !temperatureSensors.isEmpty || !humiditySensors.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let sensorItem = SensorSummaryMenuItem(
                temperatureSensors: temperatureSensors,
                humiditySensors: humiditySensors,
                bridge: iOSBridge
            )
            menu.addItem(sensorItem)
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

        case ServiceTypes.fan:
            return FanMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.garageDoorOpener:
            return GarageDoorMenuItem(serviceData: service, bridge: iOSBridge)

        case ServiceTypes.contactSensor:
            return ContactSensorMenuItem(serviceData: service, bridge: iOSBridge)

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
        case ServiceTypes.fan:
            return NSImage(systemSymbolName: "fan", accessibilityDescription: nil)
        case ServiceTypes.garageDoorOpener:
            return NSImage(systemSymbolName: "door.garage.closed", accessibilityDescription: nil)
        case ServiceTypes.contactSensor:
            return NSImage(systemSymbolName: "door.left.hand.closed", accessibilityDescription: nil)
        default:
            return NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
        }
    }
    
    private func addFooterItems() {
        // Settings menu item
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        mainMenu.addItem(settingsItem)

        mainMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Itsyhome", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        mainMenu.addItem(quitItem)
    }
    
    // MARK: - Menu Updates
    
    private func updateMenuItems(for characteristicId: UUID, value: Any) {
        updateMenuItemsRecursively(in: mainMenu, characteristicId: characteristicId, value: value)

        // Directly update scene items (submenu items may not be traversed correctly)
        for sceneItem in sceneMenuItems {
            sceneItem.updateValue(for: characteristicId, value: value)
        }
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

    @objc private func openSettings(_ sender: Any?) {
        if let data = currentMenuData {
            SettingsWindowController.shared.configure(with: data)
        }
        SettingsWindowController.shared.showWindow(nil)
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
