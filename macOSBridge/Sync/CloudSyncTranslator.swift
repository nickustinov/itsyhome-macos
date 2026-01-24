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
        case camera
    }

    // Bidirectional lookups built from MenuData
    private(set) var serviceIdToStable: [String: String] = [:]
    private(set) var stableToServiceId: [String: String] = [:]
    private(set) var sceneIdToName: [String: String] = [:]
    private(set) var sceneNameToId: [String: String] = [:]
    private(set) var roomIdToName: [String: String] = [:]
    private(set) var roomNameToId: [String: String] = [:]
    private(set) var cameraIdToName: [String: String] = [:]
    private(set) var cameraNameToId: [String: String] = [:]
    private(set) var groupIds: Set<String> = []

    private static let groupPrefix = "group::"

    var hasData: Bool { !serviceIdToStable.isEmpty }

    // MARK: - Build lookups

    mutating func updateGroupIds(_ ids: Set<String>) {
        groupIds = ids
    }

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

        cameraIdToName.removeAll()
        cameraNameToId.removeAll()
        for camera in data.cameras {
            cameraIdToName[camera.uniqueIdentifier] = camera.name
            cameraNameToId[camera.name] = camera.uniqueIdentifier
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
            case .camera:
                return cameraIdToName[id]
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
            case .camera:
                return cameraNameToId[name]
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
            } else if groupIds.contains(id) {
                translated[Self.groupPrefix + id] = shortcut
            }
        }
        return try? JSONEncoder().encode(translated)
    }

    func translateShortcutsFromCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: data) else { return nil }
        var translated: [String: PreferencesManager.ShortcutData] = [:]
        for (stable, shortcut) in dict {
            if stable.hasPrefix(Self.groupPrefix) {
                let groupId = String(stable.dropFirst(Self.groupPrefix.count))
                translated[groupId] = shortcut
            } else if let id = stableToServiceId[stable] ?? sceneNameToId[stable] {
                translated[id] = shortcut
            }
        }
        return try? JSONEncoder().encode(translated)
    }

    // MARK: - Camera overlay accessories

    func translateCameraOverlaysToCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return nil }
        var translated: [String: [String]] = [:]
        for (cameraId, serviceIds) in dict {
            guard let cameraName = cameraIdToName[cameraId] else { continue }
            let stableServiceIds = serviceIds.compactMap { serviceIdToStable[$0] }
            if !stableServiceIds.isEmpty {
                translated[cameraName] = stableServiceIds
            }
        }
        return try? JSONEncoder().encode(translated)
    }

    func translateCameraOverlaysFromCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return nil }
        var translated: [String: [String]] = [:]
        for (cameraName, stableServiceIds) in dict {
            guard let cameraId = cameraNameToId[cameraName] else { continue }
            let localIds = stableServiceIds.compactMap { stableToServiceId[$0] }
            if !localIds.isEmpty {
                translated[cameraId] = localIds
            }
        }
        return try? JSONEncoder().encode(translated)
    }
}
