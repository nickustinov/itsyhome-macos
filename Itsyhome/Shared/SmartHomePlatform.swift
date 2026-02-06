//
//  SmartHomePlatform.swift
//  Itsyhome
//
//  Protocol abstraction for smart home platforms (HomeKit, Home Assistant)
//

import Foundation

// MARK: - Platform type

public enum SmartHomePlatformType: String, Codable {
    case homeKit = "homekit"
    case homeAssistant = "homeassistant"
}

// MARK: - Platform delegate

/// Delegate for receiving updates from a smart home platform
public protocol SmartHomePlatformDelegate: AnyObject {
    /// Called when menu data should be reloaded
    func platformDidUpdateMenuData(_ platform: SmartHomePlatform, jsonString: String)

    /// Called when a single characteristic value changes
    func platformDidUpdateCharacteristic(_ platform: SmartHomePlatform, identifier: UUID, value: Any)

    /// Called when an accessory's reachability changes
    func platformDidUpdateReachability(_ platform: SmartHomePlatform, accessoryIdentifier: UUID, isReachable: Bool)

    /// Called when an error occurs
    func platformDidEncounterError(_ platform: SmartHomePlatform, message: String)

    /// Called when the platform disconnects (resets menu to loading state, no popup)
    func platformDidDisconnect(_ platform: SmartHomePlatform)

    /// Called when a doorbell rings (for camera panel display)
    func platformDidReceiveDoorbellEvent(_ platform: SmartHomePlatform, cameraIdentifier: UUID)
}

// MARK: - Camera stream info

public struct CameraStreamInfo {
    public enum StreamType {
        case hls(url: URL)
        case mjpeg(url: URL)
        case webrtc(signaling: WebRTCSignaling)
    }

    public struct WebRTCSignaling {
        public let sendOffer: (String) async throws -> String  // SDP offer -> SDP answer
        public let sendCandidate: (String) async throws -> Void  // ICE candidate

        public init(sendOffer: @escaping (String) async throws -> String,
                    sendCandidate: @escaping (String) async throws -> Void) {
            self.sendOffer = sendOffer
            self.sendCandidate = sendCandidate
        }
    }

    public let cameraId: UUID
    public let streamType: StreamType

    public init(cameraId: UUID, streamType: StreamType) {
        self.cameraId = cameraId
        self.streamType = streamType
    }
}

// MARK: - Platform capabilities

public struct PlatformCapabilities {
    /// Whether the platform supports multiple homes (HomeKit does, HA doesn't)
    public let supportsMultipleHomes: Bool

    /// Whether scenes have trackable state (HomeKit yes via actions, HA no)
    public let supportsSceneStateTracking: Bool

    /// Whether outlets report "in use" status
    public let supportsOutletInUse: Bool

    public init(supportsMultipleHomes: Bool,
                supportsSceneStateTracking: Bool,
                supportsOutletInUse: Bool) {
        self.supportsMultipleHomes = supportsMultipleHomes
        self.supportsSceneStateTracking = supportsSceneStateTracking
        self.supportsOutletInUse = supportsOutletInUse
    }

    public static let homeKit = PlatformCapabilities(
        supportsMultipleHomes: true,
        supportsSceneStateTracking: true,
        supportsOutletInUse: true
    )

    public static let homeAssistant = PlatformCapabilities(
        supportsMultipleHomes: false,
        supportsSceneStateTracking: false,
        supportsOutletInUse: false
    )
}

// MARK: - Smart home platform protocol

/// Protocol for smart home platform implementations
public protocol SmartHomePlatform: AnyObject {

    /// The type of platform
    var platformType: SmartHomePlatformType { get }

    /// Platform capabilities
    var capabilities: PlatformCapabilities { get }

    /// Delegate for receiving updates
    var delegate: SmartHomePlatformDelegate? { get set }

    /// Whether the platform is connected and ready
    var isConnected: Bool { get }

    // MARK: - Connection

    /// Connect to the platform
    func connect() async throws

    /// Disconnect from the platform
    func disconnect()

    // MARK: - Data

    /// Reload all data and notify delegate
    func reloadData()

    /// Get the current menu data as JSON string
    func getMenuDataJSON() -> String?

    // MARK: - Homes (HomeKit only)

    /// Available homes (empty for platforms that don't support multiple homes)
    var availableHomes: [HomeData] { get }

    /// Currently selected home identifier
    var selectedHomeIdentifier: UUID? { get set }

    // MARK: - Actions

    /// Execute a scene
    func executeScene(identifier: UUID)

    /// Read a characteristic value
    func readCharacteristic(identifier: UUID)

    /// Write a characteristic value
    func writeCharacteristic(identifier: UUID, value: Any)

    /// Get current value of a characteristic (synchronous, from cache)
    func getCharacteristicValue(identifier: UUID) -> Any?

    // MARK: - Cameras

    /// Whether the platform has cameras available
    var hasCameras: Bool { get }

    /// Get camera stream info for a camera
    func getCameraStream(cameraIdentifier: UUID) async throws -> CameraStreamInfo

    /// Get a snapshot image URL for a camera
    func getCameraSnapshotURL(cameraIdentifier: UUID) -> URL?

    // MARK: - Debug

    /// Get raw platform data dump for debugging
    func getRawDataDump() -> String?
}

// MARK: - Default implementations

public extension SmartHomePlatform {
    var availableHomes: [HomeData] { [] }
    var selectedHomeIdentifier: UUID? {
        get { nil }
        set { }
    }
}
