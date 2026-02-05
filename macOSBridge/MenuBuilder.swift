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

        // Debug mock accessories (toggle DebugShowMockAccessories to enable)
        DebugMockups.addMockItems(to: menu, builder: self)

        // Favourites section
        let hasFavourites = addFavouritesSection(to: menu, from: data)
        if hasFavourites {
            menu.addItem(NSMenuItem.separator())
        }

        // Groups section
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
        let preferences = PreferencesManager.shared
        // Only show global groups (no room assignment) at the top level
        let globalGroups = preferences.deviceGroups.filter { $0.roomId == nil }

        guard !globalGroups.isEmpty else { return false }

        // Order by globalGroupOrder
        let savedOrder = preferences.globalGroupOrder
        let orderedGroups = globalGroups.sorted { g1, g2 in
            let i1 = savedOrder.firstIndex(of: g1.id) ?? Int.max
            let i2 = savedOrder.firstIndex(of: g2.id) ?? Int.max
            return i1 < i2
        }

        for group in orderedGroups {
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

        let savedOrder = preferences.sceneOrder
        let orderedScenes = visibleScenes.sorted { s1, s2 in
            let i1 = savedOrder.firstIndex(of: s1.uniqueIdentifier) ?? Int.max
            let i2 = savedOrder.firstIndex(of: s2.uniqueIdentifier) ?? Int.max
            return i1 < i2
        }

        let icon = PhosphorIcon.regular("sparkle")
        let scenesItem = createSubmenuItem(title: "Scenes", icon: icon)

        let submenu = StayOpenMenu()
        for scene in orderedScenes {
            let item = SceneMenuItem(sceneData: scene, bridge: bridge)
            submenu.addItem(item)
            sceneMenuItems.append(item)
        }

        scenesItem.submenu = submenu
        menu.addItem(scenesItem)
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

        // Build groups by room lookup
        let preferences = PreferencesManager.shared
        var groupsByRoom: [String: [DeviceGroup]] = [:]
        for group in preferences.deviceGroups {
            if let roomId = group.roomId {
                groupsByRoom[roomId, default: []].append(group)
            }
        }
        // Order groups within each room
        for (roomId, roomGroups) in groupsByRoom {
            let savedOrder = preferences.groupOrder(forRoom: roomId)
            groupsByRoom[roomId] = roomGroups.sorted { g1, g2 in
                let i1 = savedOrder.firstIndex(of: g1.id) ?? Int.max
                let i2 = savedOrder.firstIndex(of: g2.id) ?? Int.max
                return i1 < i2
            }
        }

        let savedOrder = preferences.roomOrder
        let orderedRooms = rooms.sorted { r1, r2 in
            let i1 = savedOrder.firstIndex(of: r1.uniqueIdentifier) ?? Int.max
            let i2 = savedOrder.firstIndex(of: r2.uniqueIdentifier) ?? Int.max
            return i1 < i2
        }

        for room in orderedRooms {
            let roomAccessories = accessoriesByRoom[room.uniqueIdentifier] ?? []
            let roomGroups = groupsByRoom[room.uniqueIdentifier] ?? []

            // Skip rooms with no accessories and no groups
            guard !roomAccessories.isEmpty || !roomGroups.isEmpty else {
                continue
            }

            let icon = IconResolver.icon(forRoomId: room.uniqueIdentifier, roomName: room.name)
            let roomItem = createSubmenuItem(title: room.name, icon: icon)

            let submenu = StayOpenMenu()

            // Add groups at the top of the room submenu
            if let menuData = currentMenuData {
                for group in roomGroups {
                    let groupItem = GroupMenuItem(group: group, menuData: menuData, bridge: bridge)
                    submenu.addItem(groupItem)
                }
                // Add separator after groups if there are both groups and accessories
                if !roomGroups.isEmpty && !roomAccessories.isEmpty {
                    submenu.addItem(NSMenuItem.separator())
                }
            }

            addServicesGroupedByType(to: submenu, accessories: roomAccessories, roomName: room.name)
            roomItem.submenu = submenu
            menu.addItem(roomItem)
        }

        if !noRoomAccessories.isEmpty {
            let icon = PhosphorIcon.regular("squares-four")
            let otherItem = createSubmenuItem(title: "Other", icon: icon)

            let submenu = StayOpenMenu()
            addServicesGroupedByType(to: submenu, accessories: noRoomAccessories)
            otherItem.submenu = submenu
            menu.addItem(otherItem)
        }
    }

    func addServicesGroupedByType(to menu: NSMenu, accessories: [AccessoryData], roomName: String? = nil) {
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
                    // Also collect temperature/humidity from thermostats, ACs, etc.
                    if service.currentTemperatureId != nil {
                        temperatureSensors.append(service)
                    }
                    if service.humidityId != nil {
                        humiditySensors.append(service)
                    }
                }
            }
        }

        let typeOrder: [String] = [
            ServiceTypes.lightbulb,
            ServiceTypes.switch,
            ServiceTypes.outlet,
            ServiceTypes.fan,
            ServiceTypes.fanV2,
            ServiceTypes.heaterCooler,
            ServiceTypes.thermostat,
            ServiceTypes.humidifierDehumidifier,
            ServiceTypes.airPurifier,
            ServiceTypes.windowCovering,
            ServiceTypes.door,
            ServiceTypes.window,
            ServiceTypes.lock,
            ServiceTypes.garageDoorOpener,
            ServiceTypes.valve,
            ServiceTypes.faucet,
            ServiceTypes.slat,
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
                var displayService = service
                if let roomName = roomName {
                    displayService = service.strippingRoomName(roomName)
                }
                if let item = createMenuItemForService(displayService) {
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

    // MARK: - Submenu items (rooms, etc.)

    func createSubmenuItem(title: String, icon: NSImage?) -> NSMenuItem {
        let height = DS.ControlSize.menuItemHeight
        let width = DS.ControlSize.menuItemWidth

        let containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        let iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = icon
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Chevron (right-aligned)
        let chevronSize: CGFloat = 12
        let chevronX = width - DS.Spacing.md - chevronSize
        let chevronY = (height - chevronSize) / 2
        let chevronView = NSImageView(frame: NSRect(x: chevronX, y: chevronY, width: chevronSize, height: chevronSize))
        chevronView.image = PhosphorIcon.regular("caret-right")
        chevronView.contentTintColor = DS.Colors.foreground
        chevronView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(chevronView)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let labelWidth = chevronX - labelX - DS.Spacing.xs
        let nameLabel = NSTextField(labelWithString: title)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = containerView
        return item
    }

    func createActionItem(title: String, icon: NSImage?, action: @escaping () -> Void) -> NSMenuItem {
        let height = DS.ControlSize.menuItemHeight
        let width = DS.ControlSize.menuItemWidth

        let containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        let iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = icon
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let labelWidth = width - labelX - DS.Spacing.md
        let nameLabel = NSTextField(labelWithString: title)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        containerView.onAction = action

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = containerView
        return item
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
            // Use ClimateMenuItem for HA (has availableHVACModes), ThermostatMenuItem for HomeKit
            if service.availableHVACModes != nil {
                menuItem = ClimateMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = ThermostatMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.heaterCooler:
            menuItem = ACMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.lock:
            menuItem = LockMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.windowCovering, ServiceTypes.door, ServiceTypes.window:
            // Use CoverMenuItem for HA covers without position support
            if service.targetPositionId == nil {
                menuItem = CoverMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = BlindMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.fan, ServiceTypes.fanV2:
            menuItem = FanMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.garageDoorOpener:
            menuItem = GarageDoorMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.humidifierDehumidifier:
            menuItem = HumidifierMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.airPurifier:
            menuItem = AirPurifierMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.valve, ServiceTypes.faucet:
            menuItem = ValveMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.securitySystem:
            menuItem = SecuritySystemMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.slat:
            menuItem = SlatMenuItem(serviceData: service, bridge: bridge)

        default:
            let item = NSMenuItem(title: service.name, action: nil, keyEquivalent: "")
            item.image = IconResolver.icon(for: service)
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
                uniqueIdentifier: accessory.uniqueIdentifier,
                name: accessory.name,
                roomIdentifier: accessory.roomIdentifier,
                services: filteredServices,
                isReachable: accessory.isReachable
            )
        }
    }
}
