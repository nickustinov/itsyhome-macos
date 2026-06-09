//
//  VirtualDevice.swift
//  macOSBridge
//
//  Model for a user-defined virtual sensor published over HAP. Read-only in
//  v1; `state` is the last known value. Persisted via VirtualDeviceStore, so
//  every Codable raw value here is a stable on-disk contract.
//
import Foundation
import HAPCore

/// The seven read-only binary sensor types ItsyHome can publish.
enum VirtualSensorType: String, Codable, CaseIterable, Equatable {
    case contact, motion, occupancy, leak, smoke, carbonMonoxide, carbonDioxide
}

/// Cosmetic role for a contact sensor: drives ItsyHome's icon + wording only.
/// HomeKit still sees a plain contact sensor. Nil/ignored for other types.
enum ContactRole: String, Codable, CaseIterable, Equatable {
    case generic, door, window
}

struct VirtualDevice: Codable, Equatable, Identifiable {
    let id: UUID
    var key: String          // immutable-by-default URL slug
    var name: String         // display name, unique vs real devices
    var type: VirtualSensorType
    var role: ContactRole?   // only meaningful when type == .contact
    var room: String?        // ItsyHome grouping only (not pushed to HomeKit)
    var aid: UInt64          // persisted HAP accessory id
    var state: Bool          // last known state

    /// URL-safe slug: lowercase, alphanumerics, runs of other chars -> single "-".
    static func slug(from name: String) -> String {
        let lowered = name.lowercased()
        var out = ""
        var lastDash = false
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch); lastDash = false
            } else if !lastDash {
                out.append("-"); lastDash = true
            }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

extension VirtualSensorType {
    /// hap-swift factory for this sensor (carbonDioxide uses our local factory).
    func makeHAPService(startIID: UInt64) -> HAPService {
        switch self {
        case .contact:        return .contactSensor(startIID: startIID)
        case .motion:         return .motionSensor(startIID: startIID)
        case .occupancy:      return .occupancySensor(startIID: startIID)
        case .leak:           return .leakSensor(startIID: startIID)
        case .smoke:          return .smokeSensor(startIID: startIID)
        case .carbonMonoxide: return .carbonMonoxideSensor(startIID: startIID)
        case .carbonDioxide:  return .carbonDioxideSensor(startIID: startIID)
        }
    }

    /// The hap-swift characteristic type whose IID we read back after addAccessory.
    var detectedCharacteristic: HAPCharacteristicType {
        switch self {
        case .contact:        return .contactSensorState
        case .motion:         return .motionDetected
        case .occupancy:      return .occupancyDetected
        case .leak:           return .leakDetected
        case .smoke:          return .smokeDetected
        case .carbonMonoxide: return .carbonMonoxideDetected
        case .carbonDioxide:  return .carbonDioxideDetected
        }
    }

    /// The state word shown to the user for each kind (1 = active, 0 = resting).
    func stateWord(on: Bool) -> String {
        switch self {
        case .contact:        return on ? "Open" : "Closed"
        case .motion:         return on ? "Motion" : "Clear"
        case .occupancy:      return on ? "Occupied" : "Clear"
        case .leak:           return on ? "Leak" : "Dry"
        case .smoke:          return on ? "Smoke" : "Clear"
        case .carbonMonoxide: return on ? "CO" : "Clear"
        case .carbonDioxide:  return on ? "CO\u{2082}" : "Clear"
        }
    }

    /// Life-safety sensors that Apple Home can raise critical alerts for.
    var isCriticalAlertType: Bool {
        switch self {
        case .leak, .smoke, .carbonMonoxide, .carbonDioxide: return true
        case .contact, .motion, .occupancy: return false
        }
    }

    /// Full HomeKit service-type UUID string used when projecting into MenuData.
    /// Maps to the constants in Itsyhome/Shared/BridgeProtocols.swift `ServiceTypes`.
    var homeKitServiceType: String {
        switch self {
        case .contact:        return ServiceTypes.contactSensor
        case .motion:         return ServiceTypes.motionSensor
        case .occupancy:      return ServiceTypes.occupancySensor
        case .leak:           return ServiceTypes.leakSensor
        case .smoke:          return ServiceTypes.smokeSensor
        case .carbonMonoxide: return ServiceTypes.carbonMonoxideSensor
        case .carbonDioxide:  return ServiceTypes.carbonDioxideSensor
        }
    }
}
