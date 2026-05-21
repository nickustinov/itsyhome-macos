//
//  WebhookResponses.swift
//  macOSBridge
//
//  Codable response models for webhook API endpoints
//

import Foundation

// MARK: - Common responses

struct APIResponse: Encodable {
    let status: String
    var message: String?

    static let success = APIResponse(status: "success")

    static func partial(succeeded: Int, failed: Int) -> APIResponse {
        APIResponse(status: "partial", message: "\(succeeded) succeeded, \(failed) failed")
    }

    static func error(_ message: String) -> APIResponse {
        APIResponse(status: "error", message: message)
    }
}

// MARK: - Status endpoint

struct StatusResponse: Encodable {
    let rooms: Int
    let devices: Int
    let accessories: Int
    let reachable: Int
    let unreachable: Int
    let scenes: Int
    let groups: Int
    // Feature flag: clients (e.g. the G2 glasses app) check this before
    // showing the "Tap to speak" affordance. True when the user has
    // toggled Voice control on in Settings → Webhooks/CLI AND macOS has
    // granted speech-recognition authorization.
    let voiceEnabled: Bool
}

// MARK: - Voice transcription

struct VoiceTranscribeResponse: Encodable {
    let status: String       // "success" / "error"
    let text: String?        // recognised text (nil on error)
    let confidence: Float?   // best transcription's first-segment confidence
    let message: String?     // human-readable error
}

// MARK: - List endpoints

struct RoomListItem: Encodable {
    let name: String
    let icon: String
}

struct DeviceListItem: Encodable {
    let name: String
    let type: String
    let icon: String
    let reachable: Bool
    var room: String?
}

struct SceneListItem: Encodable {
    let name: String
    let icon: String
    // Optional — server may omit when the scene has no actions (e.g. HA
    // snapshot scenes), in which case clients fall back to fire-only
    // behaviour and don't render an on/off indicator.
    var state: SceneState?
}

struct SceneState: Encodable {
    var on: Bool?
}

struct GroupListItem: Encodable {
    let name: String
    let icon: String
    let devices: Int
    var room: String?
}

// /list/favourites: the items the user has pinned to the menu bar (services,
// rooms, scenes, device groups). `kind` discriminates so a client knows how
// to dispatch a tap (open device screen, fire scene, drill into room, etc.).
struct FavouriteListItem: Encodable {
    let kind: String   // "service" | "group" | "scene" | "room"
    let name: String
    let icon: String
    var type: String?      // service type label (for kind=service)
    var room: String?      // for services and room-scoped groups
    var reachable: Bool?   // for services
}

// MARK: - Info endpoint

struct ServiceInfoResponse: Encodable {
    let name: String
    let type: String
    let icon: String
    let reachable: Bool
    var room: String?
    var state: ServiceState?
}

struct ServiceState: Encodable {
    var on: Bool?
    var brightness: Int?
    var position: Int?
    var temperature: Double?
    var targetTemperature: Double?
    // Auto-mode thermostats (e.g. Ecobee) and HeaterCooler ACs use two
    // setpoints instead of a single targetTemperature. Either or both can
    // be present; clients should render whichever is non-nil.
    var heatingThreshold: Double?
    var coolingThreshold: Double?
    var mode: String?
    // Modes the device actually supports (e.g. ["off","cool","heat_cool","auto"]).
    // HA climate provides this directly; HK Thermostat / HeaterCooler get
    // translated from their valid-state arrays. Clients should restrict the
    // Mode submenu to this list so users don't pick a mode the device drops.
    var availableModes: [String]?
    var humidity: Double?
    var hue: Double?
    var saturation: Double?
    var locked: Bool?
    var doorState: String?
    var speed: Double?
    // Min/Max for stepped rotation-speed characteristics. HomeKit fans can
    // override the default 0–100 range (e.g. 0–6 for a 6-speed ceiling fan);
    // clients need these to render the speed scale and presets correctly.
    var speedMin: Double?
    var speedMax: Double?
    var securityState: String?
}

struct SceneInfoResponse: Encodable {
    let name: String
    let type: String
    let icon: String
    var state: SceneState?
}

// MARK: - Debug endpoint

struct DebugServiceResponse: Encodable {
    let name: String
    let accessoryName: String
    let serviceType: String
    let serviceTypeLabel: String
    let serviceId: String
    let reachable: Bool
    var room: String?
    var roomId: String?
    var characteristics: [String: CharacteristicDebugInfo]?
    var limits: ServiceLimits?
}

struct CharacteristicDebugInfo: Encodable {
    let id: String
    let value: AnyEncodable
}

struct ServiceLimits: Encodable {
    var colorTemperatureMin: Double?
    var colorTemperatureMax: Double?
    var rotationSpeedMin: Double?
    var rotationSpeedMax: Double?
    var valveType: Int?

    var isEmpty: Bool {
        colorTemperatureMin == nil && colorTemperatureMax == nil &&
        rotationSpeedMin == nil && rotationSpeedMax == nil && valveType == nil
    }
}

struct DebugAllResponse: Encodable {
    let accessories: [DebugAccessoryInfo]
    let rooms: Int
    let scenes: Int
}

struct DebugAccessoryInfo: Encodable {
    let name: String
    let reachable: Bool
    let services: [DebugServiceResponse]
    var room: String?
}

// MARK: - SSE event models

struct CharacteristicEvent: Encodable {
    let timestamp: String
    let device: String
    let room: String
    let type: String
    let characteristic: String
    let value: AnyEncodable
    let characteristicId: String
    let serviceId: String
    var entityId: String?
}

struct CharacteristicContext {
    let deviceName: String
    let roomName: String
    let deviceType: String
    let characteristicName: String
    let serviceId: String
    var entityId: String?
}

// MARK: - Type erasure for encoding Any values

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    init(_ value: Any?) {
        guard let value else {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
            return
        }

        if let bool = value as? Bool {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(bool)
            }
        } else if let int = value as? Int {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(int)
            }
        } else if let double = value as? Double {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(double)
            }
        } else if let number = value as? NSNumber {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(number.doubleValue)
            }
        } else if let string = value as? String {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(string)
            }
        } else {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(String(describing: value))
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - JSON encoder helper

extension WebhookServer {
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? Self.jsonEncoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"status\":\"error\",\"message\":\"Encoding failed\"}"
        }
        return string
    }
}
