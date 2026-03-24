//
//  HubitatPlatform+Actions.swift
//  Itsyhome
//
//  Action execution: scenes, characteristic reads/writes
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatPlatform")

extension HubitatPlatform {

    // MARK: - Actions

    func executeScene(identifier: UUID) {
        logger.warning("Scenes not supported on Hubitat")
    }

    func readCharacteristic(identifier: UUID) {
        guard let deviceId = mapper.getDeviceIdFromCharacteristic(identifier) else { return }
        let values = mapper.getCharacteristicValues(for: deviceId)
        if let value = values[identifier] {
            delegate?.platformDidUpdateCharacteristic(self, identifier: identifier, value: value)
        }
    }

    func writeCharacteristic(identifier: UUID, value: Any) {
        guard let client = client else { return }

        guard let deviceId = mapper.getDeviceIdFromCharacteristic(identifier) else {
            logger.error("Device not found for characteristic: \(identifier)")
            return
        }

        logger.info("Writing characteristic for device \(deviceId, privacy: .public)")

        Task {
            do {
                try await writeValueToDevice(client: client, deviceId: deviceId, characteristicUUID: identifier, value: value)
            } catch {
                logger.error("Failed to write characteristic: \(error.localizedDescription)")
                delegate?.platformDidEncounterError(self, message: error.localizedDescription)
            }
        }
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        guard let deviceId = mapper.getDeviceIdFromCharacteristic(identifier) else { return nil }
        return mapper.getCharacteristicValues(for: deviceId)[identifier]
    }

    // MARK: - Device write dispatch

    private func writeValueToDevice(client: HubitatClient, deviceId: String, characteristicUUID: UUID, value: Any) async throws {
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, deviceId: deviceId)
        logger.info("Writing characteristic '\(characteristicType)' = \(String(describing: value)) for device \(deviceId, privacy: .public)")

        switch characteristicType {

        case "power":
            guard let isOn = value as? Bool else { return }
            try await client.sendCommand(deviceId: deviceId, command: isOn ? "on" : "off")

        case "brightness":
            let level: Int
            if let i = value as? Int { level = i }
            else if let d = value as? Double { level = Int(d) }
            else { return }
            try await client.sendCommand(deviceId: deviceId, command: "setLevel", value: "\(level)")

        case "hue":
            // Convert from 0-360 to Hubitat 0-100
            let hue: Double
            if let d = value as? Double { hue = d }
            else if let i = value as? Int { hue = Double(i) }
            else if let f = value as? Float { hue = Double(f) }
            else { return }
            let hubitatHue = Int(hue * 100.0 / 360.0)
            try await client.sendCommand(deviceId: deviceId, command: "setHue", value: "\(hubitatHue)")

        case "saturation":
            let saturation: Int
            if let i = value as? Int { saturation = i }
            else if let d = value as? Double { saturation = Int(d) }
            else if let f = value as? Float { saturation = Int(f) }
            else { return }
            try await client.sendCommand(deviceId: deviceId, command: "setSaturation", value: "\(saturation)")

        case "color_temp":
            // Convert from mireds to Kelvin
            let mireds: Int
            if let i = value as? Int { mireds = i }
            else if let d = value as? Double { mireds = Int(d) }
            else { return }
            guard mireds > 0 else { return }
            let kelvin = 1_000_000 / mireds
            try await client.sendCommand(deviceId: deviceId, command: "setColorTemperature", value: "\(kelvin)")

        case "lock_target":
            guard let targetState = value as? Int else { return }
            try await client.sendCommand(deviceId: deviceId, command: targetState == 1 ? "lock" : "unlock")

        case "target_temp":
            let temp: Double
            if let d = value as? Double { temp = d }
            else if let i = value as? Int { temp = Double(i) }
            else if let f = value as? Float { temp = Double(f) }
            else { return }
            let nativeTemp = mapper.denormalizeTemperature(temp)
            // Use mode-aware setpoint command: setHeatingSetpoint for heat, setCoolingSetpoint for cool
            let currentMode = mapper.getCurrentThermostatMode(for: deviceId)
            let setpointCommand: String
            switch currentMode {
            case "cool": setpointCommand = "setCoolingSetpoint"
            case "heat", "emergency heat": setpointCommand = "setHeatingSetpoint"
            default: setpointCommand = "setHeatingSetpoint"  // Safe default
            }
            try await client.sendCommand(deviceId: deviceId, command: setpointCommand, value: "\(nativeTemp)")

        case "hvac_mode":
            let modeString: String
            if let mode = value as? Int {
                switch mode {
                case 0: modeString = "off"
                case 1: modeString = "heat"
                case 2: modeString = "cool"
                case 3: modeString = "auto"
                default: modeString = "off"
                }
            } else if let s = value as? String {
                modeString = s
            } else { return }
            try await client.sendCommand(deviceId: deviceId, command: "setThermostatMode", value: modeString)

        case "target_temp_high":
            let temp: Double
            if let d = value as? Double { temp = d }
            else if let i = value as? Int { temp = Double(i) }
            else if let f = value as? Float { temp = Double(f) }
            else { return }
            let nativeTemp = mapper.denormalizeTemperature(temp)
            try await client.sendCommand(deviceId: deviceId, command: "setCoolingSetpoint", value: "\(nativeTemp)")

        case "target_temp_low":
            let temp: Double
            if let d = value as? Double { temp = d }
            else if let i = value as? Int { temp = Double(i) }
            else if let f = value as? Float { temp = Double(f) }
            else { return }
            let nativeTemp = mapper.denormalizeTemperature(temp)
            try await client.sendCommand(deviceId: deviceId, command: "setHeatingSetpoint", value: "\(nativeTemp)")

        case "target_position":
            guard let position = value as? Int else { return }
            if position == -1 {
                try await client.sendCommand(deviceId: deviceId, command: "stopPositionChange")
            } else {
                try await client.sendCommand(deviceId: deviceId, command: "setPosition", value: "\(position)")
            }

        case "target_door":
            guard let targetDoor = value as? Int else { return }
            try await client.sendCommand(deviceId: deviceId, command: targetDoor == 0 ? "open" : "close")

        case "valve_state", "active":
            let open: Bool
            if let b = value as? Bool { open = b }
            else if let i = value as? Int { open = i == 1 }
            else { return }
            try await client.sendCommand(deviceId: deviceId, command: open ? "open" : "close")

        case "speed":
            if let speed = value as? Int {
                // Map percentage to Hubitat speed names for FanControl devices,
                // fall back to setLevel for SwitchLevel-based fans
                if speed == 0 {
                    try await client.sendCommand(deviceId: deviceId, command: "off")
                } else if speed <= 20 {
                    try await client.sendCommand(deviceId: deviceId, command: "setSpeed", value: "low")
                } else if speed <= 40 {
                    try await client.sendCommand(deviceId: deviceId, command: "setSpeed", value: "medium-low")
                } else if speed <= 60 {
                    try await client.sendCommand(deviceId: deviceId, command: "setSpeed", value: "medium")
                } else if speed <= 80 {
                    try await client.sendCommand(deviceId: deviceId, command: "setSpeed", value: "medium-high")
                } else {
                    try await client.sendCommand(deviceId: deviceId, command: "setSpeed", value: "high")
                }
            }

        case "alarm_target":
            let hsmStatus: String
            if let targetState = value as? Int {
                switch targetState {
                case 0: hsmStatus = "armHome"
                case 1: hsmStatus = "armAway"
                case 2: hsmStatus = "armNight"
                case 3: hsmStatus = "disarm"
                default: return
                }
            } else if let s = value as? String {
                hsmStatus = s
            } else { return }
            try await client.setHSM(status: hsmStatus)

        default:
            logger.warning("Unsupported characteristic type for write: \(characteristicType)")
        }
    }
}
