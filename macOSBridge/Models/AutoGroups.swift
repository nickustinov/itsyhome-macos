//
//  AutoGroups.swift
//  macOSBridge
//
//  Synthesized "All lights"-style groups, computed from the accessory list
//

import Foundation

/// Auto groups fold same-kind devices into one controllable group at the
/// menu's top level and inside each room (ported from the iOS app). They are
/// synthesized on every menu build and never persisted – ordering and
/// visibility reference them through deterministic tokens and ids instead,
/// so they survive across sessions and language changes without any storage.
enum AutoGroups {

    struct Definition {
        /// Stable key used in tokens, ids and order lists – never localized.
        let key: String
        let serviceTypes: Set<String>
        let icon: String
    }

    static let definitions: [Definition] = [
        Definition(key: "lights", serviceTypes: [ServiceTypes.lightbulb], icon: "lightbulb"),
        Definition(key: "switches", serviceTypes: [ServiceTypes.switch, ServiceTypes.outlet], icon: "power"),
        Definition(key: "blinds", serviceTypes: [ServiceTypes.windowCovering], icon: "arrows-out-line-vertical"),
        Definition(key: "acs", serviceTypes: [ServiceTypes.thermostat, ServiceTypes.heaterCooler], icon: "thermometer"),
        Definition(key: "fans", serviceTypes: [ServiceTypes.fan, ServiceTypes.fanV2], icon: "fan"),
        Definition(key: "locks", serviceTypes: [ServiceTypes.lock], icon: "lock")
    ]

    static func name(forKey key: String) -> String {
        switch key {
        case "lights":
            return String(localized: "group.auto.all_lights", defaultValue: "All lights", bundle: .macOSBridge)
        case "switches":
            return String(localized: "group.auto.all_switches", defaultValue: "All switches", bundle: .macOSBridge)
        case "blinds":
            return String(localized: "group.auto.all_blinds", defaultValue: "All blinds", bundle: .macOSBridge)
        case "acs":
            return String(localized: "group.auto.all_acs", defaultValue: "All ACs", bundle: .macOSBridge)
        case "fans":
            return String(localized: "group.auto.all_fans", defaultValue: "All fans", bundle: .macOSBridge)
        case "locks":
            return String(localized: "group.auto.all_locks", defaultValue: "All locks", bundle: .macOSBridge)
        default:
            return key
        }
    }

    // MARK: - Tokens and ids

    /// Order-list token ("autogroup:lights"). At the menu's top level the
    /// token lives in menuLayout; inside a room the same token lives in that
    /// room's accessoryOrder list, where the room context is implicit.
    static let tokenPrefix = "autogroup:"

    static func token(forKey key: String) -> String { tokenPrefix + key }

    static var menuTokens: [String] { definitions.map { token(forKey: $0.key) } }

    static func definition(forToken token: String) -> Definition? {
        guard token.hasPrefix(tokenPrefix) else { return nil }
        let key = String(token.dropFirst(tokenPrefix.count))
        return definitions.first { $0.key == key }
    }

    static func homeGroupId(forKey key: String) -> String { "autogroup:home:\(key)" }

    static func roomGroupId(forKey key: String, roomId: String) -> String { "autogroup:room:\(roomId):\(key)" }

    static func isAutoGroupId(_ id: String) -> Bool { id.hasPrefix(tokenPrefix) }

    // MARK: - Synthesis

    /// A group materializes only with 2+ members – controlling one device
    /// through a group is noise.
    static let memberThreshold = 2

    static func group(for definition: Definition, id: String, roomId: String?, services: [ServiceData]) -> DeviceGroup? {
        let members = services.filter { definition.serviceTypes.contains($0.serviceType) }
        guard members.count >= memberThreshold else { return nil }
        return DeviceGroup(
            id: id,
            name: name(forKey: definition.key),
            icon: definition.icon,
            deviceIds: members.map { $0.uniqueIdentifier },
            roomId: roomId,
            showGroupSwitch: true,
            showAsSubmenu: true
        )
    }

    /// Home-level group for a menuLayout token, spanning every visible
    /// accessory in the home.
    static func homeGroup(forToken token: String, accessories: [AccessoryData]) -> DeviceGroup? {
        guard let definition = definition(forToken: token) else { return nil }
        return group(
            for: definition,
            id: homeGroupId(forKey: definition.key),
            roomId: nil,
            services: accessories.flatMap { $0.services }
        )
    }

    /// Room-level group for a token in the room's order list.
    static func roomGroup(forToken token: String, roomId: String, services: [ServiceData]) -> DeviceGroup? {
        guard let definition = definition(forToken: token) else { return nil }
        return group(
            for: definition,
            id: roomGroupId(forKey: definition.key, roomId: roomId),
            roomId: roomId,
            services: services
        )
    }

    /// All materialized groups for a room, in definition order, paired with
    /// their order-list tokens.
    static func roomGroups(roomId: String, services: [ServiceData]) -> [(token: String, group: DeviceGroup)] {
        definitions.compactMap { definition in
            let token = token(forKey: definition.key)
            guard let group = roomGroup(forToken: token, roomId: roomId, services: services) else { return nil }
            return (token, group)
        }
    }
}
