//
//  SensorKind.swift
//  macOSBridge
//
//  The kind of read-only sensor backing a SensorStateMenuItem row and the
//  pinned status display. Binary kinds (contact, motion, occupancy, leak,
//  smoke, carbon monoxide, carbon dioxide) report an active/resting state
//  word; numeric kinds (temperature, humidity) format their own reading.
//

import Foundation

enum SensorKind {
    case contact, motion, occupancy, leak, smoke, carbonMonoxide, carbonDioxide
    case temperature, humidity

    init?(serviceType: String) {
        switch serviceType {
        case ServiceTypes.contactSensor: self = .contact
        case ServiceTypes.motionSensor: self = .motion
        case ServiceTypes.occupancySensor: self = .occupancy
        case ServiceTypes.leakSensor: self = .leak
        case ServiceTypes.smokeSensor: self = .smoke
        case ServiceTypes.carbonMonoxideSensor: self = .carbonMonoxide
        case ServiceTypes.carbonDioxideSensor: self = .carbonDioxide
        case ServiceTypes.temperatureSensor: self = .temperature
        case ServiceTypes.humiditySensor: self = .humidity
        default: return nil
        }
    }

    /// Numeric kinds format a measured value; binary kinds report a state word.
    var isNumeric: Bool { self == .temperature || self == .humidity }

    /// The ServiceData field holding this kind's reading characteristic UUID.
    func stateCharacteristicId(from serviceData: ServiceData) -> String? {
        switch self {
        case .contact: return serviceData.contactSensorStateId
        case .motion: return serviceData.motionDetectedId
        case .occupancy: return serviceData.occupancyDetectedId
        case .leak: return serviceData.leakDetectedId
        case .smoke: return serviceData.smokeDetectedId
        case .carbonMonoxide: return serviceData.carbonMonoxideDetectedId
        case .carbonDioxide: return serviceData.carbonDioxideDetectedId
        case .temperature: return serviceData.currentTemperatureId
        case .humidity: return serviceData.humidityId
        }
    }

    /// Display words for binary kinds. HAP uses 1 for the "active" reading on
    /// every one of these sensors (open / motion / occupied / leak / smoke /
    /// CO / CO2) and 0 for the resting state. nil for numeric kinds, which
    /// format their value via `formattedValue(_:)` instead.
    var stateLabels: (one: String, zero: String)? {
        // Resting word shared by the kinds that simply report "nothing detected".
        let clear = String(localized: "device.sensor.clear", defaultValue: "Clear", bundle: .macOSBridge)
        switch self {
        case .contact:
            // Contact reuses the door open/closed words (same in every locale).
            return (String(localized: "device.door.open", defaultValue: "Open", bundle: .macOSBridge),
                    String(localized: "device.door.closed", defaultValue: "Closed", bundle: .macOSBridge))
        case .motion:
            return (String(localized: "device.sensor.motion", defaultValue: "Motion", bundle: .macOSBridge), clear)
        case .occupancy:
            return (String(localized: "device.sensor.occupied", defaultValue: "Occupied", bundle: .macOSBridge), clear)
        case .leak:
            return (String(localized: "device.sensor.leak", defaultValue: "Leak", bundle: .macOSBridge),
                    String(localized: "device.sensor.dry", defaultValue: "Dry", bundle: .macOSBridge))
        case .smoke:
            return (String(localized: "device.sensor.smoke", defaultValue: "Smoke", bundle: .macOSBridge), clear)
        case .carbonMonoxide:
            return (String(localized: "device.sensor.co", defaultValue: "CO", bundle: .macOSBridge), clear)
        case .carbonDioxide:
            return (String(localized: "device.sensor.co2", defaultValue: "CO2", bundle: .macOSBridge), clear)
        case .temperature, .humidity:
            return nil
        }
    }

    /// Format a numeric reading (temperature in °, humidity in %). nil for
    /// binary kinds, which use `stateLabels` instead.
    func formattedValue(_ value: Double) -> String? {
        switch self {
        case .temperature: return TemperatureFormatter.format(value, decimals: 1)
        case .humidity: return String(format: "%.0f%%", value)
        default: return nil
        }
    }
}

// MARK: - Generic Home Assistant sensors

/// Display helpers for generic HA sensors (those without a specific HomeKit
/// kind): numeric readings shown as value + unit, binary as On/Off, with an
/// icon chosen by HA device_class.
enum GenericSensor {

    /// On/Off words for a generic binary sensor.
    static var binaryLabels: (one: String, zero: String) {
        (String(localized: "device.sensor.on", defaultValue: "On", bundle: .macOSBridge),
         String(localized: "device.sensor.off", defaultValue: "Off", bundle: .macOSBridge))
    }

    /// Format a numeric reading with its unit (e.g. "453 ppm", "85%", "230 V").
    static func formattedReading(_ value: Double, unit: String?) -> String {
        let number = value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
        guard let unit, !unit.isEmpty else { return number }
        return unit == "%" ? "\(number)%" : "\(number) \(unit)"
    }

    /// Phosphor icon name for a generic sensor, chosen by HA device_class with a
    /// gauge (numeric) / circle (binary) fallback.
    static func iconName(deviceClass: String?, binary: Bool) -> String {
        switch deviceClass {
        case "carbon_dioxide": return "cloud"
        case "power", "energy", "voltage", "current", "power_factor",
             "apparent_power", "reactive_power", "energy_storage": return "lightning"
        case "illuminance": return "sun"
        case "pressure", "atmospheric_pressure": return "gauge"
        case "battery": return "battery-medium"
        case "pm25", "pm10", "pm1", "aqi", "volatile_organic_compounds",
             "volatile_organic_compounds_parts", "nitrogen_dioxide", "nitrogen_monoxide",
             "nitrous_oxide", "ozone", "sulphur_dioxide", "gas": return "wind"
        case "signal_strength", "connectivity": return "wifi-high"
        case "sound", "sound_pressure": return "speaker-high"
        case "speed", "wind_speed": return "wind"
        case "distance": return "ruler"
        case "water", "moisture", "volume", "precipitation", "precipitation_intensity": return "drop"
        case "frequency": return "wave-sine"
        case "vibration", "moving": return "wave-sawtooth"
        case "light": return "lightbulb"
        case "running": return "play"
        case "problem", "safety", "tamper": return "warning"
        case "plug", "outlet": return "plug"
        case "update": return "arrow-clockwise"
        default: return binary ? "circle" : "gauge"
        }
    }
}
