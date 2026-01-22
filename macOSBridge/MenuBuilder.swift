//
//  MenuBuilder.swift
//  macOSBridge
//
//  Builds menu items from HomeKit data
//

import AppKit

class MenuBuilder {

    weak var bridge: Mac2iOS?
    private(set) var sceneMenuItems: [SceneMenuItem] = []
    private var currentMenuData: MenuData?

    init(bridge: Mac2iOS?) {
        self.bridge = bridge
    }

    // MARK: - Public API

    func buildMenu(into menu: NSMenu, with data: MenuData) {
        sceneMenuItems = []
        currentMenuData = data

        // Favourites section
        let hasFavourites = addFavouritesSection(to: menu, from: data)
        if hasFavourites {
            menu.addItem(NSMenuItem.separator())
        }

        // Groups section (Pro feature)
        let hasGroups = addGroupsSection(to: menu, from: data)
        if hasGroups {
            menu.addItem(NSMenuItem.separator())
        }

        // Scenes (if not hidden)
        let preferences = PreferencesManager.shared
        if !data.scenes.isEmpty && !preferences.hideScenesSection {
            addScenes(to: menu, scenes: data.scenes)
            menu.addItem(NSMenuItem.separator())
        }

        // Filter hidden services and rooms
        let filteredAccessories = filterHiddenServices(from: data.accessories)
        let visibleRooms = data.rooms.filter { !preferences.isHidden(roomId: $0.uniqueIdentifier) }

        if visibleRooms.isEmpty && filteredAccessories.isEmpty {
            let emptyItem = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            addRoomsAndAccessories(to: menu, rooms: visibleRooms, accessories: filteredAccessories)
        }
    }

    // MARK: - Favourites

    @discardableResult
    func addFavouritesSection(to menu: NSMenu, from data: MenuData) -> Bool {
        let preferences = PreferencesManager.shared

        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let allServices = data.accessories.flatMap { $0.services }
        let serviceLookup = Dictionary(uniqueKeysWithValues: allServices.map { ($0.uniqueIdentifier, $0) })

        var addedAny = false

        for id in preferences.orderedFavouriteIds {
            if let scene = sceneLookup[id] {
                let item = SceneMenuItem(sceneData: scene, bridge: bridge)
                menu.addItem(item)
                sceneMenuItems.append(item)
                addedAny = true
            } else if let service = serviceLookup[id] {
                if let item = createMenuItemForService(service) {
                    menu.addItem(item)
                    addedAny = true
                }
            }
        }

        return addedAny
    }

    // MARK: - Groups

    @discardableResult
    func addGroupsSection(to menu: NSMenu, from data: MenuData) -> Bool {
        // Only show groups for Pro users
        guard ProStatusCache.shared.isPro else { return false }

        let preferences = PreferencesManager.shared
        let groups = preferences.deviceGroups

        guard !groups.isEmpty else { return false }

        for group in groups {
            let item = GroupMenuItem(group: group, menuData: data, bridge: bridge)
            menu.addItem(item)
        }

        return true
    }

    // MARK: - Scenes

    func addScenes(to menu: NSMenu, scenes: [SceneData]) {
        let preferences = PreferencesManager.shared
        let visibleScenes = scenes.filter { !preferences.isHidden(sceneId: $0.uniqueIdentifier) }

        guard !visibleScenes.isEmpty else { return }

        if preferences.scenesDisplayMode == .grid {
            let gridItem = ScenesGridMenuItem(scenes: visibleScenes, bridge: bridge)
            menu.addItem(gridItem)
        } else {
            let scenesItem = NSMenuItem(title: "Scenes", action: nil, keyEquivalent: "")
            scenesItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)

            let submenu = StayOpenMenu()
            for scene in visibleScenes {
                let item = SceneMenuItem(sceneData: scene, bridge: bridge)
                submenu.addItem(item)
                sceneMenuItems.append(item)
            }

            scenesItem.submenu = submenu
            menu.addItem(scenesItem)
        }
    }

    // MARK: - Rooms and accessories

    func addRoomsAndAccessories(to menu: NSMenu, rooms: [RoomData], accessories: [AccessoryData]) {
        var accessoriesByRoom: [String: [AccessoryData]] = [:]
        var noRoomAccessories: [AccessoryData] = []

        for accessory in accessories {
            if let roomId = accessory.roomIdentifier {
                accessoriesByRoom[roomId, default: []].append(accessory)
            } else {
                noRoomAccessories.append(accessory)
            }
        }

        for room in rooms {
            guard let roomAccessories = accessoriesByRoom[room.uniqueIdentifier], !roomAccessories.isEmpty else {
                continue
            }

            let roomItem = NSMenuItem(title: room.name, action: nil, keyEquivalent: "")
            roomItem.image = IconMapping.iconForRoom(room.name)

            let submenu = StayOpenMenu()
            addServicesGroupedByType(to: submenu, accessories: roomAccessories)
            roomItem.submenu = submenu
            menu.addItem(roomItem)
        }

        if !noRoomAccessories.isEmpty {
            let otherItem = NSMenuItem(title: "Other", action: nil, keyEquivalent: "")
            otherItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)

            let submenu = StayOpenMenu()
            addServicesGroupedByType(to: submenu, accessories: noRoomAccessories)
            otherItem.submenu = submenu
            menu.addItem(otherItem)
        }
    }

    func addServicesGroupedByType(to menu: NSMenu, accessories: [AccessoryData]) {
        var servicesByType: [String: [ServiceData]] = [:]
        var temperatureSensors: [ServiceData] = []
        var humiditySensors: [ServiceData] = []

        let excludedTypes: Set<String> = [
            ServiceTypes.temperatureSensor,
            ServiceTypes.humiditySensor
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

        let typeOrder: [String] = [
            ServiceTypes.lightbulb,
            ServiceTypes.switch,
            ServiceTypes.outlet,
            ServiceTypes.fan,
            ServiceTypes.heaterCooler,
            ServiceTypes.thermostat,
            ServiceTypes.humidifierDehumidifier,
            ServiceTypes.airPurifier,
            ServiceTypes.windowCovering,
            ServiceTypes.lock,
            ServiceTypes.garageDoorOpener,
            ServiceTypes.valve,
            ServiceTypes.securitySystem
        ]

        let sortedTypes = servicesByType.keys.sorted { type1, type2 in
            let index1 = typeOrder.firstIndex(of: type1) ?? Int.max
            let index2 = typeOrder.firstIndex(of: type2) ?? Int.max
            return index1 < index2
        }

        var isFirstGroup = true
        for serviceType in sortedTypes {
            guard let services = servicesByType[serviceType] else { continue }

            if !isFirstGroup {
                menu.addItem(NSMenuItem.separator())
            }
            isFirstGroup = false

            let sortedServices = services.sorted { $0.name < $1.name }

            for service in sortedServices {
                if let item = createMenuItemForService(service) {
                    menu.addItem(item)
                }
            }
        }

        if !temperatureSensors.isEmpty || !humiditySensors.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let sensorItem = SensorSummaryMenuItem(
                temperatureSensors: temperatureSensors,
                humiditySensors: humiditySensors,
                bridge: bridge
            )
            menu.addItem(sensorItem)
        }
    }

    // MARK: - Service menu items

    func createMenuItemForService(_ service: ServiceData) -> NSMenuItem? {
        let menuItem: NSMenuItem?

        switch service.serviceType {
        case ServiceTypes.lightbulb:
            menuItem = LightMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.switch, ServiceTypes.outlet:
            menuItem = SwitchMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.thermostat:
            menuItem = ThermostatMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.heaterCooler:
            menuItem = ACMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.lock:
            menuItem = LockMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.windowCovering:
            menuItem = BlindMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.fan:
            menuItem = FanMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.garageDoorOpener:
            menuItem = GarageDoorMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.humidifierDehumidifier:
            menuItem = HumidifierMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.airPurifier:
            menuItem = AirPurifierMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.valve:
            menuItem = ValveMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.securitySystem:
            menuItem = SecuritySystemMenuItem(serviceData: service, bridge: bridge)

        default:
            let item = NSMenuItem(title: service.name, action: nil, keyEquivalent: "")
            item.image = IconMapping.iconForServiceType(service.serviceType)
            menuItem = item
        }

        if let reachabilityItem = menuItem as? ReachabilityUpdatable {
            reachabilityItem.setReachable(service.isReachable)
        }

        return menuItem
    }

    // MARK: - Filtering

    func filterHiddenServices(from accessories: [AccessoryData]) -> [AccessoryData] {
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
}
