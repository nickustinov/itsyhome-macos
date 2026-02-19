//
//  HomeAssistantPlatform+Actions.swift
//  Itsyhome
//
//  Action execution: scenes, characteristic reads/writes
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeAssistantPlatform")

extension HomeAssistantPlatform {

    // MARK: - Actions

    func executeScene(identifier: UUID) {
        guard let client = client else { return }

        // Find scene entity ID from UUID
        let sceneEntityId = findEntityId(for: identifier, domain: "scene")
        guard let entityId = sceneEntityId else {
            logger.error("Scene not found for identifier: \(identifier)")
            return
        }

        logger.info("Executing scene: \(entityId, privacy: .public)")

        Task {
            do {
                try await client.callService(
                    domain: "scene",
                    service: "turn_on",
                    target: ["entity_id": entityId]
                )
            } catch {
                logger.error("Failed to execute scene: \(error.localizedDescription)")
                delegate?.platformDidEncounterError(self, message: error.localizedDescription)
            }
        }
    }

    func readCharacteristic(identifier: UUID) {
        // HA doesn't have explicit read - values come via state subscriptions
        // Trigger a state refresh if needed
        if let entityId = mapper.getEntityIdFromCharacteristic(identifier) {
            // State is already cached, just notify
            let values = mapper.getCharacteristicValues(for: entityId)
            if let value = values[identifier] {
                delegate?.platformDidUpdateCharacteristic(self, identifier: identifier, value: value)
            }
        }
    }

    func writeCharacteristic(identifier: UUID, value: Any) {
        guard let client = client else { return }

        guard let entityId = mapper.getEntityIdFromCharacteristic(identifier) else {
            logger.error("Entity not found for characteristic: \(identifier)")
            return
        }

        logger.info("Writing characteristic for \(entityId, privacy: .public)")

        Task {
            do {
                try await writeValueToEntity(client: client, entityId: entityId, characteristicUUID: identifier, value: value)
            } catch {
                logger.error("Failed to write characteristic: \(error.localizedDescription)")
                delegate?.platformDidEncounterError(self, message: error.localizedDescription)
            }
        }
    }

    private func writeValueToEntity(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let domain = entityId.components(separatedBy: ".").first ?? ""

        switch domain {
        case "light":
            try await writeLightValue(client: client, entityId: entityId, characteristicUUID: characteristicUUID, value: value)

        case "switch":
            if let isOn = value as? Bool {
                try await client.callService(
                    domain: "switch",
                    service: isOn ? "turn_on" : "turn_off",
                    target: ["entity_id": entityId]
                )
            }

        case "climate":
            try await writeClimateValue(client: client, entityId: entityId, characteristicUUID: characteristicUUID, value: value)

        case "cover":
            try await writeCoverValue(client: client, entityId: entityId, characteristicUUID: characteristicUUID, value: value)

        case "lock":
            if let targetState = value as? Int {
                try await client.callService(
                    domain: "lock",
                    service: targetState == 1 ? "lock" : "unlock",
                    target: ["entity_id": entityId]
                )
            }

        case "fan":
            try await writeFanValue(client: client, entityId: entityId, characteristicUUID: characteristicUUID, value: value)

        case "humidifier":
            try await writeHumidifierValue(client: client, entityId: entityId, characteristicUUID: characteristicUUID, value: value)

        case "valve":
            try await writeValveValue(client: client, entityId: entityId, characteristicUUID: characteristicUUID, value: value)

        case "alarm_control_panel":
            try await writeAlarmValue(client: client, entityId: entityId, value: value)

        default:
            logger.warning("Unsupported domain for write: \(domain)")
        }
    }

    private func writeLightValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)
        logger.info("Writing light characteristic '\(characteristicType)' = \(String(describing: value)) for \(entityId)")

        switch characteristicType {
        case "power":
            if let isOn = value as? Bool {
                try await client.callService(
                    domain: "light",
                    service: isOn ? "turn_on" : "turn_off",
                    target: ["entity_id": entityId]
                )
            }

        case "brightness":
            // Convert from 0-100 to 0-255
            let brightness: Int
            if let b = value as? Int {
                brightness = b
            } else if let b = value as? Double {
                brightness = Int(b)
            } else {
                return
            }
            let haBrightness = Int(Double(brightness) * 2.55)
            try await client.callService(
                domain: "light",
                service: "turn_on",
                serviceData: ["brightness": haBrightness],
                target: ["entity_id": entityId]
            )

        case "hue":
            let hue: Double
            if let h = value as? Double {
                hue = h
            } else if let h = value as? Int {
                hue = Double(h)
            } else if let h = value as? Float {
                hue = Double(h)
            } else {
                return
            }

            // Thread-safe access to pending values
            let saturation: Double = pendingColorLock.withLock {
                // Store pending hue for subsequent saturation writes
                pendingHue[entityId] = hue

                // Get saturation: prefer pending value, then cached value
                if let pendingSat = pendingSaturation[entityId] {
                    return pendingSat
                } else {
                    let currentValues = mapper.getCharacteristicValues(for: entityId)
                    let satUUID = mapper.characteristicUUID(entityId, "saturation")
                    return (currentValues[satUUID] as? Double) ?? 100.0
                }
            }

            // HA expects hs_color as [hue (0-360), saturation (0-100)]
            try await client.callService(
                domain: "light",
                service: "turn_on",
                serviceData: ["hs_color": [hue, saturation]],
                target: ["entity_id": entityId]
            )

        case "saturation":
            let saturation: Double
            if let s = value as? Double {
                saturation = s
            } else if let s = value as? Int {
                saturation = Double(s)
            } else if let s = value as? Float {
                saturation = Double(s)
            } else {
                return
            }

            // Thread-safe access to pending values
            let hue: Double = pendingColorLock.withLock {
                // Store pending saturation for subsequent hue writes
                pendingSaturation[entityId] = saturation

                // Get hue: prefer pending value, then cached value
                if let pendingH = pendingHue[entityId] {
                    return pendingH
                } else {
                    let currentValues = mapper.getCharacteristicValues(for: entityId)
                    let hueUUID = mapper.characteristicUUID(entityId, "hue")
                    return (currentValues[hueUUID] as? Double) ?? 0.0
                }
            }

            try await client.callService(
                domain: "light",
                service: "turn_on",
                serviceData: ["hs_color": [hue, saturation]],
                target: ["entity_id": entityId]
            )

        case "color_temp":
            // Convert mireds to kelvin
            let mireds: Int
            if let m = value as? Int {
                mireds = m
            } else if let m = value as? Double {
                mireds = Int(m)
            } else {
                return
            }
            let kelvin = 1_000_000 / mireds
            try await client.callService(
                domain: "light",
                service: "turn_on",
                serviceData: ["color_temp_kelvin": kelvin],
                target: ["entity_id": entityId]
            )

        default:
            logger.warning("Unknown light characteristic type: \(characteristicType)")
        }
    }

    private func writeClimateValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        // Determine which characteristic is being written based on UUID
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)

        switch characteristicType {
        case "hvac_mode":
            // Get available HVAC modes for this entity
            let availableModes = mapper.getAvailableHVACModes(for: entityId)

            let hvacMode: String

            // Handle direct string mode (HA dynamic modes like dry, fan_only)
            if let modeString = value as? String {
                if availableModes.contains(modeString) {
                    hvacMode = modeString
                } else {
                    logger.warning("Mode '\(modeString)' not available for \(entityId). Available: \(availableModes)")
                    return
                }
            } else if let mode = value as? Int {
                // HomeKit-style integer mode: 0=off, 1=heat, 2=cool, 3=auto
                switch mode {
                case 0:
                    hvacMode = "off"
                case 1:
                    // Heat mode - must have actual heat support
                    if availableModes.contains("heat") {
                        hvacMode = "heat"
                    } else {
                        logger.warning("Heat mode not available for \(entityId). Available: \(availableModes)")
                        return
                    }
                case 2:
                    // Cool mode
                    if availableModes.contains("cool") {
                        hvacMode = "cool"
                    } else {
                        logger.warning("Cool mode not available for \(entityId). Available: \(availableModes)")
                        return
                    }
                case 3:
                    // Auto mode - try heat_cool first, then auto
                    if availableModes.contains("heat_cool") {
                        hvacMode = "heat_cool"
                    } else if availableModes.contains("auto") {
                        hvacMode = "auto"
                    } else {
                        logger.warning("No auto mode available for \(entityId)")
                        return
                    }
                default:
                    hvacMode = "off"
                }
            } else {
                logger.warning("Invalid HVAC mode value type: \(type(of: value))")
                return
            }

            logger.info("Setting HVAC mode to '\(hvacMode)' (available: \(availableModes))")

            try await client.callService(
                domain: "climate",
                service: "set_hvac_mode",
                serviceData: ["hvac_mode": hvacMode],
                target: ["entity_id": entityId]
            )
            logger.debug("HVAC mode set_hvac_mode service call completed")

        case "target_temp", "target_temp_high", "target_temp_low":
            // Temperature change - accept Int or Double (value is in Celsius internally)
            let temp: Double
            if let d = value as? Double {
                temp = d
            } else if let i = value as? Int {
                temp = Double(i)
            } else if let f = value as? Float {
                temp = Double(f)
            } else {
                return
            }

            if characteristicType == "target_temp_high" || characteristicType == "target_temp_low" {
                // HA requires both temps sent together for dual setpoint
                // Get current values from mapper (already in Celsius)
                let currentValues = mapper.getCharacteristicValues(for: entityId)
                let highUUID = mapper.characteristicUUID(entityId, "target_temp_high")
                let lowUUID = mapper.characteristicUUID(entityId, "target_temp_low")

                var currentHigh = (currentValues[highUUID] as? Double) ?? 24.0
                var currentLow = (currentValues[lowUUID] as? Double) ?? 18.0

                // Update the one being changed
                if characteristicType == "target_temp_high" {
                    currentHigh = temp
                } else {
                    currentLow = temp
                }

                // Convert back to HA's unit before sending
                let haLow = denormalizeTemperature(currentLow)
                let haHigh = denormalizeTemperature(currentHigh)

                logger.info("Setting temperature range: low=\(haLow), high=\(haHigh)")

                try await client.callService(
                    domain: "climate",
                    service: "set_temperature",
                    serviceData: ["target_temp_low": haLow, "target_temp_high": haHigh],
                    target: ["entity_id": entityId]
                )
            } else {
                // Single temperature setpoint - convert back to HA's unit
                let haTemp = denormalizeTemperature(temp)
                try await client.callService(
                    domain: "climate",
                    service: "set_temperature",
                    serviceData: ["temperature": haTemp],
                    target: ["entity_id": entityId]
                )
            }

        case "swing_mode":
            // Toggle swing mode between "off" and "auto"
            let swingMode = (value as? Int == 1) ? "auto" : "off"
            try await client.callService(
                domain: "climate",
                service: "set_swing_mode",
                serviceData: ["swing_mode": swingMode],
                target: ["entity_id": entityId]
            )

        default:
            logger.warning("Unknown climate characteristic type: \(characteristicType)")
        }
    }

    private func writeCoverValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let features = mapper.getCoverSupportedFeatures(for: entityId)
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)

        // Check if this is a tilt-only cover (has tilt but no position/open/close)
        let isTiltOnly = (features & 128) != 0 && (features & 4) == 0 && (features & 3) == 0

        // Handle tilt characteristic separately - value is already 0-100
        if characteristicType == "tilt" || characteristicType == "target_tilt" {
            guard let tiltPosition = value as? Int else { return }
            if features & 128 != 0 {
                try await client.callService(
                    domain: "cover",
                    service: "set_cover_tilt_position",
                    serviceData: ["tilt_position": max(0, min(100, tiltPosition))],
                    target: ["entity_id": entityId]
                )
            }
            return
        }

        // Handle garage door target state (0=open, 1=closed)
        if characteristicType == "target_door" {
            guard let targetDoor = value as? Int else { return }
            try await client.callService(
                domain: "cover",
                service: targetDoor == 0 ? "open_cover" : "close_cover",
                target: ["entity_id": entityId]
            )
            return
        }

        // Handle position-based covers
        if let position = value as? Int {
            // Special value -1 means stop
            if position == -1 {
                if isTiltOnly && (features & 64) != 0 {
                    // STOP_TILT is bit 64
                    try await client.callService(
                        domain: "cover",
                        service: "stop_cover_tilt",
                        target: ["entity_id": entityId]
                    )
                } else if features & 8 != 0 {
                    // STOP is bit 8
                    try await client.callService(
                        domain: "cover",
                        service: "stop_cover",
                        target: ["entity_id": entityId]
                    )
                }
                return
            }

            if isTiltOnly {
                // Tilt-only cover: use tilt commands
                if features & 128 != 0 {
                    // SET_TILT_POSITION supported
                    try await client.callService(
                        domain: "cover",
                        service: "set_cover_tilt_position",
                        serviceData: ["tilt_position": position],
                        target: ["entity_id": entityId]
                    )
                } else {
                    // Use open_cover_tilt/close_cover_tilt
                    try await client.callService(
                        domain: "cover",
                        service: position >= 50 ? "open_cover_tilt" : "close_cover_tilt",
                        target: ["entity_id": entityId]
                    )
                }
            } else if features & 4 != 0 {
                // SET_POSITION supported
                try await client.callService(
                    domain: "cover",
                    service: "set_cover_position",
                    serviceData: ["position": position],
                    target: ["entity_id": entityId]
                )
            } else if features & 3 != 0 {
                // OPEN/CLOSE supported (bits 0,1)
                try await client.callService(
                    domain: "cover",
                    service: position >= 50 ? "open_cover" : "close_cover",
                    target: ["entity_id": entityId]
                )
            }
        }
    }

    private func writeValveValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)

        switch characteristicType {
        case "active":
            if let isActive = value as? Bool {
                try await client.callService(
                    domain: "valve",
                    service: isActive ? "open_valve" : "close_valve",
                    target: ["entity_id": entityId]
                )
            } else if let intValue = value as? Int {
                try await client.callService(
                    domain: "valve",
                    service: intValue == 1 ? "open_valve" : "close_valve",
                    target: ["entity_id": entityId]
                )
            }

        case "target_position":
            if let position = value as? Int {
                if position == -1 {
                    // Stop command
                    try await client.callService(
                        domain: "valve",
                        service: "stop_valve",
                        target: ["entity_id": entityId]
                    )
                } else {
                    try await client.callService(
                        domain: "valve",
                        service: "set_valve_position",
                        serviceData: ["position": max(0, min(100, position))],
                        target: ["entity_id": entityId]
                    )
                }
            }

        default:
            logger.warning("Unknown valve characteristic type: \(characteristicType)")
        }
    }

    private func writeFanValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)

        switch characteristicType {
        case "power":
            if let isOn = value as? Bool {
                try await client.callService(
                    domain: "fan",
                    service: isOn ? "turn_on" : "turn_off",
                    target: ["entity_id": entityId]
                )
            }

        case "speed":
            if let speed = value as? Int {
                try await client.callService(
                    domain: "fan",
                    service: "set_percentage",
                    serviceData: ["percentage": speed],
                    target: ["entity_id": entityId]
                )
            }

        case "oscillating", "swing_mode":
            if let oscillating = value as? Int {
                try await client.callService(
                    domain: "fan",
                    service: "oscillate",
                    serviceData: ["oscillating": oscillating == 1],
                    target: ["entity_id": entityId]
                )
            }

        case "direction":
            if let direction = value as? Int {
                try await client.callService(
                    domain: "fan",
                    service: "set_direction",
                    serviceData: ["direction": direction == 0 ? "forward" : "reverse"],
                    target: ["entity_id": entityId]
                )
            }

        default:
            logger.warning("Unknown fan characteristic type: \(characteristicType)")
        }
    }

    private func writeHumidifierValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)

        switch characteristicType {
        case "power":
            if let isOn = value as? Bool {
                try await client.callService(
                    domain: "humidifier",
                    service: isOn ? "turn_on" : "turn_off",
                    target: ["entity_id": entityId]
                )
            }

        case "target_humidity":
            if let humidity = value as? Int {
                try await client.callService(
                    domain: "humidifier",
                    service: "set_humidity",
                    serviceData: ["humidity": humidity],
                    target: ["entity_id": entityId]
                )
            }

        case "hum_mode":
            if let mode = value as? String {
                try await client.callService(
                    domain: "humidifier",
                    service: "set_mode",
                    serviceData: ["mode": mode],
                    target: ["entity_id": entityId]
                )
            }

        default:
            logger.warning("Unknown humidifier characteristic type: \(characteristicType)")
        }
    }

    private func writeAlarmValue(client: HomeAssistantClient, entityId: String, value: Any) async throws {
        var service: String
        var code: String?

        // Handle different value formats
        if let dict = value as? [String: Any],
           let mode = dict["mode"] as? String {
            // HA format with mode string and optional code
            code = dict["code"] as? String
            switch mode {
            case "armed_home": service = "alarm_arm_home"
            case "armed_away": service = "alarm_arm_away"
            case "armed_night": service = "alarm_arm_night"
            case "armed_vacation": service = "alarm_arm_vacation"
            case "armed_custom_bypass": service = "alarm_arm_custom_bypass"
            case "disarmed": service = "alarm_disarm"
            default: return
            }
        } else if let modeString = value as? String {
            // Direct mode string
            switch modeString {
            case "armed_home": service = "alarm_arm_home"
            case "armed_away": service = "alarm_arm_away"
            case "armed_night": service = "alarm_arm_night"
            case "armed_vacation": service = "alarm_arm_vacation"
            case "armed_custom_bypass": service = "alarm_arm_custom_bypass"
            case "disarmed": service = "alarm_disarm"
            default: return
            }
        } else if let targetState = value as? Int {
            // HomeKit-style integer
            switch targetState {
            case 0: service = "alarm_arm_home"
            case 1: service = "alarm_arm_away"
            case 2: service = "alarm_arm_night"
            case 3: service = "alarm_disarm"
            default: return
            }
        } else {
            return
        }

        // Check if alarm requires a code and we don't have one
        let requiresCode = mapper.alarmRequiresCode(for: entityId)
        if requiresCode && service != "alarm_disarm" && code == nil {
            logger.warning("Alarm panel requires a code to arm - skipping")
            delegate?.platformDidEncounterError(self, message: "This alarm panel requires a code to arm.")
            return
        }

        // Build service data
        var serviceData: [String: Any] = [:]
        if let code = code {
            serviceData["code"] = code
        }

        try await client.callService(
            domain: "alarm_control_panel",
            service: service,
            serviceData: serviceData.isEmpty ? nil : serviceData,
            target: ["entity_id": entityId]
        )
    }

    /// Convert a temperature from internal Celsius back to HA's configured unit
    private func denormalizeTemperature(_ celsius: Double) -> Double {
        if mapper.haTemperatureUnit == "°F" {
            return celsius * 9.0 / 5.0 + 32.0
        }
        return celsius
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        guard let entityId = mapper.getEntityIdFromCharacteristic(identifier) else { return nil }
        return mapper.getCharacteristicValues(for: entityId)[identifier]
    }
}
