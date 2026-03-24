//
//  HubitatDeviceMapper.swift
//  Itsyhome
//
//  Maps Hubitat device capabilities to Itsyhome ServiceData model
//

import Foundation
import os.log
import CommonCrypto

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatDeviceMapper")

final class HubitatDeviceMapper {

    // MARK: - Properties

    private let lock = NSLock()
    private var devices: [String: HubitatDevice] = [:]
    /// Mutable attribute state — updated by EventSocket events, takes priority over device.attributes
    private var mutableAttributes: [String: [String: Any]] = [:]

    // Reverse lookup caches for O(1) characteristic lookups
    private var characteristicToDevice: [UUID: String] = [:]
    private var serviceToDevice: [UUID: String] = [:]

    /// Temperature unit detected from device attributes (default Fahrenheit for Hubitat)
    private(set) var temperatureUnit: String = "°F"

    // MARK: - Characteristic type list

    private static let characteristicTypes = [
        "power", "brightness", "hue", "saturation", "color_temp",
        "current_temp", "target_temp", "target_temp_high", "target_temp_low",
        "hvac_mode", "hvac_action",
        "lock_state", "lock_target",
        "position", "target_position",
        "door_state", "target_door",
        "active", "valve_state",
        "speed", "humidity"
    ]

    // MARK: - Data loading

    func loadDevices(_ deviceList: [HubitatDevice]) {
        lock.lock()
        devices = Dictionary(uniqueKeysWithValues: deviceList.map { ($0.id, $0) })
        mutableAttributes = Dictionary(uniqueKeysWithValues: deviceList.map { ($0.id, $0.attributes) })

        // Detect temperature unit from any thermostat or temperature sensor
        detectTemperatureUnit()

        // Build reverse lookup caches
        buildCharacteristicCache()
        lock.unlock()

        // Log room stats
        let roomNames = Set(deviceList.compactMap { $0.roomName })
        logger.info("Loaded \(deviceList.count) Hubitat devices, \(roomNames.count) rooms: \(roomNames.sorted())")
    }

    func updateDeviceAttribute(deviceId: String, attributeName: String, value: String) {
        lock.lock()
        guard devices[deviceId] != nil else {
            lock.unlock()
            logger.warning("updateDeviceAttribute: unknown device \(deviceId)")
            return
        }

        // Parse value into appropriate type
        let parsed: Any
        if value == "null" || value.isEmpty {
            parsed = value
        } else if let intVal = Int(value) {
            parsed = intVal
        } else if let doubleVal = Double(value) {
            parsed = doubleVal
        } else {
            parsed = value
        }

        mutableAttributes[deviceId, default: [:]][attributeName] = parsed
        lock.unlock()
    }

    // MARK: - Temperature helpers

    /// Convert a temperature from Hubitat's unit to Celsius for internal storage
    func normalizeTemperature(_ value: Double) -> Double {
        if temperatureUnit == "°F" {
            return (value - 32.0) * 5.0 / 9.0
        }
        return value
    }

    /// Convert Celsius back to Hubitat's native unit
    func denormalizeTemperature(_ celsius: Double) -> Double {
        if temperatureUnit == "°F" {
            return celsius * 9.0 / 5.0 + 32.0
        }
        return celsius
    }

    /// Detect temperature unit from device attributes (look for "°C" in temperature values)
    private func detectTemperatureUnit() {
        for (_, attrs) in mutableAttributes {
            if let tempUnit = attrs["temperatureScale"] as? String {
                if tempUnit.uppercased().contains("C") {
                    temperatureUnit = "°C"
                } else {
                    temperatureUnit = "°F"
                }
                logger.info("Detected Hubitat temperature unit: \(self.temperatureUnit)")
                return
            }
        }
        // Default stays °F
        logger.info("No temperatureScale found, defaulting to \(self.temperatureUnit)")
    }

    // MARK: - Reverse lookup cache

    /// Build reverse lookup caches for fast UUID -> deviceId lookups
    private func buildCharacteristicCache() {
        characteristicToDevice.removeAll()
        serviceToDevice.removeAll()

        for deviceId in devices.keys {
            // Cache service UUID
            serviceToDevice[deterministicUUID(for: "hubitat_device_\(deviceId)")] = deviceId

            // Cache all characteristic UUIDs
            for charType in Self.characteristicTypes {
                characteristicToDevice[characteristicUUID(deviceId, charType)] = deviceId
            }
        }

        logger.debug("Built characteristic cache: \(self.characteristicToDevice.count) characteristics, \(self.serviceToDevice.count) services")
    }

    // MARK: - Room generation

    /// Generate rooms from device room assignments (Maker API includes room/roomId on each device)
    private func generateRooms() -> [RoomData] {
        // Collect unique rooms from all devices
        var roomsById: [String: String] = [:]  // roomId -> roomName
        for device in devices.values {
            if let roomId = device.roomId, let roomName = device.roomName {
                roomsById[roomId] = roomName
            }
        }
        return roomsById
            .sorted { $0.value < $1.value }
            .map { (roomId, roomName) in
                RoomData(
                    uniqueIdentifier: deterministicUUID(for: "hubitat_room_\(roomId)"),
                    name: roomName
                )
            }
    }

    /// Resolve room UUID for a device
    private func roomUUID(for device: HubitatDevice) -> UUID? {
        guard let roomId = device.roomId else { return nil }
        return deterministicUUID(for: "hubitat_room_\(roomId)")
    }

    // MARK: - Menu data generation

    func generateMenuData() -> MenuData {
        lock.lock()
        let roomData = generateRooms()
        let accessoryData = generateAccessories()
        lock.unlock()

        logger.info("Generated menu data: \(roomData.count) rooms, \(accessoryData.count) accessories")

        return MenuData(
            homes: [],
            rooms: roomData,
            accessories: accessoryData,
            scenes: [],
            selectedHomeId: nil,
            hasCameras: false,
            cameras: []
        )
    }

    // MARK: - Accessory generation

    private func generateAccessories() -> [AccessoryData] {
        var accessories: [AccessoryData] = []

        for (_, device) in devices {
            guard let serviceData = mapDeviceToService(device) else { continue }

            let accessoryUUID = deterministicUUID(for: "hubitat_device_\(device.id)")

            accessories.append(AccessoryData(
                uniqueIdentifier: accessoryUUID,
                name: device.displayName,
                roomIdentifier: roomUUID(for: device),
                services: [serviceData],
                isReachable: true
            ))
        }

        return accessories.sorted { $0.name < $1.name }
    }

    // MARK: - Device to service mapping

    private func mapDeviceToService(_ device: HubitatDevice) -> ServiceData? {
        guard let serviceType = mapCapabilitiesToServiceType(device) else { return nil }

        let deviceUUID = deterministicUUID(for: "hubitat_device_\(device.id)")
        let id = device.id

        let hasColorControl = device.hasCapability("ColorControl")
        let hasColorTemp = device.hasCapability("ColorTemperature")
        let hasSwitchLevel = device.hasCapability("SwitchLevel")
        let isThermostat = device.hasCapability("Thermostat") || device.hasCapability("ThermostatMode")
        let isLock = device.hasCapability("Lock")
        let isCover = device.hasCapability("WindowShade") || device.hasCapability("WindowBlind")
        let isGarageDoor = device.hasCapability("GarageDoorControl")
        let isValve = device.hasCapability("Valve")
        let isFan = device.hasCapability("FanControl") || device.hasCapability("Fan")
        let isSwitch = device.hasCapability("Switch")
        let isTempSensor = device.hasCapability("TemperatureMeasurement")
        let isHumiditySensor = device.hasCapability("RelativeHumidityMeasurement")

        let isLight = serviceType == ServiceTypes.lightbulb

        // Color temp defaults in mireds
        let colorTempMin: Double? = (hasColorTemp || hasColorControl) ? 153 : nil  // 6500K
        let colorTempMax: Double? = (hasColorTemp || hasColorControl) ? 500 : nil  // 2000K

        // Determine valid HVAC target states from thermostat supported modes
        let validHVACStates: [Int]? = isThermostat ? [0, 1, 2, 3] : nil  // off, heat, cool, auto

        return ServiceData(
            uniqueIdentifier: deviceUUID,
            name: device.displayName,
            serviceType: serviceType,
            accessoryName: device.displayName,
            roomIdentifier: roomUUID(for: device),
            isReachable: true,
            haEntityId: nil,
            // Light / Switch power
            powerStateId: (isLight || isSwitch || isFan) && serviceType != ServiceTypes.temperatureSensor && serviceType != ServiceTypes.humiditySensor ? characteristicUUID(id, "power") : nil,
            // Light brightness
            brightnessId: isLight && (hasSwitchLevel || hasColorControl || hasColorTemp) ? characteristicUUID(id, "brightness") : nil,
            // Light color
            hueId: hasColorControl && isLight ? characteristicUUID(id, "hue") : nil,
            saturationId: hasColorControl && isLight ? characteristicUUID(id, "saturation") : nil,
            colorTemperatureId: (hasColorTemp || hasColorControl) && isLight ? characteristicUUID(id, "color_temp") : nil,
            colorTemperatureMin: colorTempMin,
            colorTemperatureMax: colorTempMax,
            // Thermostat / Temperature sensor
            currentTemperatureId: isThermostat || (serviceType == ServiceTypes.temperatureSensor) ? characteristicUUID(id, "current_temp") : nil,
            targetTemperatureId: isThermostat ? characteristicUUID(id, "target_temp") : nil,
            heatingCoolingStateId: isThermostat ? characteristicUUID(id, "hvac_action") : nil,
            targetHeatingCoolingStateId: isThermostat ? characteristicUUID(id, "hvac_mode") : nil,
            validTargetHeatingCoolingStates: validHVACStates,
            // Lock
            lockCurrentStateId: isLock ? characteristicUUID(id, "lock_state") : nil,
            lockTargetStateId: isLock ? characteristicUUID(id, "lock_target") : nil,
            // Window covering
            currentPositionId: isCover ? characteristicUUID(id, "position") : nil,
            targetPositionId: isCover ? characteristicUUID(id, "target_position") : nil,
            // Humidity sensor
            humidityId: (serviceType == ServiceTypes.humiditySensor) ? characteristicUUID(id, "humidity") : nil,
            // Valve
            activeId: isValve ? characteristicUUID(id, "active") : nil,
            // Thermostat high/low setpoints
            coolingThresholdTemperatureId: isThermostat ? characteristicUUID(id, "target_temp_high") : nil,
            heatingThresholdTemperatureId: isThermostat ? characteristicUUID(id, "target_temp_low") : nil,
            // Fan speed
            rotationSpeedId: isFan && device.hasCapability("FanControl") ? characteristicUUID(id, "speed") : nil,
            rotationSpeedMin: isFan ? 0 : nil,
            rotationSpeedMax: isFan ? 100 : nil,
            // Garage door
            currentDoorStateId: isGarageDoor ? characteristicUUID(id, "door_state") : nil,
            targetDoorStateId: isGarageDoor ? characteristicUUID(id, "target_door") : nil,
            // Valve state
            valveStateId: isValve ? characteristicUUID(id, "valve_state") : nil
        )
    }

    // MARK: - Capability to service type mapping

    private func mapCapabilitiesToServiceType(_ device: HubitatDevice) -> String? {
        // Priority order per spec
        if device.hasCapability("ColorControl") {
            return ServiceTypes.lightbulb
        }
        if device.hasCapability("ColorTemperature") {
            return ServiceTypes.lightbulb
        }
        if device.hasCapability("SwitchLevel") {
            return ServiceTypes.lightbulb
        }
        if device.hasCapability("Thermostat") || device.hasCapability("ThermostatMode") {
            return ServiceTypes.thermostat
        }
        if device.hasCapability("Lock") {
            return ServiceTypes.lock
        }
        if device.hasCapability("WindowShade") || device.hasCapability("WindowBlind") {
            return ServiceTypes.windowCovering
        }
        if device.hasCapability("GarageDoorControl") {
            return ServiceTypes.garageDoorOpener
        }
        if device.hasCapability("Valve") {
            return ServiceTypes.valve
        }
        if device.hasCapability("FanControl") || device.hasCapability("Fan") {
            return ServiceTypes.fanV2
        }
        if device.hasCapability("Switch") {
            // Check if device type name suggests outlet/plug
            if let typeName = device.type?.lowercased(),
               typeName.contains("outlet") || typeName.contains("plug") {
                return ServiceTypes.outlet
            }
            return ServiceTypes.`switch`
        }
        if device.hasCapability("TemperatureMeasurement") {
            return ServiceTypes.temperatureSensor
        }
        if device.hasCapability("RelativeHumidityMeasurement") {
            return ServiceTypes.humiditySensor
        }

        return nil
    }

    // MARK: - Value conversions

    /// Get characteristic values for a device
    func getCharacteristicValues(for deviceId: String) -> [UUID: Any] {
        lock.lock()
        guard let device = devices[deviceId] else {
            lock.unlock()
            return [:]
        }
        let attrs = mutableAttributes[deviceId] ?? device.attributes
        lock.unlock()

        guard let serviceType = mapCapabilitiesToServiceType(device) else { return [:] }

        var values: [UUID: Any] = [:]

        switch serviceType {
        case ServiceTypes.lightbulb:
            // Power
            if let switchVal = attrString(attrs, "switch") {
                values[characteristicUUID(deviceId, "power")] = switchVal == "on"
            }
            // Brightness
            if let level = attrInt(attrs, "level") {
                values[characteristicUUID(deviceId, "brightness")] = level
            }
            // Hue (Hubitat 0-100 -> Itsyhome 0-360)
            if device.hasCapability("ColorControl") {
                if let hue = attrDouble(attrs, "hue") {
                    values[characteristicUUID(deviceId, "hue")] = hue * 360.0 / 100.0
                }
                if let sat = attrInt(attrs, "saturation") {
                    values[characteristicUUID(deviceId, "saturation")] = sat
                }
            }
            // Color temperature (Kelvin -> mireds)
            if device.hasCapability("ColorTemperature") || device.hasCapability("ColorControl") {
                if let kelvin = attrDouble(attrs, "colorTemperature"), kelvin > 0 {
                    values[characteristicUUID(deviceId, "color_temp")] = Int(1_000_000 / kelvin)
                }
            }

        case ServiceTypes.`switch`, ServiceTypes.outlet:
            if let switchVal = attrString(attrs, "switch") {
                values[characteristicUUID(deviceId, "power")] = switchVal == "on"
            }

        case ServiceTypes.lock:
            let lockVal = attrString(attrs, "lock") ?? ""
            let lockState: Int
            switch lockVal {
            case "locked": lockState = 1
            case "unlocked": lockState = 0
            default: lockState = 3
            }
            values[characteristicUUID(deviceId, "lock_state")] = lockState
            values[characteristicUUID(deviceId, "lock_target")] = lockState

        case ServiceTypes.thermostat:
            // Current temperature
            if let temp = attrDouble(attrs, "temperature") {
                values[characteristicUUID(deviceId, "current_temp")] = normalizeTemperature(temp)
            }
            // Target temperature (prefer thermostatSetpoint, fallback to heatingSetpoint)
            if let setpoint = attrDouble(attrs, "thermostatSetpoint") {
                values[characteristicUUID(deviceId, "target_temp")] = normalizeTemperature(setpoint)
            } else if let heatSetpoint = attrDouble(attrs, "heatingSetpoint") {
                values[characteristicUUID(deviceId, "target_temp")] = normalizeTemperature(heatSetpoint)
            }
            // High/low setpoints
            if let coolSetpoint = attrDouble(attrs, "coolingSetpoint") {
                values[characteristicUUID(deviceId, "target_temp_high")] = normalizeTemperature(coolSetpoint)
            }
            if let heatSetpoint = attrDouble(attrs, "heatingSetpoint") {
                values[characteristicUUID(deviceId, "target_temp_low")] = normalizeTemperature(heatSetpoint)
            }
            // HVAC mode
            if let mode = attrString(attrs, "thermostatMode") {
                values[characteristicUUID(deviceId, "hvac_mode")] = mapThermostatMode(mode)
            }
            // HVAC action (operating state)
            if let opState = attrString(attrs, "thermostatOperatingState") {
                values[characteristicUUID(deviceId, "hvac_action")] = mapThermostatOperatingState(opState)
            }

        case ServiceTypes.windowCovering:
            if let position = attrInt(attrs, "position") {
                values[characteristicUUID(deviceId, "position")] = position
                values[characteristicUUID(deviceId, "target_position")] = position
            }

        case ServiceTypes.garageDoorOpener:
            let doorVal = attrString(attrs, "door") ?? ""
            values[characteristicUUID(deviceId, "door_state")] = mapDoorState(doorVal)
            values[characteristicUUID(deviceId, "target_door")] = (doorVal == "open") ? 0 : 1

        case ServiceTypes.valve:
            let valveVal = attrString(attrs, "valve") ?? ""
            let isOpen = valveVal == "open"
            values[characteristicUUID(deviceId, "active")] = isOpen ? 1 : 0
            values[characteristicUUID(deviceId, "valve_state")] = isOpen ? 1 : 0

        case ServiceTypes.fanV2:
            if let switchVal = attrString(attrs, "switch") {
                values[characteristicUUID(deviceId, "power")] = switchVal == "on"
            }
            if device.hasCapability("FanControl") {
                // FanControl reports "speed" as a string name; convert to percentage
                if let speedName = attrString(attrs, "speed") {
                    let speedPercent: Int
                    switch speedName.lowercased() {
                    case "off": speedPercent = 0
                    case "low": speedPercent = 20
                    case "medium-low": speedPercent = 40
                    case "medium": speedPercent = 60
                    case "medium-high": speedPercent = 80
                    case "high": speedPercent = 100
                    case "on", "auto": speedPercent = 50
                    default: speedPercent = 0
                    }
                    values[characteristicUUID(deviceId, "speed")] = speedPercent
                } else if let level = attrInt(attrs, "level") {
                    // Fallback to SwitchLevel if no speed string
                    values[characteristicUUID(deviceId, "speed")] = level
                }
            }

        case ServiceTypes.temperatureSensor:
            if let temp = attrDouble(attrs, "temperature") {
                values[characteristicUUID(deviceId, "current_temp")] = normalizeTemperature(temp)
            }

        case ServiceTypes.humiditySensor:
            if let humidity = attrInt(attrs, "humidity") {
                values[characteristicUUID(deviceId, "humidity")] = humidity
            }

        default:
            break
        }

        return values
    }

    // MARK: - Hubitat value mappings

    private func mapThermostatMode(_ mode: String) -> Int {
        switch mode {
        case "off": return 0
        case "heat": return 1
        case "cool": return 2
        case "auto", "emergency heat": return 3
        default:
            logger.warning("Unknown thermostat mode '\(mode)', mapping to off")
            return 0
        }
    }

    private func mapThermostatOperatingState(_ state: String) -> Int {
        switch state {
        case "idle": return 0
        case "heating": return 1
        case "cooling": return 2
        default: return 0
        }
    }

    private func mapDoorState(_ state: String) -> Int {
        switch state {
        case "open": return 0
        case "closed": return 1
        case "opening": return 2
        case "closing": return 3
        default: return 4
        }
    }

    // MARK: - Attribute helpers

    private func attrString(_ attrs: [String: Any], _ name: String) -> String? {
        guard let value = attrs[name] else { return nil }
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return String(describing: value)
    }

    private func attrDouble(_ attrs: [String: Any], _ name: String) -> Double? {
        guard let value = attrs[name] else { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private func attrInt(_ attrs: [String: Any], _ name: String) -> Int? {
        guard let value = attrs[name] else { return nil }
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    // MARK: - Characteristic lookups

    /// Get device ID from characteristic UUID - O(1) via cache
    func getDeviceIdFromCharacteristic(_ uuid: UUID) -> String? {
        lock.lock()
        let result = characteristicToDevice[uuid]
        lock.unlock()
        return result
    }

    /// Get device ID from service UUID - O(1) via cache
    func getDeviceId(for serviceUUID: UUID) -> String? {
        lock.lock()
        let result = serviceToDevice[serviceUUID]
        lock.unlock()
        return result
    }

    /// Get the current thermostat mode string for a device (e.g., "heat", "cool", "auto")
    func getCurrentThermostatMode(for deviceId: String) -> String {
        lock.lock()
        let attrs = mutableAttributes[deviceId] ?? devices[deviceId]?.attributes ?? [:]
        lock.unlock()
        return (attrs["thermostatMode"] as? String) ?? "heat"
    }

    /// Get the characteristic type name for a UUID
    func getCharacteristicType(for uuid: UUID, deviceId: String) -> String {
        for charType in Self.characteristicTypes {
            if characteristicUUID(deviceId, charType) == uuid {
                return charType
            }
        }
        return "unknown"
    }

    /// Generate deterministic UUID for a characteristic
    func characteristicUUID(_ deviceId: String, _ characteristicName: String) -> UUID {
        deterministicUUID(for: "hubitat_device_\(deviceId).\(characteristicName)")
    }

    // MARK: - UUID generation

    /// Generate deterministic UUID from string using SHA-256
    private func deterministicUUID(for string: String) -> UUID {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }

        // Set version 4 and variant bits
        hash[6] = (hash[6] & 0x0F) | 0x40
        hash[8] = (hash[8] & 0x3F) | 0x80

        let uuid = NSUUID(uuidBytes: hash) as UUID
        return uuid
    }
}
