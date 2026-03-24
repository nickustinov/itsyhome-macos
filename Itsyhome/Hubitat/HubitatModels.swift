//
//  HubitatModels.swift
//  Itsyhome
//
//  Hubitat Maker API data models
//

import Foundation

// MARK: - Device Summary

/// Brief device listing from the /devices endpoint
struct HubitatDeviceSummary {
    let id: String
    let name: String
    let label: String?

    init?(json: [String: Any]) {
        // id can come as String or Int — normalize to String
        if let idString = json["id"] as? String {
            self.id = idString
        } else if let idInt = json["id"] as? Int {
            self.id = String(idInt)
        } else {
            return nil
        }

        guard let name = json["name"] as? String else { return nil }
        self.name = name

        let labelRaw = json["label"] as? String
        self.label = (labelRaw?.isEmpty == false) ? labelRaw : nil
    }
}

// MARK: - Command

/// A command supported by a Hubitat device
struct HubitatCommand {
    let command: String
    let parameterTypes: [String]?

    init?(json: [String: Any]) {
        guard let command = json["command"] as? String else { return nil }
        self.command = command
        self.parameterTypes = json["type"] as? [String]
    }
}

// MARK: - Device

/// Full device detail from /devices/all or /devices/{id}
struct HubitatDevice {
    let id: String
    let name: String
    let label: String?
    let type: String?
    let manufacturer: String?
    let model: String?
    let roomId: String?
    let roomName: String?
    let capabilities: [String]
    let attributes: [String: Any]
    let commands: [HubitatCommand]

    /// Returns label if non-empty, otherwise name
    var displayName: String {
        if let label = label, !label.isEmpty {
            return label
        }
        return name
    }

    func hasCapability(_ capability: String) -> Bool {
        capabilities.contains(capability)
    }

    /// Returns the attribute value coerced to String, or nil if absent
    func attributeString(_ name: String) -> String? {
        guard let value = attributes[name] else { return nil }
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return String(describing: value)
    }

    /// Returns the attribute value coerced to Double, or nil if absent or not numeric
    func attributeDouble(_ name: String) -> Double? {
        guard let value = attributes[name] else { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    /// Returns the attribute value coerced to Int, or nil if absent or not numeric
    func attributeInt(_ name: String) -> Int? {
        guard let value = attributes[name] else { return nil }
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    init?(json: [String: Any]) {
        // id can come as String or Int — normalize to String
        if let idString = json["id"] as? String {
            self.id = idString
        } else if let idInt = json["id"] as? Int {
            self.id = String(idInt)
        } else {
            return nil
        }

        guard let name = json["name"] as? String else { return nil }
        self.name = name

        let labelRaw = json["label"] as? String
        self.label = (labelRaw?.isEmpty == false) ? labelRaw : nil

        self.type = json["type"] as? String
        self.manufacturer = json["manufacturer"] as? String
        self.model = json["model"] as? String

        // Room assignment — roomId can be Int or String, 0/null means unassigned
        if let roomInt = json["roomId"] as? Int, roomInt != 0 {
            self.roomId = String(roomInt)
        } else if let roomStr = json["roomId"] as? String, !roomStr.isEmpty, roomStr != "0" {
            self.roomId = roomStr
        } else {
            self.roomId = nil
        }
        let roomNameRaw = json["room"] as? String
        self.roomName = (roomNameRaw?.isEmpty == false) ? roomNameRaw : nil

        // capabilities items can be plain strings or objects with a "name" key
        if let rawCapabilities = json["capabilities"] as? [Any] {
            self.capabilities = rawCapabilities.compactMap { item in
                if let s = item as? String { return s }
                if let obj = item as? [String: Any], let capName = obj["name"] as? String { return capName }
                return nil
            }
        } else {
            self.capabilities = []
        }

        self.attributes = json["attributes"] as? [String: Any] ?? [:]

        if let rawCommands = json["commands"] as? [[String: Any]] {
            self.commands = rawCommands.compactMap { HubitatCommand(json: $0) }
        } else {
            self.commands = []
        }
    }
}

// MARK: - Event

/// A device or system event from the EventSocket WebSocket
struct HubitatEvent {
    let source: String
    let name: String
    let displayName: String?
    let value: String
    let deviceId: String?
    let descriptionText: String?
    let unit: String?
    let type: String?
    let data: String?

    /// True when this event originates from a device
    var isDeviceEvent: Bool {
        source == "DEVICE" && deviceId != nil
    }

    init?(json: [String: Any]) {
        guard let source = json["source"] as? String,
              let name = json["name"] as? String else {
            return nil
        }

        self.source = source
        self.name = name
        self.displayName = json["displayName"] as? String

        // value can be String, Number, or null — normalize to String
        if let valueString = json["value"] as? String {
            self.value = valueString
        } else if let valueNumber = json["value"] as? NSNumber {
            self.value = valueNumber.stringValue
        } else {
            self.value = ""
        }

        // deviceId can be String or Int — normalize to String
        if let deviceIdString = json["deviceId"] as? String {
            self.deviceId = deviceIdString
        } else if let deviceIdInt = json["deviceId"] as? Int {
            self.deviceId = String(deviceIdInt)
        } else {
            self.deviceId = nil
        }

        self.descriptionText = json["descriptionText"] as? String
        self.unit = json["unit"] as? String
        self.type = json["type"] as? String
        self.data = json["data"] as? String
    }
}

// MARK: - HSM Status

/// Hubitat Safety Monitor status
struct HubitatHSMStatus {
    let status: String

    init?(json: [String: Any]) {
        guard let status = json["hsm"] as? String else { return nil }
        self.status = status
    }
}

// MARK: - Mode

/// A Hubitat location mode
struct HubitatMode {
    let id: String
    let name: String
    let active: Bool

    init?(json: [String: Any]) {
        // id comes as Int from the API — normalize to String
        if let idInt = json["id"] as? Int {
            self.id = String(idInt)
        } else if let idString = json["id"] as? String {
            self.id = idString
        } else {
            return nil
        }

        guard let name = json["name"] as? String else { return nil }
        self.name = name
        self.active = json["active"] as? Bool ?? false
    }
}
