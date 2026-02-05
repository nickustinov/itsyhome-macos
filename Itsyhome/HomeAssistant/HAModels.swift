//
//  HAModels.swift
//  Itsyhome
//
//  Home Assistant API data models
//

import Foundation

// MARK: - Entity state

/// Represents the state of a Home Assistant entity
struct HAEntityState {
    let entityId: String
    let state: String
    let attributes: [String: Any]
    let lastChanged: Date?
    let lastUpdated: Date?
    let context: HAContext?

    /// Domain extracted from entity_id (e.g., "light" from "light.kitchen")
    var domain: String {
        entityId.components(separatedBy: ".").first ?? ""
    }

    /// Object ID extracted from entity_id (e.g., "kitchen" from "light.kitchen")
    var objectId: String {
        entityId.components(separatedBy: ".").dropFirst().joined(separator: ".")
    }

    /// Friendly name from attributes, or object ID as fallback
    var friendlyName: String {
        attributes["friendly_name"] as? String ?? objectId.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Device class from attributes
    var deviceClass: String? {
        attributes["device_class"] as? String
    }

    /// Supported features bitmask
    var supportedFeatures: Int {
        attributes["supported_features"] as? Int ?? 0
    }

    init?(json: [String: Any]) {
        guard let entityId = json["entity_id"] as? String,
              let state = json["state"] as? String else {
            return nil
        }

        self.entityId = entityId
        self.state = state
        self.attributes = json["attributes"] as? [String: Any] ?? [:]
        self.lastChanged = (json["last_changed"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        self.lastUpdated = (json["last_updated"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        self.context = (json["context"] as? [String: Any]).flatMap { HAContext(json: $0) }
    }
}

// MARK: - Context

struct HAContext {
    let id: String
    let parentId: String?
    let userId: String?

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else { return nil }
        self.id = id
        self.parentId = json["parent_id"] as? String
        self.userId = json["user_id"] as? String
    }
}

// MARK: - Event

struct HAEvent {
    let eventType: String
    let data: [String: Any]
    let timeFired: Date?
    let origin: String?
    let context: HAContext?

    init?(json: [String: Any]) {
        guard let eventType = json["event_type"] as? String else { return nil }

        self.eventType = eventType
        self.data = json["data"] as? [String: Any] ?? [:]
        self.timeFired = (json["time_fired"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        self.origin = json["origin"] as? String
        self.context = (json["context"] as? [String: Any]).flatMap { HAContext(json: $0) }
    }
}

// MARK: - Area

struct HAArea {
    let areaId: String
    let name: String
    let floorId: String?
    let labels: [String]

    init?(json: [String: Any]) {
        guard let areaId = json["area_id"] as? String,
              let name = json["name"] as? String else {
            return nil
        }

        self.areaId = areaId
        self.name = name
        self.floorId = json["floor_id"] as? String
        self.labels = json["labels"] as? [String] ?? []
    }
}

// MARK: - Device

struct HADevice {
    let id: String
    let name: String?
    let areaId: String?
    let manufacturer: String?
    let model: String?
    let identifiers: [[String]]
    let connections: [[String]]
    let viaDeviceId: String?
    let labels: [String]
    let disabled: Bool

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else { return nil }

        self.id = id
        self.name = json["name"] as? String ?? json["name_by_user"] as? String
        self.areaId = json["area_id"] as? String
        self.manufacturer = json["manufacturer"] as? String
        self.model = json["model"] as? String
        self.identifiers = json["identifiers"] as? [[String]] ?? []
        self.connections = json["connections"] as? [[String]] ?? []
        self.viaDeviceId = json["via_device_id"] as? String
        self.labels = json["labels"] as? [String] ?? []
        self.disabled = (json["disabled_by"] as? String) != nil
    }
}

// MARK: - Entity registry entry

struct HAEntityRegistryEntry {
    let entityId: String
    let uniqueId: String?
    let deviceId: String?
    let areaId: String?
    let name: String?
    let icon: String?
    let platform: String
    let disabled: Bool
    let hidden: Bool
    let labels: [String]

    init?(json: [String: Any]) {
        guard let entityId = json["entity_id"] as? String,
              let platform = json["platform"] as? String else {
            return nil
        }

        self.entityId = entityId
        self.uniqueId = json["unique_id"] as? String
        self.deviceId = json["device_id"] as? String
        self.areaId = json["area_id"] as? String
        self.name = json["name"] as? String ?? json["original_name"] as? String
        self.icon = json["icon"] as? String ?? json["original_icon"] as? String
        self.platform = platform
        self.disabled = (json["disabled_by"] as? String) != nil
        self.hidden = (json["hidden_by"] as? String) != nil
        self.labels = json["labels"] as? [String] ?? []
    }
}

// MARK: - Domain constants

enum HADomain: String {
    case light
    case `switch`
    case climate
    case cover
    case lock
    case fan
    case humidifier
    case valve
    case sensor
    case binarySensor = "binary_sensor"
    case alarmControlPanel = "alarm_control_panel"
    case camera
    case scene
    case script
    case event
}

// MARK: - Light attributes

extension HAEntityState {
    /// Brightness (0-255)
    var brightness: Int? {
        attributes["brightness"] as? Int
    }

    /// Brightness as percentage (0-100)
    var brightnessPercent: Int? {
        guard let b = brightness else { return nil }
        return Int(Double(b) / 2.55)
    }

    /// Color temperature in Kelvin
    var colorTempKelvin: Int? {
        attributes["color_temp_kelvin"] as? Int
    }

    /// Color temperature in Mireds (for HomeKit compatibility)
    var colorTempMireds: Int? {
        guard let kelvin = colorTempKelvin, kelvin > 0 else { return nil }
        return 1_000_000 / kelvin
    }

    /// Hue and saturation as tuple
    var hsColor: (hue: Double, saturation: Double)? {
        guard let hs = attributes["hs_color"] as? [Double], hs.count == 2 else { return nil }
        return (hs[0], hs[1])
    }

    /// RGB color as tuple
    var rgbColor: (red: Int, green: Int, blue: Int)? {
        guard let rgb = attributes["rgb_color"] as? [Int], rgb.count == 3 else { return nil }
        return (rgb[0], rgb[1], rgb[2])
    }

    /// Min color temp in Kelvin
    var minColorTempKelvin: Int? {
        attributes["min_color_temp_kelvin"] as? Int
    }

    /// Max color temp in Kelvin
    var maxColorTempKelvin: Int? {
        attributes["max_color_temp_kelvin"] as? Int
    }

    /// Supported color modes (authoritative source for light capabilities)
    /// Values: onoff, brightness, color_temp, hs, xy, rgb, rgbw, rgbww, white
    var supportedColorModes: [String] {
        attributes["supported_color_modes"] as? [String] ?? []
    }

    /// Color mode currently in use
    var colorMode: String? {
        attributes["color_mode"] as? String
    }

    /// Whether light supports color (hs, xy, rgb, rgbw, rgbww)
    var supportsColor: Bool {
        let colorModes: Set<String> = ["hs", "xy", "rgb", "rgbw", "rgbww"]
        return !supportedColorModes.filter { colorModes.contains($0) }.isEmpty
    }

    /// Whether light supports color temperature
    /// Note: "rgbww" lights have warm+cold white LEDs and can do color temp
    var supportsColorTemp: Bool {
        supportedColorModes.contains("color_temp") || supportedColorModes.contains("rgbww")
    }

    /// Whether light supports brightness
    var supportsBrightness: Bool {
        // All modes except "onoff" support brightness
        return !supportedColorModes.isEmpty && supportedColorModes != ["onoff"]
    }

    /// Whether light needs mode switching UI (separate color vs color_temp modes)
    /// True for lights with hs/rgb/xy + color_temp as separate modes
    /// False for rgbww/rgbw lights which control color AND white simultaneously
    /// Note: hs+white lights are treated as regular RGB lights (no mode switching)
    var needsColorModeSwitch: Bool {
        let colorOnlyModes: Set<String> = ["hs", "xy", "rgb"]
        let hasColorOnlyMode = !supportedColorModes.filter { colorOnlyModes.contains($0) }.isEmpty
        let hasColorTemp = supportedColorModes.contains("color_temp")
        return hasColorOnlyMode && hasColorTemp
    }
}

// MARK: - Climate attributes

extension HAEntityState {
    /// Current temperature
    var currentTemperature: Double? {
        attributes["current_temperature"] as? Double
    }

    /// Target temperature (single setpoint)
    var targetTemperature: Double? {
        attributes["temperature"] as? Double
    }

    /// Target temperature low (for heat_cool mode)
    var targetTempLow: Double? {
        attributes["target_temp_low"] as? Double
    }

    /// Target temperature high (for heat_cool mode)
    var targetTempHigh: Double? {
        attributes["target_temp_high"] as? Double
    }

    /// HVAC mode (heat, cool, heat_cool, off, etc.)
    var hvacMode: String {
        state
    }

    /// HVAC action (heating, cooling, idle, off)
    var hvacAction: String? {
        attributes["hvac_action"] as? String
    }

    /// Available HVAC modes
    var hvacModes: [String] {
        attributes["hvac_modes"] as? [String] ?? []
    }

    /// Current humidity
    var currentHumidity: Double? {
        attributes["current_humidity"] as? Double
    }

    /// Fan mode
    var fanMode: String? {
        attributes["fan_mode"] as? String
    }

    /// Swing mode
    var swingMode: String? {
        attributes["swing_mode"] as? String
    }
}

// MARK: - Cover attributes

extension HAEntityState {
    /// Current position (0=closed, 100=open)
    var currentPosition: Int? {
        attributes["current_position"] as? Int
    }

    /// Current tilt position (0-100)
    var currentTiltPosition: Int? {
        attributes["current_tilt_position"] as? Int
    }

    /// Whether cover is opening
    var isOpening: Bool {
        state == "opening"
    }

    /// Whether cover is closing
    var isClosing: Bool {
        state == "closing"
    }

    /// Whether cover is fully closed
    var isClosed: Bool {
        state == "closed"
    }
}

// MARK: - Lock attributes

extension HAEntityState {
    /// Whether lock is locked
    var isLocked: Bool {
        state == "locked"
    }

    /// Whether lock is locking
    var isLocking: Bool {
        state == "locking"
    }

    /// Whether lock is unlocking
    var isUnlocking: Bool {
        state == "unlocking"
    }

    /// Whether lock is jammed
    var isJammed: Bool {
        state == "jammed"
    }
}

// MARK: - Fan attributes

extension HAEntityState {
    /// Fan speed percentage (0-100)
    var percentage: Int? {
        attributes["percentage"] as? Int
    }

    /// Fan preset mode
    var presetMode: String? {
        attributes["preset_mode"] as? String
    }

    /// Whether fan is oscillating
    var isOscillating: Bool {
        attributes["oscillating"] as? Bool ?? false
    }

    /// Fan direction (forward/reverse)
    var direction: String? {
        attributes["direction"] as? String
    }

    /// Whether fan supports percentage/speed control
    /// SET_PERCENTAGE is bit 0 (value 1) in supported_features
    var supportsPercentage: Bool {
        supportedFeatures & 1 != 0
    }
}

// MARK: - Alarm control panel attributes

extension HAEntityState {
    /// Alarm state (armed_home, armed_away, armed_night, disarmed, triggered, etc.)
    var alarmState: String {
        state
    }

    /// Whether code is required to arm
    var codeArmRequired: Bool {
        attributes["code_arm_required"] as? Bool ?? true
    }

    /// Alarm panel supported modes (from supported_features bitmask)
    /// ARM_HOME=1, ARM_AWAY=2, ARM_NIGHT=4, TRIGGER=8, ARM_CUSTOM_BYPASS=16, ARM_VACATION=32
    var alarmSupportedModes: [String] {
        var modes: [String] = ["disarmed"]  // Always available
        let features = supportedFeatures
        if features & 1 != 0 { modes.append("armed_home") }
        if features & 2 != 0 { modes.append("armed_away") }
        if features & 4 != 0 { modes.append("armed_night") }
        if features & 16 != 0 { modes.append("armed_custom_bypass") }
        if features & 32 != 0 { modes.append("armed_vacation") }
        return modes
    }

    /// Code format (number, text, or nil)
    var codeFormat: String? {
        attributes["code_format"] as? String
    }
}

// MARK: - Sensor attributes

extension HAEntityState {
    /// Unit of measurement
    var unitOfMeasurement: String? {
        attributes["unit_of_measurement"] as? String
    }

    /// Numeric state value
    var numericState: Double? {
        Double(state)
    }
}

// MARK: - Humidifier attributes

extension HAEntityState {
    /// Target humidity (0-100)
    var targetHumidity: Int? {
        attributes["humidity"] as? Int
    }

    /// Humidifier mode
    var humidifierMode: String? {
        attributes["mode"] as? String
    }

    /// Available modes
    var availableModes: [String] {
        attributes["available_modes"] as? [String] ?? []
    }

    /// Humidifier action (humidifying, drying, idle, off)
    var humidifierAction: String? {
        attributes["action"] as? String
    }
}

// MARK: - Valve attributes

extension HAEntityState {
    /// Whether valve is open
    var isOpen: Bool {
        state == "open"
    }

    /// Valve position (0-100) if supported
    var valvePosition: Int? {
        attributes["current_position"] as? Int
    }
}

// MARK: - Camera attributes

extension HAEntityState {
    /// Whether camera is streaming
    var isStreaming: Bool {
        state == "streaming"
    }

    /// Whether camera is recording
    var isRecording: Bool {
        state == "recording" || (attributes["is_recording"] as? Bool ?? false)
    }

    /// Supported stream types
    var frontendStreamTypes: [String] {
        attributes["frontend_stream_types"] as? [String] ?? []
    }

    /// Whether WebRTC is supported
    var supportsWebRTC: Bool {
        frontendStreamTypes.contains("web_rtc")
    }
}
