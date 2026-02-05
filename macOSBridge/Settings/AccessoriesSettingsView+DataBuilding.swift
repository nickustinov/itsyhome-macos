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
        rebuildRoomData()
        rebuildSceneData()
    }

    func rebuildFavouritesList() {
        guard let data = menuData else {
            favouriteItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let serviceLookup = Dictionary(uniqueKeysWithValues: data.accessories.flatMap { $0.services }.map { ($0.uniqueIdentifier, $0) })
        let groupLookup = Dictionary(uniqueKeysWithValues: preferences.deviceGroups.map { ($0.id, $0) })

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
        let sensorTypes: Set<String> = [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]

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

        // Order rooms by saved order, with unseen rooms appended at end
        // Show all rooms so users can hide rooms that only have cameras or unsupported sensors
        let roomsWithServices = data.rooms
        let savedOrder = preferences.roomOrder
        var ordered: [RoomData] = []
        for roomId in savedOrder {
            if let room = roomsWithServices.first(where: { $0.uniqueIdentifier == roomId }) {
                ordered.append(room)
            }
        }
        for room in roomsWithServices where !ordered.contains(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) {
            ordered.append(room)
        }
        orderedRooms = ordered
        preferences.roomOrder = ordered.map { $0.uniqueIdentifier }

        // Build flat table items
        var items: [RoomTableItem] = []
        for room in ordered {
            let roomId = room.uniqueIdentifier
            let isHidden = preferences.isHidden(roomId: roomId)
            let isCollapsed = !expandedSections.contains(roomId)
            let services = servicesByRoom[roomId] ?? []
            let roomGroups = groupsByRoom[roomId] ?? []

            items.append(.header(room: room, isHidden: isHidden, isCollapsed: isCollapsed, serviceCount: services.count))

            if !isCollapsed {
                // Add groups at the top of each room
                for group in roomGroups {
                    items.append(.group(group: group, roomId: roomId))
                }

                // Add separator after groups if there are both groups and services
                if !roomGroups.isEmpty && !services.isEmpty {
                    items.append(.groupSeparator)
                }

                // Group services by type
                var servicesByType: [String: [ServiceData]] = [:]
                for service in services {
                    servicesByType[service.serviceType, default: []].append(service)
                }

                // Sort types by typeOrder and add separators between groups
                let sortedTypes = servicesByType.keys.sorted { type1, type2 in
                    let i1 = typeOrder.firstIndex(of: type1) ?? Int.max
                    let i2 = typeOrder.firstIndex(of: type2) ?? Int.max
                    return i1 < i2
                }

                var isFirstGroup = true
                for serviceType in sortedTypes {
                    guard let typeServices = servicesByType[serviceType] else { continue }

                    if !isFirstGroup {
                        items.append(.separator)
                    }
                    isFirstGroup = false

                    let sortedServices = typeServices.sorted { $0.name < $1.name }
                    for service in sortedServices {
                        items.append(.accessory(service: service, roomHidden: isHidden))
                    }
                }
            }
        }
        roomTableItems = items
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
            case .separator, .groupSeparator:
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
