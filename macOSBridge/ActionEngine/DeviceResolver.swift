//
//  DeviceResolver.swift
//  macOSBridge
//
//  Resolves human-readable identifiers to HomeKit services
//

import Foundation

enum DeviceResolver {

    // MARK: - Result types

    enum ResolveResult: Equatable {
        case services([ServiceData])
        case scene(SceneData)
        case notFound(String)
        case ambiguous([ServiceData])

        static func == (lhs: ResolveResult, rhs: ResolveResult) -> Bool {
            switch (lhs, rhs) {
            case (.services(let a), .services(let b)):
                return a.map(\.uniqueIdentifier) == b.map(\.uniqueIdentifier)
            case (.scene(let a), .scene(let b)):
                return a.uniqueIdentifier == b.uniqueIdentifier
            case (.notFound(let a), .notFound(let b)):
                return a == b
            case (.ambiguous(let a), .ambiguous(let b)):
                return a.map(\.uniqueIdentifier) == b.map(\.uniqueIdentifier)
            default:
                return false
            }
        }
    }

    // MARK: - Public API

    /// Resolve a target string to HomeKit entities
    /// Supported formats:
    /// - Room/Device: "Office/Spotlights", "Bedroom/Lamp"
    /// - Scene: "scene.Goodnight", "Goodnight"
    /// - Group: "group.Office Lights"
    /// - UUID: "ABC123-DEF456-..."
    static func resolve(_ query: String, in data: MenuData) -> ResolveResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .notFound(query)
        }

        // 1. Check for UUID match
        if let uuidResult = resolveByUUID(trimmed, in: data) {
            return uuidResult
        }

        // 2. Check for scene prefix or scene name match
        if let sceneResult = resolveScene(trimmed, in: data) {
            return sceneResult
        }

        // 3. Check for group prefix or group name match
        if let groupResult = resolveGroup(trimmed, in: data) {
            return groupResult
        }

        // 4. Room/Device format: "Office/Spotlights"
        if let roomDeviceMatch = resolveRoomAndDeviceName(trimmed, in: data) {
            return roomDeviceMatch
        }

        return .notFound(query)
    }

    // MARK: - Resolution strategies

    private static func resolveByUUID(_ query: String, in data: MenuData) -> ResolveResult? {
        // Check if it looks like a UUID (contains hyphens and hex chars)
        guard query.contains("-"),
              query.range(of: "^[A-Fa-f0-9-]+$", options: .regularExpression) != nil else {
            return nil
        }

        let upperQuery = query.uppercased()

        // Check services
        for accessory in data.accessories {
            for service in accessory.services {
                if service.uniqueIdentifier.uppercased() == upperQuery {
                    return .services([service])
                }
            }
        }

        // Check scenes
        for scene in data.scenes {
            if scene.uniqueIdentifier.uppercased() == upperQuery {
                return .scene(scene)
            }
        }

        return nil
    }

    private static func resolveScene(_ query: String, in data: MenuData) -> ResolveResult? {
        let lowered = query.lowercased()

        // Check for scene. prefix
        if lowered.hasPrefix("scene.") {
            let sceneName = String(query.dropFirst(6))
            return findSceneByName(sceneName, in: data)
        }

        // Also check direct scene name match
        for scene in data.scenes {
            if scene.name.lowercased() == lowered {
                return .scene(scene)
            }
        }

        return nil
    }

    private static func findSceneByName(_ name: String, in data: MenuData) -> ResolveResult {
        let loweredName = name.lowercased()

        // Exact match first
        for scene in data.scenes {
            if scene.name.lowercased() == loweredName {
                return .scene(scene)
            }
        }

        // Partial match
        let matches = data.scenes.filter { scene in
            scene.name.lowercased().contains(loweredName)
        }

        if matches.count == 1 {
            return .scene(matches[0])
        }

        return .notFound("scene.\(name)")
    }

    private static func resolveGroup(_ query: String, in data: MenuData) -> ResolveResult? {
        let lowered = query.lowercased()
        let groups = PreferencesManager.shared.deviceGroups

        // Check for group. prefix
        if lowered.hasPrefix("group.") {
            let groupName = String(query.dropFirst(6))
            return findGroupByName(groupName, groups: groups, data: data)
        }

        // Also check direct group name match (exact only to avoid conflicts with devices)
        for group in groups {
            if group.name.lowercased() == lowered {
                let services = group.resolveServices(in: data)
                if services.isEmpty {
                    return .notFound(query)
                }
                return .services(services)
            }
        }

        return nil
    }

    private static func findGroupByName(_ name: String, groups: [DeviceGroup], data: MenuData) -> ResolveResult {
        let loweredName = name.lowercased()

        // Exact match first
        for group in groups {
            if group.name.lowercased() == loweredName {
                let services = group.resolveServices(in: data)
                if services.isEmpty {
                    return .notFound("group.\(name)")
                }
                return .services(services)
            }
        }

        // Partial match
        let matches = groups.filter { group in
            group.name.lowercased().contains(loweredName)
        }

        if matches.count == 1 {
            let services = matches[0].resolveServices(in: data)
            if services.isEmpty {
                return .notFound("group.\(name)")
            }
            return .services(services)
        }

        return .notFound("group.\(name)")
    }

    private static func resolveRoomAndDeviceName(_ query: String, in data: MenuData) -> ResolveResult? {
        // Try splitting by "/" first, then by space
        let separators: [Character] = ["/", " "]

        for separator in separators {
            let parts = query.split(separator: separator, maxSplits: 1)
            guard parts.count == 2 else { continue }

            let roomPart = String(parts[0]).lowercased()
            let devicePart = String(parts[1]).lowercased()

            // Find matching room
            let roomMatches = data.rooms.filter { room in
                room.name.lowercased() == roomPart || room.name.lowercased().contains(roomPart)
            }

            guard !roomMatches.isEmpty else { continue }

            let roomIds = Set(roomMatches.map(\.uniqueIdentifier))

            // Find services in that room matching the device name
            var matchingServices: [ServiceData] = []
            for accessory in data.accessories {
                for service in accessory.services {
                    if let roomId = service.roomIdentifier,
                       roomIds.contains(roomId),
                       (service.name.lowercased() == devicePart ||
                        service.name.lowercased().contains(devicePart)) {
                        matchingServices.append(service)
                    }
                }
            }

            if matchingServices.count == 1 {
                return .services(matchingServices)
            } else if matchingServices.count > 1 {
                // Prefer exact name match
                let exactMatches = matchingServices.filter { $0.name.lowercased() == devicePart }
                if exactMatches.count == 1 {
                    return .services(exactMatches)
                }
                return .ambiguous(matchingServices)
            }
        }

        return nil
    }
}
