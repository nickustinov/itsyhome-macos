//
//  EntityMapper.swift
//  Itsyhome
//
//  Maps Home Assistant entities to Itsyhome ServiceData model
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "EntityMapper")

final class EntityMapper {

    // MARK: - Properties

    private var entityStates: [String: HAEntityState] = [:]
    private var entityRegistry: [String: HAEntityRegistryEntry] = [:]
    private var devices: [String: HADevice] = [:]
    private var areas: [String: HAArea] = [:]

    // Reverse lookup caches for O(1) characteristic lookups
    private var characteristicToEntity: [UUID: String] = [:]
    private var serviceToEntity: [UUID: String] = [:]

    // MARK: - Data loading

    func loadData(states: [HAEntityState],
                  entities: [HAEntityRegistryEntry],
                  devices: [HADevice],
                  areas: [HAArea]) {
        self.entityStates = Dictionary(uniqueKeysWithValues: states.map { ($0.entityId, $0) })
        self.entityRegistry = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityId, $0) })
        self.devices = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        self.areas = Dictionary(uniqueKeysWithValues: areas.map { ($0.areaId, $0) })

        // Build reverse lookup caches
        buildCharacteristicCache()

        logger.info("Loaded \(states.count) states, \(entities.count) entities, \(devices.count) devices, \(areas.count) areas")
    }

    func updateState(_ state: HAEntityState) {
        entityStates[state.entityId] = state
    }

    /// Build reverse lookup caches for fast UUID → entityId lookups
    private func buildCharacteristicCache() {
        characteristicToEntity.removeAll()
        serviceToEntity.removeAll()

        let characteristicTypes = [
            "power", "brightness", "hue", "saturation", "color_temp",
            "current_temp", "target_temp", "hvac_action", "hvac_mode",
            "lock_state", "lock_target", "position", "target_position",
            "tilt", "target_tilt", "door_state", "target_door",
            "speed", "oscillating", "direction", "alarm_state", "alarm_target",
            "target_temp_high", "target_temp_low", "humidity", "target_humidity",
            "hum_action", "hum_mode", "active", "swing_mode"
        ]

        for entityId in entityStates.keys {
            // Cache service UUID
            serviceToEntity[deterministicUUID(for: entityId)] = entityId

            // Cache all characteristic UUIDs
            for charType in characteristicTypes {
                characteristicToEntity[characteristicUUID(entityId, charType)] = entityId
            }
        }

        logger.debug("Built characteristic cache: \(self.characteristicToEntity.count) characteristics, \(self.serviceToEntity.count) services")
    }

    // MARK: - Menu data generation

    func generateMenuData() -> MenuData {
        let roomData = generateRooms()
        let accessoryData = generateAccessories()
        let sceneData = generateScenes()
        let cameraData = generateCameras()

        logger.info("Generated menu data: \(roomData.count) rooms, \(accessoryData.count) accessories, \(sceneData.count) scenes, \(cameraData.count) cameras")
        for room in roomData {
            logger.info("  Room: \(room.name) (\(room.uniqueIdentifier))")
        }

        return MenuData(
            homes: [],  // HA doesn't have multiple homes
            rooms: roomData,
            accessories: accessoryData,
            scenes: sceneData,
            selectedHomeId: nil,
            hasCameras: !cameraData.isEmpty,
            cameras: cameraData
        )
    }

    // MARK: - Room generation

    private func generateRooms() -> [RoomData] {
        logger.info("Areas available: \(self.areas.keys.sorted())")
        return areas.values
            .sorted { $0.name < $1.name }
            .map { area in
                let roomUUID = deterministicUUID(for: area.areaId)
                logger.info("Room '\(area.name)' areaId='\(area.areaId)' -> UUID=\(roomUUID)")
                return RoomData(
                    uniqueIdentifier: roomUUID,
                    name: area.name
                )
            }
    }

    // MARK: - Accessory generation

    private func generateAccessories() -> [AccessoryData] {
        // Group entities by device
        var deviceEntities: [String?: [HAEntityState]] = [:]

        // Log domain counts
        var domainCounts: [String: Int] = [:]
        for (_, state) in entityStates {
            domainCounts[state.domain, default: 0] += 1
        }
        logger.info("Entity domains: \(domainCounts)")

        for (entityId, state) in entityStates {
            // Skip unsupported domains
            guard isSupportedDomain(state.domain) else { continue }

            // Skip hidden/disabled entities
            if let registry = entityRegistry[entityId], (registry.disabled || registry.hidden) {
                logger.debug("Skipping hidden/disabled: \(entityId)")
                continue
            }

            let deviceId = entityRegistry[entityId]?.deviceId
            if let deviceId = deviceId {
                // Group entities by device
                deviceEntities[deviceId, default: []].append(state)
            } else {
                // Entities without device ID become their own accessory (use entityId as key)
                deviceEntities[entityId, default: []].append(state)
            }
        }

        logger.info("Grouped into \(deviceEntities.count) device groups")

        // Convert to accessories
        var accessories: [AccessoryData] = []
        var roomAssignments: [String: Int] = [:]

        for (deviceId, states) in deviceEntities {
            let services = states.compactMap { mapEntityToService($0) }
            guard !services.isEmpty else {
                logger.debug("No services for device \(deviceId ?? "nil") with \(states.count) states")
                continue
            }

            let device = deviceId.flatMap { devices[$0] }
            let areaId = resolveAreaId(for: states.first!, deviceId: deviceId)
            let roomUUID = areaId.flatMap { deterministicUUID(for: $0) }

            let accessoryId = deviceId.flatMap { deterministicUUID(for: $0) }
                ?? deterministicUUID(for: states.first!.entityId)

            let accessoryName = device?.name ?? states.first?.friendlyName ?? "Unknown"

            // Track room assignments
            roomAssignments[areaId ?? "nil", default: 0] += 1

            accessories.append(AccessoryData(
                uniqueIdentifier: accessoryId,
                name: accessoryName,
                roomIdentifier: roomUUID,
                services: services,
                isReachable: states.first?.state != "unavailable"
            ))
        }

        logger.info("Room assignments: \(roomAssignments)")
        return accessories.sorted { $0.name < $1.name }
    }

    // MARK: - Scene generation

    private func generateScenes() -> [SceneData] {
        return entityStates.values
            .filter { $0.domain == "scene" }
            .map { state in
                SceneData(
                    uniqueIdentifier: deterministicUUID(for: state.entityId),
                    name: state.friendlyName,
                    actions: []  // HA doesn't expose scene target values
                )
            }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Camera generation

    private func generateCameras() -> [CameraData] {
        return entityStates.values
            .filter { $0.domain == "camera" }
            .map { state in
                CameraData(
                    uniqueIdentifier: deterministicUUID(for: state.entityId),
                    name: state.friendlyName
                )
            }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Entity to service mapping

    private func mapEntityToService(_ state: HAEntityState) -> ServiceData? {
        let serviceType = mapDomainToServiceType(state.domain, deviceClass: state.deviceClass)
        guard let serviceType = serviceType else { return nil }

        // Debug logging for light capabilities
        if state.domain == "light" {
            logger.info("Light '\(state.friendlyName)' (\(state.entityId)): supported_color_modes=\(state.supportedColorModes), supportsColor=\(state.supportsColor), supportsBrightness=\(state.supportsBrightness), supportsColorTemp=\(state.supportsColorTemp)")
        }

        // Debug logging for fan capabilities
        if state.domain == "fan" {
            logger.info("Fan '\(state.friendlyName)' (\(state.entityId)): supportsPercentage=\(state.supportsPercentage), percentage=\(String(describing: state.percentage)), oscillating=\(state.isOscillating), direction=\(String(describing: state.direction))")
        }

        let areaId = resolveAreaId(for: state, deviceId: entityRegistry[state.entityId]?.deviceId)
        let roomUUID = areaId.flatMap { deterministicUUID(for: $0) }

        // Generate deterministic UUIDs for characteristic IDs
        let entityUUID = deterministicUUID(for: state.entityId)

        return ServiceData(
            uniqueIdentifier: entityUUID,
            name: state.friendlyName,
            serviceType: serviceType,
            accessoryName: state.friendlyName,
            roomIdentifier: roomUUID,
            isReachable: state.state != "unavailable",
            // Light characteristics - use supported_color_modes for capability detection
            powerStateId: hasPowerState(state) ? characteristicUUID(state.entityId, "power") : nil,
            brightnessId: state.supportsBrightness ? characteristicUUID(state.entityId, "brightness") : nil,
            hueId: state.supportsColor ? characteristicUUID(state.entityId, "hue") : nil,
            saturationId: state.supportsColor ? characteristicUUID(state.entityId, "saturation") : nil,
            colorTemperatureId: state.supportsColorTemp ? characteristicUUID(state.entityId, "color_temp") : nil,
            colorTemperatureMin: state.minColorTempKelvin.flatMap { Double(1_000_000 / $0) },
            colorTemperatureMax: state.maxColorTempKelvin.flatMap { Double(1_000_000 / $0) },
            needsColorModeSwitch: state.needsColorModeSwitch ? true : nil,
            // Climate characteristics
            currentTemperatureId: state.currentTemperature != nil ? characteristicUUID(state.entityId, "current_temp") : nil,
            targetTemperatureId: state.targetTemperature != nil ? characteristicUUID(state.entityId, "target_temp") : nil,
            heatingCoolingStateId: state.hvacAction != nil ? characteristicUUID(state.entityId, "hvac_action") : nil,
            targetHeatingCoolingStateId: state.domain == "climate" ? characteristicUUID(state.entityId, "hvac_mode") : nil,
            availableHVACModes: state.domain == "climate" ? state.hvacModes : nil,
            // Lock characteristics
            lockCurrentStateId: state.domain == "lock" ? characteristicUUID(state.entityId, "lock_state") : nil,
            lockTargetStateId: state.domain == "lock" ? characteristicUUID(state.entityId, "lock_target") : nil,
            // Cover characteristics
            // SET_POSITION is bit 4, SET_TILT_POSITION is bit 128
            // Always create position ID for covers (needed for slider UI)
            currentPositionId: state.domain == "cover" ? characteristicUUID(state.entityId, "position") : nil,
            // Show slider for covers with SET_POSITION or SET_TILT_POSITION (tilt-only shows slider that controls tilt)
            targetPositionId: state.domain == "cover" && ((state.supportedFeatures & 4) != 0 || (state.supportedFeatures & 128) != 0) ? characteristicUUID(state.entityId, "target_position") : nil,
            // Tilt slider only for covers that have BOTH position AND tilt (not tilt-only)
            currentHorizontalTiltId: state.currentTiltPosition != nil && !isTiltOnlyCover(state) ? characteristicUUID(state.entityId, "tilt") : nil,
            targetHorizontalTiltId: state.currentTiltPosition != nil && !isTiltOnlyCover(state) ? characteristicUUID(state.entityId, "target_tilt") : nil,
            // Sensor characteristics (humidity also for climate entities)
            humidityId: state.deviceClass == "humidity" || (state.domain == "climate" && state.currentHumidity != nil) ? characteristicUUID(state.entityId, "humidity") : nil,
            // HeaterCooler characteristics
            activeId: state.domain == "valve" || state.domain == "climate" ? characteristicUUID(state.entityId, "active") : nil,
            coolingThresholdTemperatureId: state.targetTempHigh != nil ? characteristicUUID(state.entityId, "target_temp_high") : nil,
            heatingThresholdTemperatureId: state.targetTempLow != nil ? characteristicUUID(state.entityId, "target_temp_low") : nil,
            // Fan characteristics - only provide speed if fan supports percentage (SET_PERCENTAGE feature)
            rotationSpeedId: state.domain == "fan" && state.supportsPercentage ? characteristicUUID(state.entityId, "speed") : nil,
            rotationSpeedMin: 0,
            rotationSpeedMax: 100,
            rotationDirectionId: state.direction != nil ? characteristicUUID(state.entityId, "direction") : nil,
            swingModeId: state.swingMode != nil ? characteristicUUID(state.entityId, "swing_mode") :
                         state.isOscillating ? characteristicUUID(state.entityId, "oscillating") : nil,
            // Garage door characteristics
            currentDoorStateId: state.deviceClass == "garage" ? characteristicUUID(state.entityId, "door_state") : nil,
            targetDoorStateId: state.deviceClass == "garage" ? characteristicUUID(state.entityId, "target_door") : nil,
            // Humidifier characteristics
            currentHumidifierDehumidifierStateId: state.humidifierAction != nil ? characteristicUUID(state.entityId, "hum_action") : nil,
            targetHumidifierDehumidifierStateId: state.domain == "humidifier" ? characteristicUUID(state.entityId, "hum_mode") : nil,
            humidifierThresholdId: state.targetHumidity != nil ? characteristicUUID(state.entityId, "target_humidity") : nil,
            // Valve characteristics
            inUseId: nil,  // HA doesn't have InUse
            // Security system characteristics
            securitySystemCurrentStateId: state.domain == "alarm_control_panel" ? characteristicUUID(state.entityId, "alarm_state") : nil,
            securitySystemTargetStateId: state.domain == "alarm_control_panel" ? characteristicUUID(state.entityId, "alarm_target") : nil,
            alarmSupportedModes: state.domain == "alarm_control_panel" ? state.alarmSupportedModes : nil,
            alarmRequiresCode: state.domain == "alarm_control_panel" ? state.codeArmRequired : nil
        )
    }

    // MARK: - Helpers

    private func isSupportedDomain(_ domain: String) -> Bool {
        let supported: Set<String> = [
            "light", "switch", "climate", "cover", "lock", "fan",
            "humidifier", "valve", "sensor", "binary_sensor", "alarm_control_panel"
        ]
        return supported.contains(domain)
    }

    private func hasPowerState(_ state: HAEntityState) -> Bool {
        let domainsWithPower: Set<String> = ["light", "switch", "fan", "humidifier"]
        return domainsWithPower.contains(state.domain)
    }

    /// Check if cover only supports tilt (no position control)
    private func isTiltOnlyCover(_ state: HAEntityState) -> Bool {
        guard state.domain == "cover" else { return false }
        let hasSetPosition = (state.supportedFeatures & 4) != 0
        let hasSetTiltPosition = (state.supportedFeatures & 128) != 0
        return !hasSetPosition && hasSetTiltPosition
    }

    private func mapDomainToServiceType(_ domain: String, deviceClass: String?) -> String? {
        switch domain {
        case "light":
            return ServiceTypes.lightbulb
        case "switch":
            if deviceClass == "outlet" {
                return ServiceTypes.outlet
            }
            return ServiceTypes.switch
        case "climate":
            // Check for heater/cooler vs thermostat based on features
            return ServiceTypes.thermostat
        case "cover":
            switch deviceClass {
            case "garage":
                return ServiceTypes.garageDoorOpener
            case "door":
                return ServiceTypes.door
            case "window":
                return ServiceTypes.window
            default:
                return ServiceTypes.windowCovering
            }
        case "lock":
            return ServiceTypes.lock
        case "fan":
            return ServiceTypes.fanV2
        case "humidifier":
            return ServiceTypes.humidifierDehumidifier
        case "valve":
            return ServiceTypes.valve
        case "sensor":
            switch deviceClass {
            case "temperature":
                return ServiceTypes.temperatureSensor
            case "humidity":
                return ServiceTypes.humiditySensor
            default:
                return nil
            }
        case "binary_sensor":
            // We don't show binary sensors as menu items typically
            return nil
        case "alarm_control_panel":
            return ServiceTypes.securitySystem
        default:
            return nil
        }
    }

    private func resolveAreaId(for state: HAEntityState, deviceId: String?) -> String? {
        // First check entity's direct area
        if let entityArea = entityRegistry[state.entityId]?.areaId {
            logger.debug("\(state.entityId): area from entity registry: \(entityArea)")
            return entityArea
        }

        // Then check device's area
        if let deviceId = deviceId, let device = devices[deviceId] {
            if let deviceArea = device.areaId {
                logger.debug("\(state.entityId): area from device '\(device.name ?? "unnamed")': \(deviceArea)")
                return deviceArea
            } else {
                logger.debug("\(state.entityId): device '\(device.name ?? "unnamed")' has no area")
            }
        } else if let deviceId = deviceId {
            logger.debug("\(state.entityId): device \(deviceId) not found in registry")
        } else {
            logger.debug("\(state.entityId): no device ID in entity registry")
        }

        return nil
    }

    /// Generate deterministic UUID from string (for stable IDs across sessions)
    private func deterministicUUID(for string: String) -> UUID {
        let data = string.data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: 16)

        data.withUnsafeBytes { bytes in
            for (index, byte) in bytes.enumerated() {
                hash[index % 16] ^= byte
            }
        }

        // Set version (4) and variant bits
        hash[6] = (hash[6] & 0x0F) | 0x40
        hash[8] = (hash[8] & 0x3F) | 0x80

        return UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))
    }

    /// Generate deterministic UUID for a characteristic
    func characteristicUUID(_ entityId: String, _ characteristicName: String) -> UUID {
        return deterministicUUID(for: "\(entityId).\(characteristicName)")
    }

    // MARK: - Value conversions

    /// Convert HA entity state to characteristic values
    func getCharacteristicValues(for entityId: String) -> [UUID: Any] {
        guard let state = entityStates[entityId] else { return [:] }

        var values: [UUID: Any] = [:]

        // Power state
        if hasPowerState(state) {
            values[characteristicUUID(entityId, "power")] = state.state == "on"
        }

        // Light values
        if let brightness = state.brightnessPercent {
            values[characteristicUUID(entityId, "brightness")] = brightness
        }
        if let hs = state.hsColor {
            values[characteristicUUID(entityId, "hue")] = hs.hue
            values[characteristicUUID(entityId, "saturation")] = hs.saturation
        }
        if let mireds = state.colorTempMireds {
            values[characteristicUUID(entityId, "color_temp")] = mireds
        }

        // Climate values
        if let currentTemp = state.currentTemperature {
            values[characteristicUUID(entityId, "current_temp")] = currentTemp
        }
        if let targetTemp = state.targetTemperature {
            values[characteristicUUID(entityId, "target_temp")] = targetTemp
        }
        if let targetTempHigh = state.targetTempHigh {
            values[characteristicUUID(entityId, "target_temp_high")] = targetTempHigh
        }
        if let targetTempLow = state.targetTempLow {
            values[characteristicUUID(entityId, "target_temp_low")] = targetTempLow
        }
        // Climate-specific values
        if state.domain == "climate" {
            if let hvacAction = state.hvacAction {
                values[characteristicUUID(entityId, "hvac_action")] = mapHVACActionToHomeKit(hvacAction)
            }
            values[characteristicUUID(entityId, "hvac_mode")] = mapHVACModeToHomeKit(state.hvacMode)
            if let swingMode = state.swingMode {
                values[characteristicUUID(entityId, "swing_mode")] = swingMode == "off" ? 0 : 1
            }
        }
        // Humidity for climate entities
        if let humidity = state.currentHumidity {
            values[characteristicUUID(entityId, "humidity")] = humidity
        }

        // Lock values
        if state.domain == "lock" {
            values[characteristicUUID(entityId, "lock_state")] = mapLockStateToHomeKit(state.state)
            values[characteristicUUID(entityId, "lock_target")] = state.isLocked ? 1 : 0
        }

        // Cover values
        if let position = state.currentPosition {
            values[characteristicUUID(entityId, "position")] = position
            values[characteristicUUID(entityId, "target_position")] = position
        } else if state.domain == "cover" {
            // Check if this is a tilt-only cover (has SET_TILT_POSITION but no SET_POSITION)
            let isTiltOnly = (state.supportedFeatures & 128) != 0 && (state.supportedFeatures & 4) == 0
            if isTiltOnly, let tilt = state.currentTiltPosition {
                // Use tilt position as the "position" for tilt-only covers
                values[characteristicUUID(entityId, "position")] = tilt
            } else {
                // For covers without position support, derive from state
                // open/opening = 100, closed/closing = 0
                let derivedPosition = (state.state == "open" || state.state == "opening") ? 100 : 0
                values[characteristicUUID(entityId, "position")] = derivedPosition
            }
        }
        if let tilt = state.currentTiltPosition {
            // Use 0-100 directly for HA tilt (not angle conversion)
            values[characteristicUUID(entityId, "tilt")] = tilt
            values[characteristicUUID(entityId, "target_tilt")] = tilt
        }

        // Garage door values
        if state.deviceClass == "garage" {
            values[characteristicUUID(entityId, "door_state")] = mapDoorStateToHomeKit(state.state)
            values[characteristicUUID(entityId, "target_door")] = state.isClosed ? 1 : 0
        }

        // Fan values
        if let percentage = state.percentage {
            values[characteristicUUID(entityId, "speed")] = percentage
        }
        values[characteristicUUID(entityId, "oscillating")] = state.isOscillating ? 1 : 0
        if let direction = state.direction {
            values[characteristicUUID(entityId, "direction")] = direction == "forward" ? 0 : 1
        }

        // Security system values
        if state.domain == "alarm_control_panel" {
            values[characteristicUUID(entityId, "alarm_state")] = mapAlarmStateToHomeKit(state.state)
            values[characteristicUUID(entityId, "alarm_target")] = mapAlarmTargetToHomeKit(state.state)
        }

        return values
    }

    // MARK: - HomeKit value mappings

    private func mapHVACActionToHomeKit(_ action: String) -> Int {
        switch action {
        case "heating": return 1
        case "cooling": return 2
        case "idle", "off": return 0
        default: return 0
        }
    }

    private func mapHVACModeToHomeKit(_ mode: String) -> Int {
        // Extended mapping to support HA-specific modes
        // Standard HomeKit: 0=off, 1=heat, 2=cool, 3=heat_cool
        // Extended for HA: 4=dry, 5=fan_only, 6=auto (AI/schedule)
        switch mode {
        case "off": return 0
        case "heat": return 1
        case "cool": return 2
        case "heat_cool": return 3
        case "dry": return 4
        case "fan_only": return 5
        case "auto": return 6
        default:
            logger.warning("Unknown HVAC mode '\(mode)', mapping to off")
            return 0
        }
    }

    private func mapLockStateToHomeKit(_ state: String) -> Int {
        switch state {
        case "locked": return 1
        case "unlocked": return 0
        case "jammed": return 2
        default: return 3  // Unknown
        }
    }

    private func mapDoorStateToHomeKit(_ state: String) -> Int {
        switch state {
        case "open": return 0
        case "closed": return 1
        case "opening": return 2
        case "closing": return 3
        default: return 4  // Stopped
        }
    }

    private func mapAlarmStateToHomeKit(_ state: String) -> Int {
        switch state {
        case "armed_home": return 0
        case "armed_away": return 1
        case "armed_night": return 2
        case "disarmed": return 3
        case "triggered": return 4
        default: return 3
        }
    }

    private func mapAlarmTargetToHomeKit(_ state: String) -> Int {
        switch state {
        case "armed_home": return 0
        case "armed_away", "armed_vacation": return 1
        case "armed_night": return 2
        case "disarmed", "arming", "pending": return 3
        default: return 3
        }
    }

    // MARK: - Entity attribute helpers

    /// Get available HVAC modes for a climate entity
    func getAvailableHVACModes(for entityId: String) -> [String] {
        guard let state = entityStates[entityId] else { return [] }
        return state.hvacModes
    }

    /// Check if alarm panel requires a code
    func alarmRequiresCode(for entityId: String) -> Bool {
        guard let state = entityStates[entityId] else { return true }
        return state.codeArmRequired
    }

    /// Get supported features for a cover entity
    func getCoverSupportedFeatures(for entityId: String) -> Int {
        guard let state = entityStates[entityId] else { return 0 }
        return state.supportedFeatures
    }

    /// Get the characteristic type name for a UUID
    func getCharacteristicType(for uuid: UUID, entityId: String) -> String {
        let possibleTypes = [
            "power", "brightness", "hue", "saturation", "color_temp",
            "current_temp", "target_temp", "hvac_action", "hvac_mode",
            "lock_state", "lock_target", "position", "target_position",
            "tilt", "target_tilt", "door_state", "target_door",
            "speed", "oscillating", "direction", "alarm_state", "alarm_target",
            "target_temp_high", "target_temp_low", "humidity", "target_humidity",
            "hum_action", "hum_mode", "active", "swing_mode"
        ]

        for charType in possibleTypes {
            if characteristicUUID(entityId, charType) == uuid {
                return charType
            }
        }
        return "unknown"
    }

    // MARK: - Entity ID lookup

    /// Get entity ID from service UUID - O(1) via cache
    func getEntityId(for serviceUUID: UUID) -> String? {
        return serviceToEntity[serviceUUID]
    }

    /// Get entity ID from characteristic UUID - O(1) via cache
    func getEntityIdFromCharacteristic(_ characteristicUUID: UUID) -> String? {
        return characteristicToEntity[characteristicUUID]
    }
}
