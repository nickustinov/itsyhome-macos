//
//  HubitatPlatform.swift
//  Itsyhome
//
//  SmartHomePlatform implementation for Hubitat
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatPlatform")

final class HubitatPlatform: SmartHomePlatform {

    // MARK: - SmartHomePlatform properties

    let platformType: SmartHomePlatformType = .hubitat
    let capabilities: PlatformCapabilities = .hubitat

    weak var delegate: SmartHomePlatformDelegate?

    var isConnected: Bool {
        client?.isConnected ?? false
    }

    // MARK: - Home support (not applicable for Hubitat)

    var availableHomes: [HomeData] { [] }
    var selectedHomeIdentifier: UUID? {
        get { nil }
        set { }
    }

    // MARK: - Camera support (not supported on Hubitat)

    var hasCameras: Bool { false }

    // MARK: - Internal properties (accessed by extensions)

    var client: HubitatClient?
    let mapper = HubitatDeviceMapper()

    // MARK: - Private properties

    private let cacheLock = NSLock()
    private var _cachedMenuDataJSON: String?
    private var cachedMenuDataJSON: String? {
        get { cacheLock.lock(); defer { cacheLock.unlock() }; return _cachedMenuDataJSON }
        set { cacheLock.lock(); _cachedMenuDataJSON = newValue; cacheLock.unlock() }
    }

    // MARK: - Initialization

    init() {
        logger.info("HubitatPlatform initialized")
    }

    // MARK: - Connection

    func connect() async throws {
        guard let hubURL = HubitatAuthManager.shared.hubURL,
              let appId = HubitatAuthManager.shared.appId,
              let accessToken = HubitatAuthManager.shared.accessToken else {
            throw HubitatAuthError.notConfigured
        }

        logger.info("Connecting to Hubitat...")

        client = try HubitatClient(hubURL: hubURL, appId: appId, accessToken: accessToken)
        client?.delegate = self

        // Load devices first (populates authorizedDeviceIds for EventSocket filtering)
        await loadAllData()

        // Then connect EventSocket
        try await client?.connect()
    }

    func disconnect() {
        logger.info("Disconnecting from Hubitat")
        client?.disconnect()
        client = nil
    }

    // MARK: - Data loading

    func loadAllData() async {
        guard let client = client else { return }

        do {
            let devices = try await client.getAllDevices()
            mapper.loadDevices(devices)

            // Generate and cache menu data
            let menuData = mapper.generateMenuData()
            if let jsonData = try? JSONEncoder().encode(menuData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                cachedMenuDataJSON = jsonString
                delegate?.platformDidUpdateMenuData(self, jsonString: jsonString)
            }

            logger.info("Loaded \(devices.count) Hubitat devices")
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

    // MARK: - Cameras (not supported)

    func getCameraStream(cameraIdentifier: UUID) async throws -> CameraStreamInfo {
        throw HubitatClientError.commandFailed("Camera streaming is not supported on Hubitat")
    }

    func getCameraSnapshotURL(cameraIdentifier: UUID) -> URL? {
        return nil
    }

    // MARK: - Debug

    func getRawDataDump() -> String? {
        return cachedMenuDataJSON
    }
}
