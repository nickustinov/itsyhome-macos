//
//  HomeAssistantPlatform.swift
//  Itsyhome
//
//  SmartHomePlatform implementation for Home Assistant
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeAssistantPlatform")

final class HomeAssistantPlatform: SmartHomePlatform {

    // MARK: - SmartHomePlatform properties

    let platformType: SmartHomePlatformType = .homeAssistant
    let capabilities: PlatformCapabilities = .homeAssistant

    weak var delegate: SmartHomePlatformDelegate?

    var isConnected: Bool {
        client?.isConnected ?? false
    }

    // MARK: - Home support (not applicable for HA)

    var availableHomes: [HomeData] { [] }
    var selectedHomeIdentifier: UUID? {
        get { nil }
        set { }
    }

    // MARK: - Camera support

    var hasCameras: Bool {
        !mapper.generateMenuData().cameras.isEmpty
    }

    // MARK: - Private properties

    private var client: HomeAssistantClient?
    private let mapper = EntityMapper()
    private var stateSubscriptionId: Int?

    private var cachedMenuDataJSON: String?

    // MARK: - Initialization

    init() {
        logger.info("HomeAssistantPlatform initialized")
    }

    // MARK: - Connection

    func connect() async throws {
        guard let serverURL = HAAuthManager.shared.serverURL,
              let accessToken = HAAuthManager.shared.accessToken else {
            throw HAAuthError.notConfigured
        }

        logger.info("Connecting to Home Assistant...")

        client = HomeAssistantClient(serverURL: serverURL, accessToken: accessToken)
        client?.delegate = self

        try await client?.connect()

        // Load initial data
        await loadAllData()

        // Subscribe to state changes
        do {
            stateSubscriptionId = try await client?.subscribeToStateChanges()
            logger.info("Subscribed to state changes")
        } catch {
            logger.error("Failed to subscribe to state changes: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        logger.info("Disconnecting from Home Assistant")
        client?.disconnect()
        client = nil
        stateSubscriptionId = nil
    }

    // MARK: - Data loading

    private func loadAllData() async {
        guard let client = client else { return }

        do {
            async let states = client.getStates()
            async let entities = client.getEntities()
            async let devices = client.getDevices()
            async let areas = client.getAreas()

            let (statesResult, entitiesResult, devicesResult, areasResult) = try await (states, entities, devices, areas)

            mapper.loadData(
                states: statesResult,
                entities: entitiesResult,
                devices: devicesResult,
                areas: areasResult
            )

            // Generate and cache menu data
            let menuData = mapper.generateMenuData()
            if let jsonData = try? JSONEncoder().encode(menuData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                cachedMenuDataJSON = jsonString
                delegate?.platformDidUpdateMenuData(self, jsonString: jsonString)
            }

            logger.info("Loaded all Home Assistant data")
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription)")
            delegate?.platformDidEncounterError(self, message: error.localizedDescription)
        }
    }

    func reloadData() {
        Task {
            await loadAllData()
        }
    }

    func getMenuDataJSON() -> String? {
        return cachedMenuDataJSON
    }

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
            logger.debug("Read requested for characteristic of entity: \(entityId)")
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
            if let isActive = value as? Bool {
                try await client.callService(
                    domain: "valve",
                    service: isActive ? "open_valve" : "close_valve",
                    target: ["entity_id": entityId]
                )
            }

        case "alarm_control_panel":
            try await writeAlarmValue(client: client, entityId: entityId, value: value)

        default:
            logger.warning("Unsupported domain for write: \(domain)")
        }
    }

    private func writeLightValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        // Determine what type of value we're writing based on the characteristic
        let charIdString = characteristicUUID.uuidString.lowercased()

        if let isOn = value as? Bool {
            try await client.callService(
                domain: "light",
                service: isOn ? "turn_on" : "turn_off",
                target: ["entity_id": entityId]
            )
        } else if let brightness = value as? Int {
            // Convert from 0-100 to 0-255
            let haBrightness = Int(Double(brightness) * 2.55)
            try await client.callService(
                domain: "light",
                service: "turn_on",
                serviceData: ["brightness": haBrightness],
                target: ["entity_id": entityId]
            )
        } else if let mireds = value as? Int {
            // Convert mireds to kelvin
            let kelvin = 1_000_000 / mireds
            try await client.callService(
                domain: "light",
                service: "turn_on",
                serviceData: ["color_temp_kelvin": kelvin],
                target: ["entity_id": entityId]
            )
        }
    }

    private func writeClimateValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        // Determine which characteristic is being written based on UUID
        let characteristicType = mapper.getCharacteristicType(for: characteristicUUID, entityId: entityId)

        switch characteristicType {
        case "hvac_mode":
            guard let mode = value as? Int else { return }
            // Get available HVAC modes for this entity
            let availableModes = mapper.getAvailableHVACModes(for: entityId)

            // HomeKit mode: 0=off, 1=heat, 2=cool, 3=auto
            // Map to best available HA mode
            let hvacMode: String
            switch mode {
            case 0:
                hvacMode = "off"
            case 1:
                // Heat mode - fallback to heat_cool or auto if heat not available
                if availableModes.contains("heat") {
                    hvacMode = "heat"
                } else if availableModes.contains("heat_cool") {
                    hvacMode = "heat_cool"
                } else if availableModes.contains("auto") {
                    hvacMode = "auto"
                } else {
                    logger.warning("No heating mode available for \(entityId)")
                    return
                }
            case 2:
                // Cool mode - fallback to heat_cool or auto if cool not available
                if availableModes.contains("cool") {
                    hvacMode = "cool"
                } else if availableModes.contains("heat_cool") {
                    hvacMode = "heat_cool"
                } else if availableModes.contains("auto") {
                    hvacMode = "auto"
                } else {
                    logger.warning("No cooling mode available for \(entityId)")
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

            logger.info("Setting HVAC mode to '\(hvacMode)' (requested: \(mode), available: \(availableModes))")

            try await client.callService(
                domain: "climate",
                service: "set_hvac_mode",
                serviceData: ["hvac_mode": hvacMode],
                target: ["entity_id": entityId]
            )

        case "target_temp", "target_temp_high", "target_temp_low":
            // Temperature change - accept Int or Double
            let temp: Double
            if let d = value as? Double {
                temp = d
            } else if let i = value as? Int {
                temp = Double(i)
            } else {
                return
            }

            if characteristicType == "target_temp_high" {
                try await client.callService(
                    domain: "climate",
                    service: "set_temperature",
                    serviceData: ["target_temp_high": temp],
                    target: ["entity_id": entityId]
                )
            } else if characteristicType == "target_temp_low" {
                try await client.callService(
                    domain: "climate",
                    service: "set_temperature",
                    serviceData: ["target_temp_low": temp],
                    target: ["entity_id": entityId]
                )
            } else {
                try await client.callService(
                    domain: "climate",
                    service: "set_temperature",
                    serviceData: ["temperature": temp],
                    target: ["entity_id": entityId]
                )
            }

        default:
            logger.warning("Unknown climate characteristic type: \(characteristicType)")
        }
    }

    private func writeCoverValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        let features = mapper.getCoverSupportedFeatures(for: entityId)

        if let position = value as? Int {
            // Check if cover supports position setting (feature bit 4)
            if features & 4 != 0 {
                try await client.callService(
                    domain: "cover",
                    service: "set_cover_position",
                    serviceData: ["position": position],
                    target: ["entity_id": entityId]
                )
            } else {
                // Fallback to open/close
                try await client.callService(
                    domain: "cover",
                    service: position > 50 ? "open_cover" : "close_cover",
                    target: ["entity_id": entityId]
                )
            }
        } else if let tilt = value as? Int {
            // Check if cover supports tilt position (feature bit 128)
            if features & 128 != 0 {
                // Convert from -90 to 90 to 0-100
                let tiltPosition = Int((Double(tilt) + 90) / 1.8)
                try await client.callService(
                    domain: "cover",
                    service: "set_cover_tilt_position",
                    serviceData: ["tilt_position": tiltPosition],
                    target: ["entity_id": entityId]
                )
            }
        } else if let targetDoor = value as? Int {
            // Garage door: 0=open, 1=closed
            try await client.callService(
                domain: "cover",
                service: targetDoor == 0 ? "open_cover" : "close_cover",
                target: ["entity_id": entityId]
            )
        }
    }

    private func writeFanValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        if let isOn = value as? Bool {
            try await client.callService(
                domain: "fan",
                service: isOn ? "turn_on" : "turn_off",
                target: ["entity_id": entityId]
            )
        } else if let speed = value as? Int {
            try await client.callService(
                domain: "fan",
                service: "set_percentage",
                serviceData: ["percentage": speed],
                target: ["entity_id": entityId]
            )
        } else if let oscillating = value as? Int {
            try await client.callService(
                domain: "fan",
                service: "oscillate",
                serviceData: ["oscillating": oscillating == 1],
                target: ["entity_id": entityId]
            )
        } else if let direction = value as? Int {
            try await client.callService(
                domain: "fan",
                service: "set_direction",
                serviceData: ["direction": direction == 0 ? "forward" : "reverse"],
                target: ["entity_id": entityId]
            )
        }
    }

    private func writeHumidifierValue(client: HomeAssistantClient, entityId: String, characteristicUUID: UUID, value: Any) async throws {
        if let isOn = value as? Bool {
            try await client.callService(
                domain: "humidifier",
                service: isOn ? "turn_on" : "turn_off",
                target: ["entity_id": entityId]
            )
        } else if let humidity = value as? Int {
            try await client.callService(
                domain: "humidifier",
                service: "set_humidity",
                serviceData: ["humidity": humidity],
                target: ["entity_id": entityId]
            )
        }
    }

    private func writeAlarmValue(client: HomeAssistantClient, entityId: String, value: Any) async throws {
        guard let targetState = value as? Int else { return }

        let service: String
        switch targetState {
        case 0: service = "alarm_arm_home"
        case 1: service = "alarm_arm_away"
        case 2: service = "alarm_arm_night"
        case 3: service = "alarm_disarm"
        default: return
        }

        // Check if alarm requires a code
        let requiresCode = mapper.alarmRequiresCode(for: entityId)
        if requiresCode && targetState != 3 {
            // Arming requires a code - we don't have one stored yet
            // TODO: Add alarm code setting in preferences
            logger.warning("Alarm panel requires a code to arm - skipping")
            delegate?.platformDidEncounterError(self, message: "This alarm panel requires a code to arm. Code entry is not yet supported.")
            return
        }

        try await client.callService(
            domain: "alarm_control_panel",
            service: service,
            target: ["entity_id": entityId]
        )
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        guard let entityId = mapper.getEntityIdFromCharacteristic(identifier) else { return nil }
        return mapper.getCharacteristicValues(for: entityId)[identifier]
    }

    // MARK: - Cameras

    func getCameraStream(cameraIdentifier: UUID) async throws -> CameraStreamInfo {
        guard let client = client else {
            throw HomeAssistantClientError.notConnected
        }

        let entityId = findEntityId(for: cameraIdentifier, domain: "camera")
        guard let entityId = entityId else {
            throw HomeAssistantClientError.invalidResponse
        }

        // Use WebRTC signaling
        let signaling = CameraStreamInfo.WebRTCSignaling(
            sendOffer: { [weak client] offer in
                guard let client = client else { throw HomeAssistantClientError.notConnected }
                return try await client.sendWebRTCOffer(entityId: entityId, offer: offer)
            },
            sendCandidate: { [weak client] candidate in
                guard let client = client else { throw HomeAssistantClientError.notConnected }
                try await client.sendWebRTCCandidate(entityId: entityId, candidate: candidate)
            }
        )

        return CameraStreamInfo(cameraId: cameraIdentifier, streamType: .webrtc(signaling: signaling))
    }

    func getCameraSnapshotURL(cameraIdentifier: UUID) -> URL? {
        guard let entityId = findEntityId(for: cameraIdentifier, domain: "camera") else {
            return nil
        }
        return client?.getCameraSnapshotURL(entityId: entityId)
    }

    // MARK: - Debug

    func getRawDataDump() -> String? {
        return cachedMenuDataJSON
    }

    // MARK: - Helpers

    private func findEntityId(for uuid: UUID, domain: String) -> String? {
        // Generate menu data and find matching entity
        let menuData = mapper.generateMenuData()

        if domain == "scene" {
            for scene in menuData.scenes {
                if UUID(uuidString: scene.uniqueIdentifier) == uuid {
                    // Reconstruct entity ID - this is a bit hacky
                    // We need the original entity ID, so let's search differently
                    return mapper.getEntityId(for: uuid)
                }
            }
        } else if domain == "camera" {
            for camera in menuData.cameras {
                if UUID(uuidString: camera.uniqueIdentifier) == uuid {
                    return mapper.getEntityId(for: uuid)
                }
            }
        }

        return mapper.getEntityId(for: uuid)
    }
}

// MARK: - HomeAssistantClientDelegate

extension HomeAssistantPlatform: HomeAssistantClientDelegate {
    func clientDidConnect(_ client: HomeAssistantClient) {
        logger.info("Client connected")
    }

    func clientDidDisconnect(_ client: HomeAssistantClient, error: Error?) {
        logger.info("Client disconnected: \(error?.localizedDescription ?? "no error")")
        delegate?.platformDidEncounterError(self, message: "Disconnected from Home Assistant")
    }

    func client(_ client: HomeAssistantClient, didReceiveStateChange entityId: String, newState: HAEntityState, oldState: HAEntityState?) {
        logger.debug("State change: \(entityId, privacy: .public) -> \(newState.state)")

        // Update mapper
        mapper.updateState(newState)

        // Notify delegate of characteristic changes
        let values = mapper.getCharacteristicValues(for: entityId)
        for (uuid, value) in values {
            delegate?.platformDidUpdateCharacteristic(self, identifier: uuid, value: value)
        }

        // Check for doorbell events
        if newState.domain == "event" && newState.deviceClass == "doorbell" {
            // Find associated camera
            if let cameraUUID = findAssociatedCamera(for: entityId) {
                delegate?.platformDidReceiveDoorbellEvent(self, cameraIdentifier: cameraUUID)
            }
        }
    }

    func client(_ client: HomeAssistantClient, didReceiveEvent event: HAEvent) {
        // Handle other event types if needed
    }

    func client(_ client: HomeAssistantClient, didEncounterError error: Error) {
        delegate?.platformDidEncounterError(self, message: error.localizedDescription)
    }

    private func findAssociatedCamera(for doorbellEntityId: String) -> UUID? {
        // Try to find camera with similar name/device
        let menuData = mapper.generateMenuData()
        for camera in menuData.cameras {
            // Simple heuristic: camera name contains doorbell-related terms
            // or is from the same device
            // This is a simplification - real implementation would check device associations
            return UUID(uuidString: camera.uniqueIdentifier)
        }
        return nil
    }
}
