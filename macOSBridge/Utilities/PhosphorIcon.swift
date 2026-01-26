//
//  PhosphorIcon.swift
//  macOSBridge
//
//  Phosphor Icons integration for consistent iconography
//  Icons are loaded at runtime from SVG files: ph.{name}.svg and ph.{name}.fill.svg
//

import AppKit

// MARK: - PhosphorIcon

enum PhosphorIcon {

    /// The bundle containing Phosphor icon SVGs
    private static let bundle = Bundle(for: BundleToken.self)

    /// Cache for loaded icons to avoid repeated disk reads
    private static var iconCache: [String: NSImage] = [:]
    private static let cacheLock = NSLock()

    /// Get a Phosphor icon by name (regular weight)
    static func regular(_ name: String) -> NSImage? {
        loadIcon(named: "ph.\(name)")
    }

    /// Get a Phosphor icon by name (fill weight)
    static func fill(_ name: String) -> NSImage? {
        loadIcon(named: "ph.\(name).fill")
    }

    /// Get icon with automatic variant based on state (fill when on, regular when off)
    static func icon(_ name: String, filled: Bool) -> NSImage? {
        filled ? fill(name) : regular(name)
    }

    /// Load an SVG icon from the bundle's Resources/PhosphorIcons folder
    private static func loadIcon(named name: String) -> NSImage? {
        // Check cache first
        cacheLock.lock()
        if let cached = iconCache[name] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Load SVG from bundle
        guard let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "PhosphorIcons"),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else {
            return nil
        }

        // Mark as template for tinting
        image.isTemplate = true

        // Cache the loaded image
        cacheLock.lock()
        iconCache[name] = image
        cacheLock.unlock()

        return image
    }

    /// Preload commonly used icons for better performance
    static func preloadCommonIcons() {
        let commonIcons = [
            "lightbulb", "power", "thermometer", "lock", "fan", "garage",
            "house", "gear", "star", "caret-right", "caret-down", "x"
        ]
        for name in commonIcons {
            _ = regular(name)
            _ = fill(name)
        }
    }
}

/// Token class to locate the macOSBridge bundle
private class BundleToken {}

// MARK: - Accessory type icon definitions

extension PhosphorIcon {

    /// Icon configuration for an accessory type
    struct AccessoryIconConfig {
        let defaultIcon: String
        let suggestedIcons: [String]
        /// Mode-specific icons (e.g., heat/cool/auto for AC, locked/unlocked for locks)
        let modeIcons: [String: String]

        init(defaultIcon: String, suggestedIcons: [String], modeIcons: [String: String] = [:]) {
            self.defaultIcon = defaultIcon
            self.suggestedIcons = suggestedIcons
            self.modeIcons = modeIcons
        }
    }

    /// Get mode icon name for a service type and mode
    static func modeIconName(for serviceType: String, mode: String) -> String? {
        accessoryIconConfigs[serviceType]?.modeIcons[mode]
    }

    /// Get mode icon for a service type and mode
    static func modeIcon(for serviceType: String, mode: String, filled: Bool = true) -> NSImage? {
        guard let iconName = modeIconName(for: serviceType, mode: mode) else { return nil }
        return icon(iconName, filled: filled)
    }

    /// Get the default icon for a service type
    static func defaultIcon(for serviceType: String) -> NSImage? {
        guard let config = accessoryIconConfigs[serviceType] else {
            return regular("question")
        }
        return regular(config.defaultIcon)
    }

    /// Get the default icon name for a service type
    static func defaultIconName(for serviceType: String) -> String {
        accessoryIconConfigs[serviceType]?.defaultIcon ?? "question"
    }

    /// Get suggested icons for a service type (for icon picker)
    static func suggestedIcons(for serviceType: String) -> [String] {
        accessoryIconConfigs[serviceType]?.suggestedIcons ?? []
    }

    /// Icon configurations for all accessory types
    static let accessoryIconConfigs: [String: AccessoryIconConfig] = [
        // Lights
        ServiceTypes.lightbulb: AccessoryIconConfig(
            defaultIcon: "lightbulb",
            suggestedIcons: ["lightbulb", "lightbulb-filament", "sun", "lamp", "lamp-pendant", "headlights"]
        ),

        // Switches & Outlets
        ServiceTypes.switch: AccessoryIconConfig(
            defaultIcon: "power",
            suggestedIcons: ["power", "toggle-left", "toggle-right", "plug", "plug-charging", "plugs"]
        ),
        ServiceTypes.outlet: AccessoryIconConfig(
            defaultIcon: "plug",
            suggestedIcons: ["plug", "plug-charging", "plugs", "power", "toggle-left", "toggle-right"]
        ),

        // Thermostats
        ServiceTypes.thermostat: AccessoryIconConfig(
            defaultIcon: "thermometer",
            suggestedIcons: ["thermometer", "thermometer-cold", "thermometer-hot", "thermometer-simple"],
            modeIcons: ["heat": "fire", "cool": "snowflake", "auto": "arrows-left-right"]
        ),

        // Heater/Cooler (AC)
        ServiceTypes.heaterCooler: AccessoryIconConfig(
            defaultIcon: "snowflake",
            suggestedIcons: ["snowflake", "thermometer", "fire", "fire-simple", "thermometer-cold", "thermometer-hot", "thermometer-simple"],
            modeIcons: ["heat": "fire", "cool": "snowflake", "auto": "arrows-left-right"]
        ),

        // Door Locks
        ServiceTypes.lock: AccessoryIconConfig(
            defaultIcon: "lock",
            suggestedIcons: ["lock", "lock-key", "lock-simple", "lock-laminated", "keyhole", "key"],
            modeIcons: ["locked": "lock", "unlocked": "lock-open"]
        ),

        // Fans
        ServiceTypes.fan: AccessoryIconConfig(
            defaultIcon: "fan",
            suggestedIcons: ["fan", "wind"]
        ),

        // Window Coverings / Blinds
        ServiceTypes.windowCovering: AccessoryIconConfig(
            defaultIcon: "caret-up-down",
            suggestedIcons: ["caret-up-down", "list"]
        ),

        // Garage Doors
        ServiceTypes.garageDoorOpener: AccessoryIconConfig(
            defaultIcon: "garage",
            suggestedIcons: ["garage", "car", "car-profile", "car-simple"],
            modeIcons: ["open": "garage", "closed": "garage", "obstructed": "warning"]
        ),

        // Humidifiers
        ServiceTypes.humidifierDehumidifier: AccessoryIconConfig(
            defaultIcon: "drop-half",
            suggestedIcons: ["drop-half", "drop", "drop-simple", "drop-half-bottom"],
            modeIcons: ["humidify": "drop-half", "dehumidify": "drop"]
        ),

        // Air Purifiers
        ServiceTypes.airPurifier: AccessoryIconConfig(
            defaultIcon: "wind",
            suggestedIcons: ["wind", "fan"]
        ),

        // Valves
        ServiceTypes.valve: AccessoryIconConfig(
            defaultIcon: "pipe",
            suggestedIcons: ["pipe", "shower", "drop"]
        ),

        // Security Systems
        ServiceTypes.securitySystem: AccessoryIconConfig(
            defaultIcon: "shield",
            suggestedIcons: ["shield", "shield-check", "shield-star", "key", "lock"],
            modeIcons: ["disarmed": "shield", "armed": "shield-check", "triggered": "shield-warning"]
        ),

        // Temperature Sensors
        ServiceTypes.temperatureSensor: AccessoryIconConfig(
            defaultIcon: "thermometer",
            suggestedIcons: ["thermometer", "thermometer-cold", "thermometer-hot", "thermometer-simple"]
        ),

        // Humidity Sensors
        ServiceTypes.humiditySensor: AccessoryIconConfig(
            defaultIcon: "drop-half",
            suggestedIcons: ["drop", "drop-simple", "drop-half", "drop-half-bottom"]
        )
    ]
}

// MARK: - Room icon mappings

extension PhosphorIcon {

    /// Get icon for a room based on its name
    static func iconForRoom(_ name: String) -> NSImage? {
        regular(iconNameForRoom(name))
    }

    /// Get icon name for a room based on its name
    static func iconNameForRoom(_ name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("living") {
            return "couch"
        } else if lowercased.contains("bedroom") || lowercased.contains("bed") {
            return "bed"
        } else if lowercased.contains("kitchen") {
            return "cooking-pot"
        } else if lowercased.contains("bath") {
            return "bathtub"
        } else if lowercased.contains("office") || lowercased.contains("study") {
            return "desktop"
        } else if lowercased.contains("garage") {
            return "garage"
        } else if lowercased.contains("garden") || lowercased.contains("outdoor") {
            return "tree"
        } else if lowercased.contains("dining") {
            return "fork-knife"
        } else if lowercased.contains("hall") || lowercased.contains("corridor") {
            return "door-open"
        } else if lowercased.contains("laundry") {
            return "washing-machine"
        } else if lowercased.contains("basement") || lowercased.contains("cellar") {
            return "stairs"
        } else if lowercased.contains("attic") {
            return "house-line"
        } else if lowercased.contains("balcony") || lowercased.contains("patio") || lowercased.contains("terrace") {
            return "sun-horizon"
        } else if lowercased.contains("pool") {
            return "swimming-pool"
        } else if lowercased.contains("gym") || lowercased.contains("fitness") {
            return "barbell"
        } else if lowercased.contains("nursery") || lowercased.contains("kid") || lowercased.contains("child") {
            return "baby"
        } else if lowercased.contains("guest") {
            return "user"
        } else {
            return "house"
        }
    }

    /// Suggested room icons for picker
    static let suggestedRoomIcons: [String] = [
        "house", "couch", "bed", "cooking-pot", "bathtub", "desktop",
        "garage", "tree", "fork-knife", "door-open", "washing-machine",
        "stairs", "house-line", "sun-horizon", "swimming-pool", "barbell",
        "baby", "user", "television", "game-controller"
    ]
}

// MARK: - Scene icons

extension PhosphorIcon {

    /// Infer a scene icon based on its name
    static func iconForScene(_ name: String) -> NSImage? {
        regular(iconNameForScene(name))
    }

    /// Infer a scene icon name based on its name
    static func iconNameForScene(_ name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("morning") || lowercased.contains("sunrise") || lowercased.contains("wake") {
            return "sun-horizon"
        } else if lowercased.contains("night") || lowercased.contains("sleep") || lowercased.contains("bedtime") {
            return "moon"
        } else if lowercased.contains("movie") || lowercased.contains("cinema") || lowercased.contains("theater") {
            return "film-strip"
        } else if lowercased.contains("party") || lowercased.contains("celebration") {
            return "confetti"
        } else if lowercased.contains("relax") || lowercased.contains("chill") || lowercased.contains("calm") {
            return "coffee"
        } else if lowercased.contains("work") || lowercased.contains("focus") || lowercased.contains("office") {
            return "briefcase"
        } else if lowercased.contains("dinner") || lowercased.contains("meal") || lowercased.contains("eat") {
            return "fork-knife"
        } else if lowercased.contains("away") || lowercased.contains("leave") || lowercased.contains("goodbye") || lowercased.contains("vacation") {
            return "airplane-takeoff"
        } else if lowercased.contains("home") || lowercased.contains("arrive") || lowercased.contains("welcome") {
            return "house"
        } else if lowercased.contains("bright") || lowercased.contains("full") {
            return "sun"
        } else if lowercased.contains("dim") || lowercased.contains("low") {
            return "moon-stars"
        } else if lowercased.contains("off") || lowercased.contains("all off") {
            return "power"
        } else if lowercased.contains("on") || lowercased.contains("all on") {
            return "lightbulb"
        } else if lowercased.contains("reading") {
            return "book-open"
        } else if lowercased.contains("romantic") || lowercased.contains("date") {
            return "heart"
        } else if lowercased.contains("gaming") || lowercased.contains("game") {
            return "game-controller"
        } else if lowercased.contains("music") || lowercased.contains("listen") {
            return "music-notes"
        } else {
            return "sparkle"
        }
    }

    /// Suggested scene icons for picker
    static let suggestedSceneIcons: [String] = [
        "sparkle", "sun-horizon", "moon", "sun", "moon-stars", "lightbulb",
        "power", "house", "airplane-takeoff", "film-strip", "confetti",
        "coffee", "briefcase", "fork-knife", "book-open", "heart",
        "game-controller", "music-notes", "television", "bed"
    ]
}

// MARK: - Group icons

extension PhosphorIcon {

    /// Default icon for groups
    static let defaultGroupIcon = "squares-four"

    /// Suggested group icons for picker
    static let suggestedGroupIcons: [String] = [
        "squares-four", "grid-four", "stack", "folder", "tag",
        "lightbulb", "lamp", "fan", "thermometer", "lock",
        "house", "couch", "bed", "sun", "moon"
    ]
}

// MARK: - Mode icons (for AC, thermostat, etc.)

extension PhosphorIcon {

    enum ACMode: Int {
        case auto = 0
        case heat = 1
        case cool = 2
    }

    static func iconForACMode(_ mode: ACMode) -> NSImage? {
        switch mode {
        case .auto:
            return regular("arrows-left-right")
        case .heat:
            return regular("fire")
        case .cool:
            return regular("snowflake")
        }
    }

    static func iconNameForACMode(_ mode: ACMode) -> String {
        switch mode {
        case .auto:
            return "arrows-left-right"
        case .heat:
            return "fire"
        case .cool:
            return "snowflake"
        }
    }
}

// MARK: - Lock state icons

extension PhosphorIcon {

    enum LockState: Int {
        case unlocked = 0
        case locked = 1
        case jammed = 2
        case unknown = 3
    }

    static func iconForLockState(_ state: LockState) -> NSImage? {
        switch state {
        case .locked:
            return fill("lock")
        case .unlocked:
            return regular("lock-open")
        case .jammed:
            return regular("warning")
        case .unknown:
            return regular("lock")
        }
    }
}

// MARK: - Garage door state icons

extension PhosphorIcon {

    enum GarageDoorState: Int {
        case open = 0
        case closed = 1
        case opening = 2
        case closing = 3
        case stopped = 4
    }

    static func iconForGarageDoorState(_ state: GarageDoorState) -> NSImage? {
        switch state {
        case .open, .opening, .stopped:
            return regular("garage")
        case .closed, .closing:
            return fill("garage")
        }
    }
}

// MARK: - Security system state icons

extension PhosphorIcon {

    enum SecurityState: Int {
        case stayArm = 0
        case awayArm = 1
        case nightArm = 2
        case disarmed = 3
        case triggered = 4
    }

    static func iconForSecurityState(_ state: SecurityState) -> NSImage? {
        switch state {
        case .stayArm:
            return fill("shield-check")
        case .awayArm:
            return fill("shield-check")
        case .nightArm:
            return regular("moon")
        case .disarmed:
            return regular("shield")
        case .triggered:
            return fill("shield-warning")
        }
    }

    static func iconNameForSecurityState(_ state: SecurityState) -> String {
        switch state {
        case .stayArm, .awayArm:
            return "shield-check"
        case .nightArm:
            return "moon"
        case .disarmed:
            return "shield"
        case .triggered:
            return "shield-warning"
        }
    }
}

// MARK: - UI icons (for buttons, settings, etc.)

extension PhosphorIcon {

    // Common UI icons used throughout the app
    static var star: NSImage? { regular("star") }
    static var starFill: NSImage? { fill("star") }
    static var eye: NSImage? { regular("eye") }
    static var eyeSlash: NSImage? { regular("eye-slash") }
    static var pin: NSImage? { regular("push-pin") }
    static var pinFill: NSImage? { fill("push-pin") }
    static var pencil: NSImage? { regular("pencil-simple") }
    static var trash: NSImage? { regular("trash") }
    static var plus: NSImage? { regular("plus") }
    static var minus: NSImage? { regular("minus") }
    static var gear: NSImage? { regular("gear") }
    static var chevronRight: NSImage? { regular("caret-right") }
    static var chevronDown: NSImage? { regular("caret-down") }
    static var chevronUp: NSImage? { regular("caret-up") }
    static var dragHandle: NSImage? { regular("dots-six-vertical") }
    static var close: NSImage? { regular("x") }
    static var check: NSImage? { regular("check") }
    static var warning: NSImage? { regular("warning") }
    static var info: NSImage? { regular("info") }
    static var question: NSImage? { regular("question") }
    static var refresh: NSImage? { regular("arrows-clockwise") }
    static var keyboard: NSImage? { regular("keyboard") }
    static var cloud: NSImage? { regular("cloud") }
    static var cloudCheck: NSImage? { regular("cloud-check") }
    static var bell: NSImage? { regular("bell") }
    static var bellRinging: NSImage? { regular("bell-ringing") }
    static var copy: NSImage? { regular("copy") }
    static var link: NSImage? { regular("link") }
    static var sparkle: NSImage? { regular("sparkle") }
}
