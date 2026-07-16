//
//  AccessoriesSettingsView+DataBuilding.swift
//  macOSBridge
//
//  Data building methods for accessories settings
//

import AppKit

extension AccessoriesSettingsView {

    // MARK: - Data Building

    func rebuildAllData() {
        rebuildGroupData()
        rebuildFavouritesList()
        // Scenes before rooms: the rooms table hosts the scenes section rows.
        rebuildSceneData()
        rebuildRoomData()
    }

    func rebuildFavouritesList() {
        guard let data = menuData else {
            favouriteItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let sceneLookup = Dictionary(data.scenes.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { _, last in last })
        let serviceLookup = Dictionary(data.accessories.flatMap { $0.services }.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { _, last in last })
        let groupLookup = Dictionary(preferences.deviceGroups.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        var items: [FavouriteItem] = []
        for id in preferences.orderedFavouriteIds {
            if id.hasPrefix("groupFav:") {
                let groupId = String(id.dropFirst("groupFav:".count))
                if let group = groupLookup[groupId] {
                    let icon = PhosphorIcon.regular(group.icon)
                    items.append(FavouriteItem(kind: .group(group), id: id, name: group.name, icon: icon))
                }
            } else if let scene = sceneLookup[id] {
                items.append(FavouriteItem(kind: .scene(scene), id: id, name: scene.name, icon: SceneIconInference.icon(for: scene.name)))
            } else if let service = serviceLookup[id] {
                items.append(FavouriteItem(kind: .service(service), id: id, name: service.name, icon: IconResolver.icon(for: service)))
            }
        }
        favouriteItems = items
    }

    func rebuildRoomData() {
        guard let data = menuData else {
            roomTableItems = []
            orderedRooms = []
            return
        }

        let preferences = PreferencesManager.shared
        // Temperature/humidity sensors are only rolled into the aggregate summary
        // when it's enabled; with the summary off they are individual rows and
        // must be manageable here like any other accessory.
        let sensorTypes: Set<String> = preferences.sensorSummary
            ? [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]
            : []

        servicesByRoom = [:]
        noRoomServices = []

        for accessory in data.accessories {
            for service in accessory.services {
                if let roomId = service.roomIdentifier {
                    if !sensorTypes.contains(service.serviceType) {
                        servicesByRoom[roomId, default: []].append(service)
                    }
                } else if !sensorTypes.contains(service.serviceType) {
                    noRoomServices.append(service)
                }
            }
        }

        // Resolve the saved top-level layout (all sections and dividers),
        // persisting any drift. Shows all rooms so users can hide rooms that
        // only have cameras or unsupported sensors.
        let tokens = preferences.normalizeMenuLayout(roomIds: data.rooms.map { $0.uniqueIdentifier })
        orderedRooms = tokens.compactMap { token in
            data.rooms.first { $0.uniqueIdentifier == token }
        }

        // Build flat table items in section order. Mirrors the menu: empty
        // sections are skipped (they appear once they have content), and a
        // divider row only shows when visible sections sit on both sides of
        // it – suppressed divider tokens stay in the layout and reappear
        // together with their section.
        var items: [RoomTableItem] = []
        var pendingDivider: String?
        var emittedAny = false

        /// Runs a section builder; when it emitted rows, materialise any
        /// pending divider above them.
        func appendSection(_ build: (inout [RoomTableItem]) -> Void) {
            let start = items.count
            build(&items)
            guard items.count > start else { return }
            if let divider = pendingDivider {
                items.insert(.sectionDivider(token: divider), at: start)
                pendingDivider = nil
            }
            emittedAny = true
        }

        for token in tokens {
            if token.hasPrefix(PreferencesManager.dividerPrefix) {
                if emittedAny { pendingDivider = token }
                continue
            }
            if token == PreferencesManager.favouritesSectionToken {
                appendSection { self.appendFavouritesItems(to: &$0) }
                continue
            }
            if token == PreferencesManager.groupsSectionToken {
                appendSection { self.appendGlobalGroupsItems(to: &$0, data: data) }
                continue
            }
            if token == PreferencesManager.scenesSectionToken {
                appendSection { self.appendScenesItems(to: &$0) }
                continue
            }
            if token == PreferencesManager.otherSectionToken {
                appendSection { self.appendOtherItems(to: &$0) }
                continue
            }
            if token == PreferencesManager.batteriesSectionToken {
                appendSection { self.appendBatteriesItems(to: &$0, accessories: data.accessories) }
                continue
            }
            if AutoGroups.definition(forToken: token) != nil {
                appendSection { self.appendHomeAutoGroupItem(token: token, to: &$0, data: data) }
                continue
            }
            guard let room = data.rooms.first(where: { $0.uniqueIdentifier == token }) else { continue }
            if let divider = pendingDivider {
                items.append(.sectionDivider(token: divider))
                pendingDivider = nil
            }
            emittedAny = true
            let roomId = room.uniqueIdentifier
            let isHidden = preferences.isHidden(roomId: roomId)
            let isCollapsed = !expandedSections.contains(roomId)
            let services = servicesByRoom[roomId] ?? []
            let roomGroups = groupsByRoom[roomId] ?? []

            items.append(.header(room: room, isHidden: isHidden, isCollapsed: isCollapsed, serviceCount: services.count))

            if !isCollapsed {
                let savedOrder = preferences.accessoryOrder(forRoom: roomId)
                if !savedOrder.isEmpty {
                    // Custom order: groups, services and user dividers in the
                    // saved sequence, with anything new appended at the end.
                    let serviceLookup = Dictionary(services.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
                    let groupLookup = Dictionary(roomGroups.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                    var seenIds: Set<String> = []
                    for token in savedOrder {
                        if token.hasPrefix(PreferencesManager.dividerPrefix) {
                            items.append(.divider(token: token, roomId: roomId))
                        } else if AutoGroups.definition(forToken: token) != nil {
                            seenIds.insert(token)
                            if preferences.autoGroupsEnabled,
                               let group = AutoGroups.roomGroup(forToken: token, roomId: roomId, services: services) {
                                items.append(.autoGroup(group: group, token: token, roomId: roomId))
                            }
                        } else if let group = groupLookup[token] {
                            appendGroupRow(group, roomId: roomId, to: &items, data: data)
                            seenIds.insert(token)
                        } else if let service = serviceLookup[token] {
                            items.append(.accessory(service: service, roomHidden: isHidden, roomId: roomId))
                            seenIds.insert(token)
                        }
                    }
                    // Append anything that wasn't in the saved order yet;
                    // auto groups land at the bottom, matching the menu.
                    for group in roomGroups where !seenIds.contains(group.id) {
                        appendGroupRow(group, roomId: roomId, to: &items, data: data)
                    }
                    for service in services where !seenIds.contains(service.uniqueIdentifier) {
                        items.append(.accessory(service: service, roomHidden: isHidden, roomId: roomId))
                    }
                    if preferences.autoGroupsEnabled {
                        for (autoToken, group) in AutoGroups.roomGroups(roomId: roomId, services: services)
                            where !seenIds.contains(autoToken) {
                            items.append(.autoGroup(group: group, token: autoToken, roomId: roomId))
                        }
                    }
                } else {
                    // Groups at the top of each room, then services by type
                    for group in roomGroups {
                        appendGroupRow(group, roomId: roomId, to: &items, data: data)
                    }
                    if !roomGroups.isEmpty && !services.isEmpty {
                        items.append(.groupSeparator)
                    }
                    // Default: group services by type with auto separators. All
                    // read-only sensor types share a single section under one
                    // divider, matching the menu (see MenuBuilder).
                    var servicesByType: [String: [ServiceData]] = [:]
                    for service in services {
                        servicesByType[service.serviceType, default: []].append(service)
                    }

                    let sortedTypes = servicesByType.keys.sorted { type1, type2 in
                        let i1 = typeOrder.firstIndex(of: type1) ?? Int.max
                        let i2 = typeOrder.firstIndex(of: type2) ?? Int.max
                        return i1 < i2
                    }

                    let sensorTypes: Set<String> = [
                        ServiceTypes.contactSensor, ServiceTypes.motionSensor,
                        ServiceTypes.occupancySensor, ServiceTypes.leakSensor,
                        ServiceTypes.smokeSensor, ServiceTypes.carbonMonoxideSensor,
                        ServiceTypes.carbonDioxideSensor,
                        ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor,
                        ServiceTypes.sensor, ServiceTypes.binarySensor
                    ]

                    func appendServices(_ typeServices: [ServiceData]) {
                        for service in typeServices.sorted(by: { $0.name < $1.name }) {
                            items.append(.accessory(service: service, roomHidden: isHidden, roomId: roomId))
                        }
                    }

                    var isFirstGroup = true
                    for serviceType in sortedTypes where !sensorTypes.contains(serviceType) {
                        guard let typeServices = servicesByType[serviceType] else { continue }
                        if !isFirstGroup {
                            items.append(.separator)
                        }
                        isFirstGroup = false
                        appendServices(typeServices)
                    }

                    // Auto groups at the bottom of the room's controls,
                    // above the sensor section – matching the menu.
                    if preferences.autoGroupsEnabled {
                        let autoPairs = AutoGroups.roomGroups(roomId: roomId, services: services)
                        if !autoPairs.isEmpty {
                            if !isFirstGroup {
                                items.append(.separator)
                            }
                            isFirstGroup = false
                            for (autoToken, group) in autoPairs {
                                items.append(.autoGroup(group: group, token: autoToken, roomId: roomId))
                            }
                        }
                    }

                    // Sensor section: one divider, then every sensor row.
                    let sensorTypesPresent = sortedTypes.filter { sensorTypes.contains($0) }
                    if !sensorTypesPresent.isEmpty {
                        if !isFirstGroup {
                            items.append(.separator)
                        }
                        isFirstGroup = false
                        for serviceType in sensorTypesPresent {
                            guard let typeServices = servicesByType[serviceType] else { continue }
                            appendServices(typeServices)
                        }
                    }
                }
            }
        }
        roomTableItems = items
    }

    /// Favourites section rows (header plus, when expanded, one row per
    /// favourite in the user's order).
    private func appendFavouritesItems(to items: inout [RoomTableItem]) {
        guard !favouriteItems.isEmpty else { return }
        let isCollapsed = !expandedSections.contains("favourites")
        items.append(.favouritesHeader(isCollapsed: isCollapsed, count: favouriteItems.count))
        if !isCollapsed {
            for item in favouriteItems {
                items.append(.favourite(item: item))
            }
        }
    }

    /// Global groups section rows (header plus, when expanded, one row per
    /// group, each expandable to its member devices).
    private func appendGlobalGroupsItems(to items: inout [RoomTableItem], data: MenuData) {
        guard !globalGroups.isEmpty else { return }
        let isCollapsed = !expandedSections.contains("groups")
        items.append(.groupsHeader(isCollapsed: isCollapsed, count: globalGroups.count))
        if !isCollapsed {
            for group in globalGroups {
                items.append(.globalGroup(group: group))
                appendGroupDevices(of: group, to: &items, data: data)
            }
        }
    }

    /// A room group row, followed by its member devices when expanded.
    private func appendGroupRow(_ group: DeviceGroup, roomId: String, to items: inout [RoomTableItem], data: MenuData) {
        items.append(.group(group: group, roomId: roomId))
        appendGroupDevices(of: group, to: &items, data: data)
    }

    /// Member devices of an expanded group, in deviceIds order – the order
    /// the group's submenu and pinned menu use.
    private func appendGroupDevices(of group: DeviceGroup, to items: inout [RoomTableItem], data: MenuData) {
        guard expandedSections.contains(group.id) else { return }
        for service in group.resolveServices(in: data) {
            items.append(.groupDevice(service: service, groupId: group.id))
        }
    }

    /// "Other" section rows: header plus, when expanded, the no-room services
    /// grouped by type (this section has no custom ordering).
    private func appendOtherItems(to items: inout [RoomTableItem]) {
        guard !noRoomServices.isEmpty else { return }
        let isHidden = PreferencesManager.shared.hideOtherSection
        let isCollapsed = !expandedSections.contains("other")
        items.append(.otherHeader(isHidden: isHidden, isCollapsed: isCollapsed, count: noRoomServices.count))
        guard !isCollapsed else { return }
        let sorted = noRoomServices.sorted { s1, s2 in
            let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
            let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
            return i1 != i2 ? i1 < i2 : s1.name < s2.name
        }
        for service in sorted {
            items.append(.otherAccessory(service: service, sectionHidden: isHidden))
        }
    }

    /// Scenes section rows (header plus, when expanded, one row per scene)
    /// hosted in the rooms table so the section can be dragged among rooms.
    private func appendScenesItems(to items: inout [RoomTableItem]) {
        guard !sceneItems.isEmpty else { return }
        let preferences = PreferencesManager.shared
        let isHidden = preferences.hideScenesSection
        let isCollapsed = !expandedSections.contains("scenes")
        items.append(.scenesHeader(isHidden: isHidden, isCollapsed: isCollapsed, sceneCount: sceneItems.count))
        if !isCollapsed {
            for scene in sceneItems {
                items.append(.scene(scene: scene, sectionHidden: isHidden))
            }
        }
    }

    /// One top-level auto group row ("All lights" across the home). Shown
    /// even when eye-hidden – the eye reflects the state – but not at all
    /// when the feature is off or under 2 devices match.
    private func appendHomeAutoGroupItem(token: String, to items: inout [RoomTableItem], data: MenuData) {
        guard PreferencesManager.shared.autoGroupsEnabled,
              let group = AutoGroups.homeGroup(forToken: token, accessories: data.accessories) else { return }
        items.append(.autoGroup(group: group, token: token, roomId: nil))
    }

    /// Batteries section header (#144). Counts every battery-powered device,
    /// hidden or not, so the row reflects what the submenu can show.
    private func appendBatteriesItems(to items: inout [RoomTableItem], accessories: [AccessoryData]) {
        let deviceCount = BatteriesMenuItem.devices(from: accessories).count
        guard deviceCount > 0 else { return }
        items.append(.batteriesHeader(isHidden: PreferencesManager.shared.hideBatteriesSection, deviceCount: deviceCount))
    }

    func rebuildSceneData() {
        guard let data = menuData else {
            sceneItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let savedOrder = preferences.sceneOrder
        var ordered: [SceneData] = []
        for sceneId in savedOrder {
            if let scene = data.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
                ordered.append(scene)
            }
        }
        for scene in data.scenes where !ordered.contains(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) {
            ordered.append(scene)
        }
        sceneItems = ordered
        preferences.sceneOrder = ordered.map { $0.uniqueIdentifier }
    }

    func rebuildGroupData() {
        let preferences = PreferencesManager.shared
        let allGroups = preferences.deviceGroups

        // Separate groups by room assignment
        var global: [DeviceGroup] = []
        var byRoom: [String: [DeviceGroup]] = [:]

        for group in allGroups {
            if let roomId = group.roomId {
                byRoom[roomId, default: []].append(group)
            } else {
                global.append(group)
            }
        }

        // Order global groups
        let savedGlobalOrder = preferences.globalGroupOrder
        var orderedGlobal: [DeviceGroup] = []
        for groupId in savedGlobalOrder {
            if let group = global.first(where: { $0.id == groupId }) {
                orderedGlobal.append(group)
            }
        }
        for group in global where !orderedGlobal.contains(where: { $0.id == group.id }) {
            orderedGlobal.append(group)
        }
        globalGroups = orderedGlobal
        if !orderedGlobal.isEmpty {
            preferences.globalGroupOrder = orderedGlobal.map { $0.id }
        }

        // Order groups per room
        for (roomId, roomGroups) in byRoom {
            let savedRoomOrder = preferences.groupOrder(forRoom: roomId)
            var ordered: [DeviceGroup] = []
            for groupId in savedRoomOrder {
                if let group = roomGroups.first(where: { $0.id == groupId }) {
                    ordered.append(group)
                }
            }
            for group in roomGroups where !ordered.contains(where: { $0.id == group.id }) {
                ordered.append(group)
            }
            byRoom[roomId] = ordered
            if !ordered.isEmpty {
                preferences.setGroupOrder(ordered.map { $0.id }, forRoom: roomId)
            }
        }
        groupsByRoom = byRoom
    }

    // MARK: - Height Calculation

    func calculateRoomsTableHeight() -> CGFloat {
        let L = AccessoryRowLayout.self
        var height: CGFloat = 0
        for (index, item) in roomTableItems.enumerated() {
            switch item {
            case .separator, .groupSeparator, .divider, .sectionDivider:
                height += 12
            default:
                height += L.rowHeight
            }
            // Add intercell spacing (except for last row)
            if index < roomTableItems.count - 1 {
                height += 4
            }
        }
        return height
    }

    // MARK: - Room Index Helpers

    func roomIndex(forTableRow row: Int) -> Int? {
        var headerCount = 0
        for i in 0...row {
            if case .header = roomTableItems[i] {
                if i == row { return headerCount }
                headerCount += 1
            }
        }
        return nil
    }

    func tableRow(forRoomIndex roomIndex: Int) -> Int? {
        var headerCount = 0
        for (i, item) in roomTableItems.enumerated() {
            if case .header = item {
                if headerCount == roomIndex { return i }
                headerCount += 1
            }
        }
        return nil
    }
}
