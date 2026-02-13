//
//  DeviceResolver.swift
//  macOSBridge
//
//  Resolves human-readable identifiers to HomeKit services
//

import Foundation

// MARK: - String normalization for comparison

private extension String {
    /// Replaces typographic (smart/curly) quotes with their ASCII equivalents
    /// so that HomeKit names like "Jay\u{2019}s Office" match URL-encoded
    /// queries that use straight quotes like "Jay's Office".
    func normalizedForComparison() -> String {
        var result = self
        // Single quotes: left ' (U+2018) and right ' (U+2019) → ' (U+0027)
        result = result.replacingOccurrences(of: "\u{2018}", with: "'")
        result = result.replacingOccurrences(of: "\u{2019}", with: "'")
        // Double quotes: left " (U+201C) and right " (U+201D) → " (U+0022)
        result = result.replacingOccurrences(of: "\u{201C}", with: "\"")
        result = result.replacingOccurrences(of: "\u{201D}", with: "\"")
        return result
    }
}

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
    /// - Room/Group: "Office/group.All Lights" (room-scoped group)
    /// - Scene: "scene.Goodnight", "Goodnight"
    /// - Group: "group.Office Lights" (global group)
    /// - UUID: "ABC123-DEF456-..."
    static func resolve(_ query: String, in data: MenuData, groups: [DeviceGroup] = []) -> ResolveResult {
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

        // 3. Check for Room/group.Name format (room-scoped groups)
        if let roomGroupResult = resolveRoomScopedGroup(trimmed, in: data, groups: groups) {
            return roomGroupResult
        }

        // 4. Check for group prefix or group name match (global groups)
        if let groupResult = resolveGroup(trimmed, groups: groups, data: data) {
            return groupResult
        }

        // 5. Room/Device format: "Office/Spotlights"
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
        let lowered = query.lowercased().normalizedForComparison()

        // Check for scene. prefix
        if lowered.hasPrefix("scene.") {
            let sceneName = String(query.dropFirst(6))
            return findSceneByName(sceneName, in: data)
        }

        // Also check direct scene name match
        for scene in data.scenes {
            if scene.name.lowercased().normalizedForComparison() == lowered {
                return .scene(scene)
            }
        }

        return nil
    }

    private static func findSceneByName(_ name: String, in data: MenuData) -> ResolveResult {
        let loweredName = name.lowercased().normalizedForComparison()

        // Exact match first
        for scene in data.scenes {
            if scene.name.lowercased().normalizedForComparison() == loweredName {
                return .scene(scene)
            }
        }

        // Partial match
        let matches = data.scenes.filter { scene in
            scene.name.lowercased().normalizedForComparison().contains(loweredName)
        }

        if matches.count == 1 {
            return .scene(matches[0])
        }

        return .notFound("scene.\(name)")
    }

    private static func resolveGroup(_ query: String, groups: [DeviceGroup], data: MenuData) -> ResolveResult? {
        let lowered = query.lowercased().normalizedForComparison()

        // Check for group. prefix
        if lowered.hasPrefix("group.") {
            let groupName = String(query.dropFirst(6))
            return findGroupByName(groupName, groups: groups, data: data)
        }

        // Also check direct group name match (exact only to avoid conflicts with devices)
        for group in groups {
            if group.name.lowercased().normalizedForComparison() == lowered {
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
        let loweredName = name.lowercased().normalizedForComparison()

        // Exact match first
        for group in groups {
            if group.name.lowercased().normalizedForComparison() == loweredName {
                let services = group.resolveServices(in: data)
                if services.isEmpty {
                    return .notFound("group.\(name)")
                }
                return .services(services)
            }
        }

        // Partial match
        let matches = groups.filter { group in
            group.name.lowercased().normalizedForComparison().contains(loweredName)
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

    /// Resolve room-scoped group format: "Room/group.Name"
    private static func resolveRoomScopedGroup(_ query: String, in data: MenuData, groups: [DeviceGroup]) -> ResolveResult? {
        // Only handle queries with "/" separator that contain "group."
        guard query.contains("/") else { return nil }

        let parts = query.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let roomPart = String(parts[0])
        let targetPart = String(parts[1])

        // Check if target part is a group reference
        let loweredTarget = targetPart.lowercased()
        guard loweredTarget.hasPrefix("group.") else { return nil }

        let groupName = String(targetPart.dropFirst(6))
        let loweredGroupName = groupName.lowercased().normalizedForComparison()
        let loweredRoom = roomPart.lowercased().normalizedForComparison()

        // Find the room
        guard let room = data.rooms.first(where: { $0.name.lowercased().normalizedForComparison() == loweredRoom }) else {
            return .notFound(query)
        }

        // First try to find a group with matching name AND roomId
        let roomScopedGroup = groups.first { group in
            group.name.lowercased().normalizedForComparison() == loweredGroupName && group.roomId == room.uniqueIdentifier
        }

        if let group = roomScopedGroup {
            let services = group.resolveServices(in: data)
            if services.isEmpty {
                return .notFound(query)
            }
            return .services(services)
        }

        // Fall back to global group (roomId == nil) with matching name
        let globalGroup = groups.first { group in
            group.name.lowercased().normalizedForComparison() == loweredGroupName && group.roomId == nil
        }

        if let group = globalGroup {
            let services = group.resolveServices(in: data)
            if services.isEmpty {
                return .notFound(query)
            }
            return .services(services)
        }

        return .notFound(query)
    }

    private static func resolveRoomAndDeviceName(_ query: String, in data: MenuData) -> ResolveResult? {
        // Try splitting by "/" first, then by space
        let separators: [Character] = ["/", " "]

        for separator in separators {
            let parts = query.split(separator: separator, maxSplits: 1)
            guard parts.count == 2 else { continue }

            let roomPart = String(parts[0]).lowercased().normalizedForComparison()
            let devicePart = String(parts[1]).lowercased().normalizedForComparison()

            // Find matching room
            let roomMatches = data.rooms.filter { room in
                let name = room.name.lowercased().normalizedForComparison()
                return name == roomPart || name.contains(roomPart)
            }

            guard !roomMatches.isEmpty else { continue }

            let roomIds = Set(roomMatches.map(\.uniqueIdentifier))

            // Find services in that room matching the device name
            var matchingServices: [ServiceData] = []
            for accessory in data.accessories {
                for service in accessory.services {
                    let name = service.name.lowercased().normalizedForComparison()
                    if let roomId = service.roomIdentifier,
                       roomIds.contains(roomId),
                       (name == devicePart || name.contains(devicePart)) {
                        matchingServices.append(service)
                    }
                }
            }

            if matchingServices.count == 1 {
                return .services(matchingServices)
            } else if matchingServices.count > 1 {
                // Prefer exact name match
                let exactMatches = matchingServices.filter { $0.name.lowercased().normalizedForComparison() == devicePart }
                if exactMatches.count == 1 {
                    return .services(exactMatches)
                }
                return .ambiguous(matchingServices)
            }
        }

        return nil
    }
}
