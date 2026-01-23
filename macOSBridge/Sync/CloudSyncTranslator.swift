//
//  CloudSyncTranslator.swift
//  macOSBridge
//
//  Translates device-specific UUIDs to stable room::accessory::service names for cross-device sync
//

import Foundation

struct CloudSyncTranslator {

    enum IdType {
        case service  // orderedFavouriteIds can contain both service and scene IDs
        case scene
        case room
    }

    // Bidirectional lookups built from MenuData
    private(set) var serviceIdToStable: [String: String] = [:]
    private(set) var stableToServiceId: [String: String] = [:]
    private(set) var sceneIdToName: [String: String] = [:]
    private(set) var sceneNameToId: [String: String] = [:]
    private(set) var roomIdToName: [String: String] = [:]
    private(set) var roomNameToId: [String: String] = [:]

    var hasData: Bool { !serviceIdToStable.isEmpty }

    // MARK: - Build lookups

    mutating func updateMenuData(_ data: MenuData) {
        let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })

        serviceIdToStable.removeAll()
        stableToServiceId.removeAll()
        sceneIdToName.removeAll()
        sceneNameToId.removeAll()
        roomIdToName = roomLookup
        roomNameToId = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.name, $0.uniqueIdentifier) })

        for accessory in data.accessories {
            let roomName = accessory.roomIdentifier.flatMap { roomLookup[$0] } ?? "Unknown"
            for service in accessory.services {
                let stable = "\(roomName)::\(accessory.name)::\(service.name)"
                serviceIdToStable[service.uniqueIdentifier] = stable
                stableToServiceId[stable] = service.uniqueIdentifier
            }
        }

        for scene in data.scenes {
            sceneIdToName[scene.uniqueIdentifier] = scene.name
            sceneNameToId[scene.name] = scene.uniqueIdentifier
        }
    }

    // MARK: - ID translation

    func translateIdsToStable(_ ids: [String], type: IdType) -> [String] {
        ids.compactMap { id in
            switch type {
            case .service:
                return serviceIdToStable[id] ?? sceneIdToName[id]
            case .scene:
                return sceneIdToName[id]
            case .room:
                return roomIdToName[id]
            }
        }
    }

    func translateStableToIds(_ names: [String], type: IdType) -> [String] {
        names.compactMap { name in
            switch type {
            case .service:
                return stableToServiceId[name] ?? sceneNameToId[name]
            case .scene:
                return sceneNameToId[name]
            case .room:
                return roomNameToId[name]
            }
        }
    }

    // MARK: - Device groups

    func translateDeviceGroupsToCloud(_ data: Data) -> Data? {
        guard let groups = try? JSONDecoder().decode([DeviceGroup].self, from: data) else { return nil }
        let translated = groups.map { group -> [String: Any] in
            let stableIds = group.deviceIds.compactMap { serviceIdToStable[$0] }
            return ["id": group.id, "name": group.name, "icon": group.icon, "deviceIds": stableIds]
        }
        return try? JSONSerialization.data(withJSONObject: translated)
    }

    func translateDeviceGroupsFromCloud(_ data: Data) -> Data? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let groups = array.compactMap { dict -> DeviceGroup? in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let icon = dict["icon"] as? String,
                  let stableIds = dict["deviceIds"] as? [String] else { return nil }
            let localIds = stableIds.compactMap { stableToServiceId[$0] }
            return DeviceGroup(id: id, name: name, icon: icon, deviceIds: localIds)
        }
        return try? JSONEncoder().encode(groups)
    }

    // MARK: - Shortcuts

    func translateShortcutsToCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: data) else { return nil }
        var translated: [String: PreferencesManager.ShortcutData] = [:]
        for (id, shortcut) in dict {
            if let stable = serviceIdToStable[id] ?? sceneIdToName[id] {
                translated[stable] = shortcut
            }
        }
        return try? JSONEncoder().encode(translated)
    }

    func translateShortcutsFromCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: data) else { return nil }
        var translated: [String: PreferencesManager.ShortcutData] = [:]
        for (stable, shortcut) in dict {
            if let id = stableToServiceId[stable] ?? sceneNameToId[stable] {
                translated[id] = shortcut
            }
        }
        return try? JSONEncoder().encode(translated)
    }
}
