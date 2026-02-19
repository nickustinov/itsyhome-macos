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

    // MARK: - Internal properties (accessed by extensions)

    var client: HomeAssistantClient?
    let mapper = EntityMapper()

    /// Pending hue/saturation writes to handle race conditions
    /// When hue and saturation are written in quick succession, we need to track pending values
    /// so the second write uses the new value instead of stale cache
    var pendingHue: [String: Double] = [:]
    var pendingSaturation: [String: Double] = [:]
    let pendingColorLock = NSLock()

    // MARK: - Private properties

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

        client = try HomeAssistantClient(serverURL: serverURL, accessToken: accessToken)
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
            async let sceneConfigs = client.getAllSceneConfigs()
            async let config = client.getConfig()

            let (statesResult, entitiesResult, devicesResult, areasResult, sceneConfigsResult, configResult) = try await (states, entities, devices, areas, sceneConfigs, config)

            // Extract temperature unit from HA config
            if let unitSystem = configResult["unit_system"] as? [String: Any],
               let tempUnit = unitSystem["temperature"] as? String {
                mapper.setTemperatureUnit(tempUnit)
            }

            mapper.loadData(
                states: statesResult,
                entities: entitiesResult,
                devices: devicesResult,
                areas: areasResult,
                sceneConfigs: sceneConfigsResult
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

    func findEntityId(for uuid: UUID, domain: String) -> String? {
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
