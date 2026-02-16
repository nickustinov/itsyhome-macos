//
//  URLSchemeHandler.swift
//  Itsyhome
//
//  Parses URL scheme commands into ActionParser-compatible strings
//

import Foundation

enum URLSchemeHandler {

    /// Parse a URL into a command string for ActionParser
    ///
    /// URL format: itsyhome://<action>/<target>
    /// Examples:
    ///   - itsyhome://toggle/Office/Spotlights
    ///   - itsyhome://on/Kitchen/Light
    ///   - itsyhome://brightness/50/Bedroom/Lamp
    ///   - itsyhome://scene/Goodnight
    ///
    /// - Parameter url: URL to parse
    /// - Returns: Command string for ActionParser, or nil if invalid
    static func handle(_ url: URL) -> String? {
        guard url.scheme == "itsyhome",
              let action = url.host, !action.isEmpty else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        return parseAction(action, components: pathComponents)
    }

    // MARK: - Action parsing

    private static func parseAction(_ action: String, components: [String]) -> String? {
        switch action {
        case "toggle", "on", "off", "lock", "unlock", "open", "close":
            return parseSimpleAction(action, components: components)

        case "brightness":
            return parseValueAction("brightness", components: components)

        case "position":
            return parseValueAction("position", components: components)

        case "temp":
            return parseValueAction("temperature", components: components)

        case "color":
            return parseColorAction(components: components)

        case "speed":
            return parseValueAction("speed", components: components)

        case "scene":
            return parseSceneAction(components: components)

        default:
            return nil
        }
    }

    /// Parse simple actions: toggle, on, off, lock, unlock, open, close
    /// URL: itsyhome://toggle/Room/Device → "toggle Room/Device"
    private static func parseSimpleAction(_ action: String, components: [String]) -> String? {
        guard !components.isEmpty else {
            return nil
        }
        let target = components.joined(separator: "/").removingPercentEncoding ?? components.joined(separator: "/")
        return "\(action) \(target)"
    }

    /// Parse value actions: brightness, position, temperature
    /// URL: itsyhome://brightness/50/Room/Device → "set brightness 50 Room/Device"
    private static func parseValueAction(_ property: String, components: [String]) -> String? {
        guard components.count >= 2 else {
            return nil
        }
        let value = components[0]
        let target = components.dropFirst().joined(separator: "/").removingPercentEncoding
            ?? components.dropFirst().joined(separator: "/")
        return "set \(property) \(value) \(target)"
    }

    /// Parse color action with hue and saturation
    /// URL: itsyhome://color/120/100/Room/Device → "set color 120 100 Room/Device"
    private static func parseColorAction(components: [String]) -> String? {
        guard components.count >= 3 else {
            return nil
        }
        let hue = components[0]
        let saturation = components[1]
        let target = components.dropFirst(2).joined(separator: "/").removingPercentEncoding
            ?? components.dropFirst(2).joined(separator: "/")
        return "set color \(hue) \(saturation) \(target)"
    }

    /// Parse scene action
    /// URL: itsyhome://scene/Goodnight → "execute Goodnight"
    private static func parseSceneAction(components: [String]) -> String? {
        guard !components.isEmpty else {
            return nil
        }
        let sceneName = components.joined(separator: "/").removingPercentEncoding
            ?? components.joined(separator: "/")
        return "execute \(sceneName)"
    }
}
