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

        // Every top-level section in the user's saved layout.
        addOrderedSections(to: menu, from: data)
    }

    // MARK: - Favourites

    /// Menu items for the favourites section, in the user's order. Scene
    /// items are tracked in sceneMenuItems for live state updates.
    private func buildFavouriteItems(from data: MenuData) -> [NSMenuItem] {
        let preferences = PreferencesManager.shared

        let sceneLookup = Dictionary(data.scenes.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { _, last in last })
        let allServices = data.accessories.flatMap { $0.services }
        let serviceLookup = Dictionary(allServices.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { _, last in last })

        var items: [NSMenuItem] = []
        for id in preferences.orderedFavouriteIds {
            if let scene = sceneLookup[id] {
                let item = SceneMenuItem(sceneData: scene, bridge: bridge)
                items.append(item)
                sceneMenuItems.append(item)
            } else if let service = serviceLookup[id], let item = createMenuItemForService(service) {
                items.append(item)
            }
        }
        return items
    }

    // MARK: - Groups

    /// Global groups (no room assignment) in the user's order.
    private func orderedGlobalGroups() -> [DeviceGroup] {
        let preferences = PreferencesManager.shared
        let globalGroups = preferences.deviceGroups.filter { $0.roomId == nil }
        let savedOrder = preferences.globalGroupOrder
        return globalGroups.sorted { g1, g2 in
            let i1 = savedOrder.firstIndex(of: g1.id) ?? Int.max
            let i2 = savedOrder.firstIndex(of: g2.id) ?? Int.max
            return i1 < i2
        }
    }

    private func addGroupItem(to menu: NSMenu, group: DeviceGroup, menuData: MenuData) {
        if group.showAsSubmenu {
            let icon = IconResolver.icon(for: group)
            let submenuItem = createSubmenuItem(title: group.name, icon: icon)
            let submenu = StayOpenMenu()

            if group.showGroupSwitch {
                let groupToggle = GroupMenuItem(group: group, menuData: menuData, bridge: bridge)
                submenu.addItem(groupToggle)
                submenu.addItem(NSMenuItem.separator())
            }

            // Render in deviceIds order (reorderable in Settings → Home),
            // not grouped by type – the pinned menu uses the same order.
            for service in group.resolveServices(in: menuData) {
                if let item = createMenuItemForService(service) {
                    submenu.addItem(item)
                }
            }

            submenuItem.submenu = submenu
            menu.addItem(submenuItem)
        } else {
            let item = GroupMenuItem(group: group, menuData: menuData, bridge: bridge)
            menu.addItem(item)
        }
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
        let scenesItem = createSubmenuItem(title: String(localized: "menu.scenes", defaultValue: "Scenes", bundle: .macOSBridge), icon: icon)

        let submenu = StayOpenMenu()
        for scene in orderedScenes {
            let item = SceneMenuItem(sceneData: scene, bridge: bridge)
            submenu.addItem(item)
            sceneMenuItems.append(item)
        }

        scenesItem.submenu = submenu
        menu.addItem(scenesItem)
    }

    // MARK: - Ordered top-level sections

    /// Adds every top-level section in the user's saved layout (menuLayout:
    /// favourites, global groups, scenes, rooms, other and batteries tokens
    /// interleaved with user divider tokens). Separators appear exactly at
    /// the user's dividers, with leading, trailing and doubled-up separators
    /// suppressed when the sections around them have nothing to show.
    func addOrderedSections(to menu: NSMenu, from data: MenuData) {
        let preferences = PreferencesManager.shared

        let filteredAccessories = filterHiddenServices(from: data.accessories)
        let visibleRooms = data.rooms.filter { !preferences.isHidden(roomId: $0.uniqueIdentifier) }

        var accessoriesByRoom: [String: [AccessoryData]] = [:]
        var noRoomAccessories: [AccessoryData] = []
        for accessory in filteredAccessories {
            if let roomId = accessory.roomIdentifier {
                accessoriesByRoom[roomId, default: []].append(accessory)
            } else {
                noRoomAccessories.append(accessory)
            }
        }

        // Build groups by room lookup, ordered within each room
        var groupsByRoom: [String: [DeviceGroup]] = [:]
        for group in preferences.deviceGroups {
            if let roomId = group.roomId {
                groupsByRoom[roomId, default: []].append(group)
            }
        }
        for (roomId, roomGroups) in groupsByRoom {
            let savedOrder = preferences.groupOrder(forRoom: roomId)
            groupsByRoom[roomId] = roomGroups.sorted { g1, g2 in
                let i1 = savedOrder.firstIndex(of: g1.id) ?? Int.max
                let i2 = savedOrder.firstIndex(of: g2.id) ?? Int.max
                return i1 < i2
            }
        }

        var emittedAny = false
        var pendingDivider = false
        func flushPendingDivider() {
            if pendingDivider {
                menu.addItem(NSMenuItem.separator())
                pendingDivider = false
            }
        }

        let tokens = preferences.reconciledMenuLayout(roomIds: data.rooms.map { $0.uniqueIdentifier })
        for token in tokens {
            if token.hasPrefix(PreferencesManager.dividerPrefix) {
                // Only becomes a separator once another section follows it, so
                // hidden/empty sections never leave stray or doubled lines.
                if emittedAny { pendingDivider = true }
                continue
            }
            switch token {
            case PreferencesManager.favouritesSectionToken:
                let favouriteItems = buildFavouriteItems(from: data)
                guard !favouriteItems.isEmpty else { continue }
                flushPendingDivider()
                favouriteItems.forEach { menu.addItem($0) }
                emittedAny = true

            case PreferencesManager.groupsSectionToken:
                let globalGroups = orderedGlobalGroups()
                guard !globalGroups.isEmpty else { continue }
                flushPendingDivider()
                for group in globalGroups {
                    addGroupItem(to: menu, group: group, menuData: data)
                }
                emittedAny = true

            case PreferencesManager.scenesSectionToken:
                let hasVisibleScenes = data.scenes.contains { !preferences.isHidden(sceneId: $0.uniqueIdentifier) }
                guard hasVisibleScenes, !preferences.hideScenesSection else { continue }
                flushPendingDivider()
                addScenes(to: menu, scenes: data.scenes)
                emittedAny = true

            case PreferencesManager.otherSectionToken:
                guard !noRoomAccessories.isEmpty, !preferences.hideOtherSection else { continue }
                flushPendingDivider()
                let icon = PhosphorIcon.regular("squares-four")
                let otherItem = createSubmenuItem(title: String(localized: "menu.other", defaultValue: "Other", bundle: .macOSBridge), icon: icon)
                let submenu = StayOpenMenu()
                addServicesGroupedByType(to: submenu, accessories: noRoomAccessories)
                otherItem.submenu = submenu
                menu.addItem(otherItem)
                emittedAny = true

            case PreferencesManager.batteriesSectionToken:
                guard !preferences.hideBatteriesSection,
                      let batteriesItem = BatteriesMenuItem(accessories: filteredAccessories, bridge: bridge) else { continue }
                batteriesItem.view = Self.makeSubmenuItemView(title: batteriesItem.title, icon: PhosphorIcon.regular("battery-medium"))
                flushPendingDivider()
                menu.addItem(batteriesItem)
                emittedAny = true

            default:
                if AutoGroups.definition(forToken: token) != nil {
                    guard preferences.autoGroupsEnabled,
                          let group = AutoGroups.homeGroup(forToken: token, accessories: filteredAccessories),
                          !preferences.hiddenAutoGroupIds.contains(group.id) else { continue }
                    flushPendingDivider()
                    addGroupItem(to: menu, group: group, menuData: data)
                    emittedAny = true
                    continue
                }
                guard let room = visibleRooms.first(where: { $0.uniqueIdentifier == token }) else { continue }
                let roomAccessories = accessoriesByRoom[room.uniqueIdentifier] ?? []
                let roomGroups = groupsByRoom[room.uniqueIdentifier] ?? []

                // Skip rooms with no accessories and no groups
                guard !roomAccessories.isEmpty || !roomGroups.isEmpty else { continue }
                flushPendingDivider()
                addRoomItem(to: menu, room: room, accessories: roomAccessories, groups: roomGroups)
                emittedAny = true
            }
        }

        if visibleRooms.isEmpty && filteredAccessories.isEmpty {
            if emittedAny {
                menu.addItem(NSMenuItem.separator())
            }
            let emptyItem = NSMenuItem(title: String(localized: "menu.no_devices", defaultValue: "No devices found", bundle: .macOSBridge), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }
    }

    private func addRoomItem(to menu: NSMenu, room: RoomData, accessories: [AccessoryData], groups: [DeviceGroup]) {
        let icon = IconResolver.icon(forRoomId: room.uniqueIdentifier, roomName: room.name)
        let roomItem = createSubmenuItem(title: room.name, icon: icon)

        let submenu = StayOpenMenu()
        addServicesGroupedByType(to: submenu, accessories: accessories, roomName: room.name, roomId: room.uniqueIdentifier, groups: groups)
        roomItem.submenu = submenu
        menu.addItem(roomItem)
    }

    /// Renders a section's rows. With a custom saved order (roomId set and
    /// accessoryOrder non-empty) rows follow that order, with groups
    /// interleaved wherever the user dragged them; otherwise groups sit on
    /// top and services are grouped by type.
    func addServicesGroupedByType(to menu: NSMenu, accessories: [AccessoryData], roomName: String? = nil, roomId: String? = nil, groups: [DeviceGroup] = []) {
        var servicesByType: [String: [ServiceData]] = [:]
        var temperatureSensors: [ServiceData] = []
        var humiditySensors: [ServiceData] = []
        var allServices: [ServiceData] = []

        // When the aggregate summary is on, standalone temperature/humidity
        // sensors are pulled out of the per-type rows and rolled into a single
        // SensorSummaryMenuItem (along with readings embedded in thermostats,
        // ACs, etc.). When off, they render as individual rows like any other
        // sensor and no summary is built.
        let summaryEnabled = PreferencesManager.shared.sensorSummary
        let excludedTypes: Set<String> = summaryEnabled
            ? [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]
            : []

        for accessory in accessories {
            for service in accessory.services {
                if summaryEnabled && service.serviceType == ServiceTypes.temperatureSensor {
                    temperatureSensors.append(service)
                } else if summaryEnabled && service.serviceType == ServiceTypes.humiditySensor {
                    humiditySensors.append(service)
                } else if !excludedTypes.contains(service.serviceType) {
                    servicesByType[service.serviceType, default: []].append(service)
                    allServices.append(service)
                    // Also collect temperature/humidity embedded in thermostats,
                    // ACs, etc. for the summary (their own rows show it too).
                    if summaryEnabled {
                        if service.currentTemperatureId != nil {
                            temperatureSensors.append(service)
                        }
                        if service.humidityId != nil {
                            humiditySensors.append(service)
                        }
                    }
                }
            }
        }

        // Custom per-room order overrides the default type grouping. Tokens
        // are service ids, group ids or divider tokens.
        let savedOrder: [String] = roomId.map { PreferencesManager.shared.accessoryOrder(forRoom: $0) } ?? []
        if !savedOrder.isEmpty {
            let serviceLookup = Dictionary(allServices.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
            let groupLookup = Dictionary(groups.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            var seen: Set<String> = []
            var lastWasDivider = true  // suppress leading divider
            for token in savedOrder {
                if token.hasPrefix(PreferencesManager.dividerPrefix) {
                    if !lastWasDivider, menu.items.last?.isSeparatorItem == false {
                        menu.addItem(NSMenuItem.separator())
                        lastWasDivider = true
                    }
                } else if AutoGroups.definition(forToken: token) != nil {
                    seen.insert(token)
                    if PreferencesManager.shared.autoGroupsEnabled,
                       let roomId = roomId,
                       let group = AutoGroups.roomGroup(forToken: token, roomId: roomId, services: allServices),
                       !PreferencesManager.shared.hiddenAutoGroupIds.contains(group.id),
                       let menuData = currentMenuData {
                        addGroupItem(to: menu, group: group, menuData: menuData)
                        lastWasDivider = false
                    }
                } else if let group = groupLookup[token], let menuData = currentMenuData {
                    addGroupItem(to: menu, group: group, menuData: menuData)
                    lastWasDivider = false
                    seen.insert(token)
                } else if let service = serviceLookup[token] {
                    var displayService = service
                    if let roomName = roomName {
                        displayService = service.strippingRoomName(roomName)
                    }
                    if let item = createMenuItemForService(displayService) {
                        menu.addItem(item)
                        lastWasDivider = false
                    }
                    seen.insert(token)
                }
            }
            // Append anything not yet in the saved order (newly created
            // groups, newly discovered services).
            var appendedSeparator = false
            func separatorBeforeAppendedItems() {
                if !appendedSeparator, !lastWasDivider, menu.items.last?.isSeparatorItem == false {
                    menu.addItem(NSMenuItem.separator())
                }
                appendedSeparator = true
            }
            if let menuData = currentMenuData {
                for group in groups where !seen.contains(group.id) {
                    separatorBeforeAppendedItems()
                    addGroupItem(to: menu, group: group, menuData: menuData)
                    lastWasDivider = false
                }
            }
            for service in allServices where !seen.contains(service.uniqueIdentifier) {
                separatorBeforeAppendedItems()
                var displayService = service
                if let roomName = roomName {
                    displayService = service.strippingRoomName(roomName)
                }
                if let item = createMenuItemForService(displayService) {
                    menu.addItem(item)
                    lastWasDivider = false
                }
            }

            // Auto groups not yet in the saved order land at the bottom
            // (new feature, or new devices crossed the 2-member threshold).
            if let roomId = roomId, PreferencesManager.shared.autoGroupsEnabled, let menuData = currentMenuData {
                let hidden = PreferencesManager.shared.hiddenAutoGroupIds
                for (token, group) in AutoGroups.roomGroups(roomId: roomId, services: allServices)
                    where !seen.contains(token) && !hidden.contains(group.id) {
                    separatorBeforeAppendedItems()
                    addGroupItem(to: menu, group: group, menuData: menuData)
                    lastWasDivider = false
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
            return
        }

        // Default layout: groups on top, then services grouped by type.
        if !groups.isEmpty, let menuData = currentMenuData {
            for group in groups {
                addGroupItem(to: menu, group: group, menuData: menuData)
            }
            if !allServices.isEmpty {
                menu.addItem(NSMenuItem.separator())
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
            ServiceTypes.securitySystem,
            ServiceTypes.contactSensor,
            ServiceTypes.motionSensor,
            ServiceTypes.occupancySensor,
            ServiceTypes.leakSensor,
            ServiceTypes.smokeSensor,
            ServiceTypes.carbonMonoxideSensor,
            ServiceTypes.carbonDioxideSensor,
            ServiceTypes.temperatureSensor,
            ServiceTypes.humiditySensor,
            ServiceTypes.sensor,
            ServiceTypes.binarySensor
        ]

        let sortedTypes = servicesByType.keys.sorted { type1, type2 in
            let index1 = typeOrder.firstIndex(of: type1) ?? Int.max
            let index2 = typeOrder.firstIndex(of: type2) ?? Int.max
            return index1 < index2
        }

        // Read-only sensors share a single section: each non-sensor type keeps
        // its own divider, but all sensor types (and the temperature/humidity
        // summary) are grouped together under one divider from the rest.
        let sensorTypes: Set<String> = [
            ServiceTypes.contactSensor, ServiceTypes.motionSensor,
            ServiceTypes.occupancySensor, ServiceTypes.leakSensor,
            ServiceTypes.smokeSensor, ServiceTypes.carbonMonoxideSensor,
            ServiceTypes.carbonDioxideSensor,
            ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor,
            ServiceTypes.sensor, ServiceTypes.binarySensor
        ]

        func addServiceItems(_ services: [ServiceData]) {
            for service in services.sorted(by: { $0.name < $1.name }) {
                let displayService = roomName.map { service.strippingRoomName($0) } ?? service
                if let item = createMenuItemForService(displayService) {
                    menu.addItem(item)
                }
            }
        }

        var isFirstGroup = true
        for serviceType in sortedTypes where !sensorTypes.contains(serviceType) {
            guard let services = servicesByType[serviceType] else { continue }
            if !isFirstGroup {
                menu.addItem(NSMenuItem.separator())
            }
            isFirstGroup = false
            addServiceItems(services)
        }

        // Auto groups sit at the bottom of the room's controls, above the
        // sensor section.
        if let roomId = roomId, PreferencesManager.shared.autoGroupsEnabled, let menuData = currentMenuData {
            let hidden = PreferencesManager.shared.hiddenAutoGroupIds
            let autoGroups = AutoGroups.roomGroups(roomId: roomId, services: allServices)
                .map { $0.group }
                .filter { !hidden.contains($0.id) }
            if !autoGroups.isEmpty {
                if !isFirstGroup {
                    menu.addItem(NSMenuItem.separator())
                }
                isFirstGroup = false
                for group in autoGroups {
                    addGroupItem(to: menu, group: group, menuData: menuData)
                }
            }
        }

        // Sensor section: one divider, then every sensor row, then the summary.
        let sensorTypesPresent = sortedTypes.filter { sensorTypes.contains($0) }
        let hasSummary = !temperatureSensors.isEmpty || !humiditySensors.isEmpty
        if !sensorTypesPresent.isEmpty || hasSummary {
            if !isFirstGroup {
                menu.addItem(NSMenuItem.separator())
            }
            isFirstGroup = false
            for serviceType in sensorTypesPresent {
                guard let services = servicesByType[serviceType] else { continue }
                addServiceItems(services)
            }
            if hasSummary {
                menu.addItem(SensorSummaryMenuItem(
                    temperatureSensors: temperatureSensors,
                    humiditySensors: humiditySensors,
                    bridge: bridge
                ))
            }
        }
    }

    // MARK: - Submenu items (rooms, etc.)

    func createSubmenuItem(title: String, icon: NSImage?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = Self.makeSubmenuItemView(title: title, icon: icon)
        return item
    }

    /// The shared row view for items that open a submenu: icon, name and a
    /// trailing chevron. Also used by menu item subclasses (BatteriesMenuItem)
    /// that need the same look on a custom NSMenuItem.
    static func makeSubmenuItemView(title: String, icon: NSImage?) -> NSView {
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

        return containerView
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
            // Use HAClimateMenuItem for HA (has availableHVACModes), ThermostatMenuItem for HomeKit
            if service.availableHVACModes != nil {
                menuItem = HAClimateMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = ThermostatMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.heaterCooler:
            menuItem = ACMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.lock:
            if PlatformManager.shared.selectedPlatform == .homeAssistant {
                menuItem = HALockMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = LockMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.windowCovering, ServiceTypes.door, ServiceTypes.window:
            // Use HACoverMenuItem for HA covers without position support
            if service.targetPositionId == nil {
                menuItem = HACoverMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = BlindMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.fan, ServiceTypes.fanV2:
            menuItem = FanMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.garageDoorOpener:
            if PlatformManager.shared.selectedPlatform == .homeAssistant {
                menuItem = HAGarageDoorMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = GarageDoorMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.humidifierDehumidifier:
            if PlatformManager.shared.selectedPlatform == .homeAssistant {
                menuItem = HAHumidifierMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = HumidifierMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.airPurifier:
            menuItem = AirPurifierMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.valve, ServiceTypes.faucet:
            if PlatformManager.shared.selectedPlatform == .homeAssistant {
                menuItem = HAValveMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = ValveMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.securitySystem:
            if PlatformManager.shared.selectedPlatform == .homeAssistant {
                menuItem = HASecuritySystemMenuItem(serviceData: service, bridge: bridge)
            } else {
                menuItem = SecuritySystemMenuItem(serviceData: service, bridge: bridge)
            }

        case ServiceTypes.slat:
            menuItem = SlatMenuItem(serviceData: service, bridge: bridge)

        case ServiceTypes.contactSensor, ServiceTypes.motionSensor,
             ServiceTypes.occupancySensor, ServiceTypes.leakSensor,
             ServiceTypes.smokeSensor, ServiceTypes.carbonMonoxideSensor,
             ServiceTypes.carbonDioxideSensor,
             ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor,
             ServiceTypes.sensor, ServiceTypes.binarySensor:
            // Temperature/humidity only reach here when the aggregate summary is
            // off; otherwise they are rolled into a SensorSummaryMenuItem. The
            // generic sensor/binarySensor types are Home Assistant sensors with
            // no HomeKit equivalent.
            menuItem = SensorStateMenuItem(serviceData: service, bridge: bridge)

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
