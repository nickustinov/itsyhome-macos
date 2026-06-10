//
//  Automation.swift
//  macOSBridge
//
//  Automation model. Triggers / conditions / actions are enums with
//  associated values - Swift auto-synthesizes Codable + Equatable, and
//  "extensible" means adding a case plus a handler in AutomationEngine. See
//  docs/superpowers/specs/2026-06-09-automations-framework-design.md.
//
import Foundation

struct Automation: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var enabled: Bool
    var trigger: AutomationTrigger
    var conditions: [AutomationCondition]
    var actions: [AutomationAction]

    /// The single Duration condition, if any (v1 supports one).
    var durationSeconds: Int? {
        for c in conditions { if case .duration(let s) = c { return s } }
        return nil
    }
}

enum AutomationTrigger: Codable, Equatable {
    case accessoryState(AccessoryStateTrigger)
    // M2: case schedule(ScheduleTrigger), case webhook(WebhookTrigger)
}

enum AutomationCondition: Codable, Equatable {
    case duration(seconds: Int)
}

enum AutomationAction: Codable, Equatable {
    case setVirtualSensor(SetVirtualSensorAction)
    // M3: case controlDevice(ControlDeviceAction)
}

struct AccessoryStateTrigger: Codable, Equatable {
    var characteristicId: UUID
    var accessoryName: String         // display + unresolved detection
    var characteristicLabel: String   // e.g. "Contact"
    var comparator: Comparator
    var value: Double

    enum Comparator: String, Codable { case equal, notEqual, greater, less }

    /// Coerce a HomeKit value (Bool/Int/Double/NSNumber) to Double.
    func currentValueAsDouble(_ raw: Any?) -> Double? {
        switch raw {
        case let b as Bool: return b ? 1 : 0
        case let i as Int: return Double(i)
        case let d as Double: return d
        case let n as NSNumber: return n.doubleValue
        default: return nil
        }
    }

    func isSatisfied(by raw: Any?) -> Bool {
        guard let v = currentValueAsDouble(raw) else { return false }
        switch comparator {
        case .equal:    return v == value
        case .notEqual: return v != value
        case .greater:  return v > value
        case .less:     return v < value
        }
    }
}

struct SetVirtualSensorAction: Codable, Equatable {
    var deviceId: UUID
    var rePulse: RePulse

    struct RePulse: Codable, Equatable {
        var enabled: Bool
        var intervalSeconds: Int
    }
}
