//
//  BridgeProtocols.swift
//  Itsyhome
//
//  Protocol bridge between iOS/Catalyst and macOS plugin
//

import Foundation
import CoreGraphics

// MARK: - Camera panel size bounds

/// Grid-mode size bounds for the camera panel, shared by the AppKit window
/// (min/max size + frame clamps) and the Catalyst scene's sizeRestrictions.
/// The two sides MUST stay identical: a setFrame outside the scene's
/// restrictions traps the Catalyst window.
public enum CameraPanelBounds {
    public static let minWidth: CGFloat = 300
    public static let minHeight: CGFloat = 200
    public static let maxWidth: CGFloat = 1600
    public static let maxHeight: CGFloat = 1400
}

// MARK: - Codable data transfer objects for JSON serialization

public struct HomeData: Codable {
    public let uniqueIdentifier: String
    public let name: String
    public let isPrimary: Bool
    
    public init(uniqueIdentifier: UUID, name: String, isPrimary: Bool) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
        self.isPrimary = isPrimary
    }
}

public struct RoomData: Codable {
    public let uniqueIdentifier: String
    public let name: String
    
    public init(uniqueIdentifier: UUID, name: String) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
    }
}

public struct ServiceData: Codable {
    public let uniqueIdentifier: String
    public var name: String
    public let serviceType: String
    public let accessoryName: String
    public let roomIdentifier: String?
    public let isReachable: Bool
    public let haEntityId: String?  // HA only: original entity_id (e.g. "light.living_room")

    // Characteristic UUIDs - each service type uses different ones
    public let powerStateId: String?           // Lights, switches, outlets
    public let outletInUseId: String?          // Outlets - read-only, true if drawing power
    public let brightnessId: String?           // Dimmable lights
    public let hueId: String?                  // RGB lights (0-360)
    public let saturationId: String?           // RGB lights (0-100)
    public let colorTemperatureId: String?     // Tunable white lights (Mired)
    public let colorTemperatureMin: Double?    // Min Mired value
    public let colorTemperatureMax: Double?    // Max Mired value
    public let currentTemperatureId: String?   // Thermostats, temperature sensors, AC
    public let targetTemperatureId: String?    // Thermostats
    public let heatingCoolingStateId: String?  // Thermostats (current mode)
    public let targetHeatingCoolingStateId: String? // Thermostats (target mode)
    public let validTargetHeatingCoolingStates: [Int]?  // Valid values for target state (e.g. [0, 1] = off + heat)
    public let availableHVACModes: [String]?  // HA only: available HVAC modes for dynamic UI
    public let lockCurrentStateId: String?     // Locks
    public let lockTargetStateId: String?      // Locks
    public let currentPositionId: String?      // Blinds/window coverings
    public let targetPositionId: String?       // Blinds/window coverings
    public let currentHorizontalTiltId: String?  // Blinds tilt (-90 to 90)
    public let targetHorizontalTiltId: String?   // Blinds tilt (-90 to 90)
    public let currentVerticalTiltId: String?    // Blinds tilt (-90 to 90)
    public let targetVerticalTiltId: String?     // Blinds tilt (-90 to 90)
    public let positionStateId: String?          // 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED
    public let humidityId: String?             // Humidity sensors
    public let motionDetectedId: String?       // Motion sensors
    // HeaterCooler (AC) characteristics
    public let activeId: String?               // AC/Fan on/off
    public let currentHeaterCoolerStateId: String?  // AC current state (inactive/idle/heating/cooling)
    public let targetHeaterCoolerStateId: String?   // AC target mode (auto/heat/cool)
    public let validTargetHeaterCoolerStates: [Int]?  // Valid values for target state (e.g. [1] = heat only)
    public let coolingThresholdTemperatureId: String?  // AC cooling target temp
    public let heatingThresholdTemperatureId: String?  // AC heating target temp
    // Fan characteristics
    public let rotationSpeedId: String?        // Fan speed
    public let rotationSpeedMin: Double?       // Min speed value
    public let rotationSpeedMax: Double?       // Max speed value
    public let targetFanStateId: String?       // 0=MANUAL, 1=AUTO
    public let currentFanStateId: String?      // 0=INACTIVE, 1=IDLE, 2=BLOWING_AIR (read-only)
    public let rotationDirectionId: String?    // 0=CLOCKWISE, 1=COUNTER_CLOCKWISE
    public let swingModeId: String?            // 0=DISABLED, 1=ENABLED
    public let availableSwingModes: [String]?  // HA only: available swing modes (e.g. ["off", "both", "vertical"])
    // Garage door characteristics
    public let currentDoorStateId: String?     // 0=open, 1=closed, 2=opening, 3=closing, 4=stopped
    public let targetDoorStateId: String?      // 0=open, 1=closed
    public let obstructionDetectedId: String?  // Bool
    // Contact sensor characteristics
    public let contactSensorStateId: String?   // 0=detected (closed), 1=not detected (open)
    // Safety / occupancy sensor characteristics (0=clear, 1=detected)
    public let occupancyDetectedId: String?    // Occupancy sensors
    public let leakDetectedId: String?         // Leak sensors
    public let smokeDetectedId: String?        // Smoke sensors
    public let carbonMonoxideDetectedId: String?  // Carbon monoxide sensors
    public let carbonDioxideDetectedId: String?   // Carbon dioxide sensors
    // Generic Home Assistant sensor (read-only, no HomeKit equivalent)
    public let sensorReadingId: String?           // numeric value, or 0/1 for generic binary
    public let sensorUnit: String?                // unit_of_measurement (numeric sensors)
    public let sensorDeviceClass: String?         // HA device_class, for icon and label
    // Battery (sibling battery service on HomeKit; same-device battery sensor on HA)
    public let batteryLevelId: String?            // 0–100 percentage
    public let statusLowBatteryId: String?        // 1 = low
    // Humidifier/Dehumidifier characteristics
    public let currentHumidifierDehumidifierStateId: String?
    public let targetHumidifierDehumidifierStateId: String?
    public let humidifierThresholdId: String?
    public let dehumidifierThresholdId: String?
    public let waterLevelId: String?              // 0-100 percentage (read-only)
    // Air Purifier characteristics
    public let currentAirPurifierStateId: String?
    public let targetAirPurifierStateId: String?
    // Valve characteristics
    public let inUseId: String?
    public let valveTypeValue: Int?  // Store actual value, not characteristic ID
    public let setDurationId: String?
    public let remainingDurationId: String?
    public let valveStateId: String?           // HA only: raw state string (open/closed/opening/closing)
    // Security System characteristics
    public let securitySystemCurrentStateId: String?
    public let securitySystemTargetStateId: String?
    public let alarmSupportedModes: [String]?  // HA only: available alarm modes
    public let alarmRequiresCode: Bool?        // HA only: whether code is required
    // HA Humidifier characteristics
    public let humidifierAvailableModes: [String]?  // HA only: available modes like ["home", "eco"]
    // Slat characteristics
    public let currentTiltAngleId: String?      // Slat tilt (-90 to 90)
    public let targetTiltAngleId: String?       // Slat tilt (-90 to 90)
    public let slatTypeValue: Int?              // 0=HORIZONTAL, 1=VERTICAL
    public let currentSlatStateId: String?      // 0=FIXED, 1=JAMMED, 2=SWINGING

    public init(
        uniqueIdentifier: UUID,
        name: String,
        serviceType: String,
        accessoryName: String,
        roomIdentifier: UUID?,
        isReachable: Bool = true,
        haEntityId: String? = nil,
        powerStateId: UUID? = nil,
        outletInUseId: UUID? = nil,
        brightnessId: UUID? = nil,
        hueId: UUID? = nil,
        saturationId: UUID? = nil,
        colorTemperatureId: UUID? = nil,
        colorTemperatureMin: Double? = nil,
        colorTemperatureMax: Double? = nil,
        currentTemperatureId: UUID? = nil,
        targetTemperatureId: UUID? = nil,
        heatingCoolingStateId: UUID? = nil,
        targetHeatingCoolingStateId: UUID? = nil,
        validTargetHeatingCoolingStates: [Int]? = nil,
        availableHVACModes: [String]? = nil,
        lockCurrentStateId: UUID? = nil,
        lockTargetStateId: UUID? = nil,
        currentPositionId: UUID? = nil,
        targetPositionId: UUID? = nil,
        currentHorizontalTiltId: UUID? = nil,
        targetHorizontalTiltId: UUID? = nil,
        currentVerticalTiltId: UUID? = nil,
        targetVerticalTiltId: UUID? = nil,
        positionStateId: UUID? = nil,
        humidityId: UUID? = nil,
        motionDetectedId: UUID? = nil,
        activeId: UUID? = nil,
        currentHeaterCoolerStateId: UUID? = nil,
        targetHeaterCoolerStateId: UUID? = nil,
        validTargetHeaterCoolerStates: [Int]? = nil,
        coolingThresholdTemperatureId: UUID? = nil,
        heatingThresholdTemperatureId: UUID? = nil,
        rotationSpeedId: UUID? = nil,
        rotationSpeedMin: Double? = nil,
        rotationSpeedMax: Double? = nil,
        targetFanStateId: UUID? = nil,
        currentFanStateId: UUID? = nil,
        rotationDirectionId: UUID? = nil,
        swingModeId: UUID? = nil,
        availableSwingModes: [String]? = nil,
        currentDoorStateId: UUID? = nil,
        targetDoorStateId: UUID? = nil,
        obstructionDetectedId: UUID? = nil,
        contactSensorStateId: UUID? = nil,
        // Safety / occupancy sensors
        occupancyDetectedId: UUID? = nil,
        leakDetectedId: UUID? = nil,
        smokeDetectedId: UUID? = nil,
        carbonMonoxideDetectedId: UUID? = nil,
        carbonDioxideDetectedId: UUID? = nil,
        // Generic Home Assistant sensor
        sensorReadingId: UUID? = nil,
        sensorUnit: String? = nil,
        sensorDeviceClass: String? = nil,
        // Battery
        batteryLevelId: UUID? = nil,
        statusLowBatteryId: UUID? = nil,
        // Humidifier/Dehumidifier
        currentHumidifierDehumidifierStateId: UUID? = nil,
        targetHumidifierDehumidifierStateId: UUID? = nil,
        humidifierThresholdId: UUID? = nil,
        dehumidifierThresholdId: UUID? = nil,
        waterLevelId: UUID? = nil,
        // Air Purifier
        currentAirPurifierStateId: UUID? = nil,
        targetAirPurifierStateId: UUID? = nil,
        // Valve
        inUseId: UUID? = nil,
        valveTypeValue: Int? = nil,
        setDurationId: UUID? = nil,
        remainingDurationId: UUID? = nil,
        valveStateId: UUID? = nil,
        // Security System
        securitySystemCurrentStateId: UUID? = nil,
        securitySystemTargetStateId: UUID? = nil,
        alarmSupportedModes: [String]? = nil,
        alarmRequiresCode: Bool? = nil,
        // HA Humidifier
        humidifierAvailableModes: [String]? = nil,
        // Slat
        currentTiltAngleId: UUID? = nil,
        targetTiltAngleId: UUID? = nil,
        slatTypeValue: Int? = nil,
        currentSlatStateId: UUID? = nil
    ) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
        self.serviceType = serviceType
        self.accessoryName = accessoryName
        self.roomIdentifier = roomIdentifier?.uuidString
        self.isReachable = isReachable
        self.haEntityId = haEntityId
        self.powerStateId = powerStateId?.uuidString
        self.outletInUseId = outletInUseId?.uuidString
        self.brightnessId = brightnessId?.uuidString
        self.hueId = hueId?.uuidString
        self.saturationId = saturationId?.uuidString
        self.colorTemperatureId = colorTemperatureId?.uuidString
        self.colorTemperatureMin = colorTemperatureMin
        self.colorTemperatureMax = colorTemperatureMax
        self.currentTemperatureId = currentTemperatureId?.uuidString
        self.targetTemperatureId = targetTemperatureId?.uuidString
        self.heatingCoolingStateId = heatingCoolingStateId?.uuidString
        self.targetHeatingCoolingStateId = targetHeatingCoolingStateId?.uuidString
        self.validTargetHeatingCoolingStates = validTargetHeatingCoolingStates
        self.availableHVACModes = availableHVACModes
        self.lockCurrentStateId = lockCurrentStateId?.uuidString
        self.lockTargetStateId = lockTargetStateId?.uuidString
        self.currentPositionId = currentPositionId?.uuidString
        self.targetPositionId = targetPositionId?.uuidString
        self.currentHorizontalTiltId = currentHorizontalTiltId?.uuidString
        self.targetHorizontalTiltId = targetHorizontalTiltId?.uuidString
        self.currentVerticalTiltId = currentVerticalTiltId?.uuidString
        self.targetVerticalTiltId = targetVerticalTiltId?.uuidString
        self.positionStateId = positionStateId?.uuidString
        self.humidityId = humidityId?.uuidString
        self.motionDetectedId = motionDetectedId?.uuidString
        self.activeId = activeId?.uuidString
        self.currentHeaterCoolerStateId = currentHeaterCoolerStateId?.uuidString
        self.targetHeaterCoolerStateId = targetHeaterCoolerStateId?.uuidString
        self.validTargetHeaterCoolerStates = validTargetHeaterCoolerStates
        self.coolingThresholdTemperatureId = coolingThresholdTemperatureId?.uuidString
        self.heatingThresholdTemperatureId = heatingThresholdTemperatureId?.uuidString
        self.rotationSpeedId = rotationSpeedId?.uuidString
        self.rotationSpeedMin = rotationSpeedMin
        self.rotationSpeedMax = rotationSpeedMax
        self.targetFanStateId = targetFanStateId?.uuidString
        self.currentFanStateId = currentFanStateId?.uuidString
        self.rotationDirectionId = rotationDirectionId?.uuidString
        self.swingModeId = swingModeId?.uuidString
        self.availableSwingModes = availableSwingModes
        self.currentDoorStateId = currentDoorStateId?.uuidString
        self.targetDoorStateId = targetDoorStateId?.uuidString
        self.obstructionDetectedId = obstructionDetectedId?.uuidString
        self.contactSensorStateId = contactSensorStateId?.uuidString
        // Safety / occupancy sensors
        self.occupancyDetectedId = occupancyDetectedId?.uuidString
        self.leakDetectedId = leakDetectedId?.uuidString
        self.smokeDetectedId = smokeDetectedId?.uuidString
        self.carbonMonoxideDetectedId = carbonMonoxideDetectedId?.uuidString
        self.carbonDioxideDetectedId = carbonDioxideDetectedId?.uuidString
        // Generic Home Assistant sensor
        self.sensorReadingId = sensorReadingId?.uuidString
        self.sensorUnit = sensorUnit
        self.sensorDeviceClass = sensorDeviceClass
        // Battery
        self.batteryLevelId = batteryLevelId?.uuidString
        self.statusLowBatteryId = statusLowBatteryId?.uuidString
        // Humidifier/Dehumidifier
        self.currentHumidifierDehumidifierStateId = currentHumidifierDehumidifierStateId?.uuidString
        self.targetHumidifierDehumidifierStateId = targetHumidifierDehumidifierStateId?.uuidString
        self.humidifierThresholdId = humidifierThresholdId?.uuidString
        self.dehumidifierThresholdId = dehumidifierThresholdId?.uuidString
        self.waterLevelId = waterLevelId?.uuidString
        // Air Purifier
        self.currentAirPurifierStateId = currentAirPurifierStateId?.uuidString
        self.targetAirPurifierStateId = targetAirPurifierStateId?.uuidString
        // Valve
        self.inUseId = inUseId?.uuidString
        self.valveTypeValue = valveTypeValue
        self.setDurationId = setDurationId?.uuidString
        self.remainingDurationId = remainingDurationId?.uuidString
        self.valveStateId = valveStateId?.uuidString
        // Security System
        self.securitySystemCurrentStateId = securitySystemCurrentStateId?.uuidString
        self.securitySystemTargetStateId = securitySystemTargetStateId?.uuidString
        self.alarmSupportedModes = alarmSupportedModes
        self.alarmRequiresCode = alarmRequiresCode
        // HA Humidifier
        self.humidifierAvailableModes = humidifierAvailableModes
        // Slat
        self.currentTiltAngleId = currentTiltAngleId?.uuidString
        self.targetTiltAngleId = targetTiltAngleId?.uuidString
        self.slatTypeValue = slatTypeValue
        self.currentSlatStateId = currentSlatStateId?.uuidString
    }

    func strippingRoomName(_ roomName: String) -> ServiceData {
        var copy = self
        let trimmed = copy.name.trimmingCharacters(in: .whitespaces)
        let roomPrefix = roomName.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix(roomPrefix.lowercased()) {
            let afterPrefix = trimmed.dropFirst(roomPrefix.count)
            // Only strip when room name is followed by a space (word boundary)
            guard afterPrefix.first == " " else { return copy }
            let remainder = afterPrefix.trimmingCharacters(in: .whitespaces)
            if !remainder.isEmpty {
                copy.name = remainder
            }
        }
        return copy
    }
}

public struct SceneActionData: Codable {
    public let characteristicId: String
    public let characteristicType: String  // e.g., powerState, brightness, targetPosition
    public let targetValue: Double  // Normalized to Double for comparison

    public init(characteristicId: UUID, characteristicType: String, targetValue: Double) {
        self.characteristicId = characteristicId.uuidString
        self.characteristicType = characteristicType
        self.targetValue = targetValue
    }
}

public struct SceneData: Codable {
    public let uniqueIdentifier: String
    public let name: String
    public let actions: [SceneActionData]

    public init(uniqueIdentifier: UUID, name: String, actions: [SceneActionData] = []) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
        self.actions = actions
    }
}

public struct AccessoryData: Codable {
    public let uniqueIdentifier: String
    public let name: String
    public let roomIdentifier: String?
    public let services: [ServiceData]
    public let isReachable: Bool

    public init(uniqueIdentifier: UUID, name: String, roomIdentifier: UUID?, services: [ServiceData], isReachable: Bool) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
        self.roomIdentifier = roomIdentifier?.uuidString
        self.services = services
        self.isReachable = isReachable
    }

    /// String-based initializer for when data is already serialized (avoids String→UUID→String roundtrip)
    public init(uniqueIdentifier: String, name: String, roomIdentifier: String?, services: [ServiceData], isReachable: Bool) {
        self.uniqueIdentifier = uniqueIdentifier
        self.name = name
        self.roomIdentifier = roomIdentifier
        self.services = services
        self.isReachable = isReachable
    }
}

public struct CameraData: Codable {
    public let uniqueIdentifier: String
    public let name: String
    public let entityId: String?  // HA only: e.g. "camera.front_door"
    public let hasMotionSensor: Bool

    public init(uniqueIdentifier: UUID, name: String, entityId: String? = nil, hasMotionSensor: Bool = false) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
        self.entityId = entityId
        self.hasMotionSensor = hasMotionSensor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uniqueIdentifier = try container.decode(String.self, forKey: .uniqueIdentifier)
        name = try container.decode(String.self, forKey: .name)
        entityId = try container.decodeIfPresent(String.self, forKey: .entityId)
        hasMotionSensor = try container.decodeIfPresent(Bool.self, forKey: .hasMotionSensor) ?? false
    }
}

public struct MenuData: Codable {
    public let homes: [HomeData]
    public let rooms: [RoomData]
    public let accessories: [AccessoryData]
    public let scenes: [SceneData]
    public let selectedHomeId: String?
    public let hasCameras: Bool
    public let cameras: [CameraData]

    public init(homes: [HomeData], rooms: [RoomData], accessories: [AccessoryData], scenes: [SceneData], selectedHomeId: UUID?, hasCameras: Bool = false, cameras: [CameraData] = []) {
        self.homes = homes
        self.rooms = rooms
        self.accessories = accessories
        self.scenes = scenes
        self.selectedHomeId = selectedHomeId?.uuidString
        self.hasCameras = hasCameras
        self.cameras = cameras
    }

    /// Creates a lookup dictionary mapping room unique identifiers to room names
    public func roomLookup() -> [String: String] {
        Dictionary(uniqueKeysWithValues: rooms.map { ($0.uniqueIdentifier, $0.name) })
    }
}

// MARK: - Legacy Obj-C classes (for protocol compatibility)

@objc public class HomeInfo: NSObject {
    @objc public let uniqueIdentifier: UUID
    @objc public let name: String
    @objc public let isPrimary: Bool
    
    @objc public init(uniqueIdentifier: UUID, name: String, isPrimary: Bool) {
        self.uniqueIdentifier = uniqueIdentifier
        self.name = name
        self.isPrimary = isPrimary
    }
}

@objc public class RoomInfo: NSObject {
    @objc public let uniqueIdentifier: UUID
    @objc public let name: String
    
    @objc public init(uniqueIdentifier: UUID, name: String) {
        self.uniqueIdentifier = uniqueIdentifier
        self.name = name
    }
}

@objc public class ServiceInfo: NSObject {
    @objc public let uniqueIdentifier: UUID
    @objc public let name: String
    @objc public let serviceType: String
    @objc public let accessoryName: String
    @objc public let roomIdentifier: UUID?
    
    @objc public init(uniqueIdentifier: UUID, name: String, serviceType: String, accessoryName: String, roomIdentifier: UUID?) {
        self.uniqueIdentifier = uniqueIdentifier
        self.name = name
        self.serviceType = serviceType
        self.accessoryName = accessoryName
        self.roomIdentifier = roomIdentifier
    }
}

@objc public class SceneInfo: NSObject {
    @objc public let uniqueIdentifier: UUID
    @objc public let name: String
    
    @objc public init(uniqueIdentifier: UUID, name: String) {
        self.uniqueIdentifier = uniqueIdentifier
        self.name = name
    }
}

@objc public class AccessoryInfo: NSObject {
    @objc public let uniqueIdentifier: UUID
    @objc public let name: String
    @objc public let roomIdentifier: UUID?
    @objc public let services: [ServiceInfo]
    @objc public let isReachable: Bool
    
    @objc public init(uniqueIdentifier: UUID, name: String, roomIdentifier: UUID?, services: [ServiceInfo], isReachable: Bool) {
        self.uniqueIdentifier = uniqueIdentifier
        self.name = name
        self.roomIdentifier = roomIdentifier
        self.services = services
        self.isReachable = isReachable
    }
}

// MARK: - Bridge protocols

/// Protocol for macOS plugin to call iOS/HomeKit code
@objc(Mac2iOS)
public protocol Mac2iOS: NSObjectProtocol {
    var homes: [HomeInfo] { get }
    var selectedHomeIdentifier: UUID? { get set }
    var rooms: [RoomInfo] { get }
    var accessories: [AccessoryInfo] { get }
    var scenes: [SceneInfo] { get }

    func reloadHomeKit()
    func executeScene(identifier: UUID)
    func readCharacteristic(identifier: UUID)
    func writeCharacteristic(identifier: UUID, value: Any)
    func getCharacteristicValue(identifier: UUID) -> Any?
    func openCameraWindow()
    func closeCameraWindow()
    func setCameraWindowHidden(_ hidden: Bool)
    func getRawHomeKitDump() -> String?
    func getCameraDebugJSON(entityId: String?, completion: @escaping (String?) -> Void)
}

/// Protocol for iOS code to call macOS plugin
@objc(iOS2Mac)
public protocol iOS2Mac: NSObjectProtocol {
    init()
    var iOSBridge: Mac2iOS? { get set }

    func reloadMenuWithJSON(_ jsonString: String)
    func updateCharacteristic(identifier: UUID, value: Any)
    func setReachability(accessoryIdentifier: UUID, isReachable: Bool)
    func showError(message: String)
    func executeCommand(_ command: String) -> Bool
    func configureCameraPanel()
    func resizeCameraPanel(width: CGFloat, height: CGFloat, aspectRatio: CGFloat, isStream: Bool, animated: Bool)
    func setCameraPanelPinned(_ pinned: Bool)
    func showCameraPanelForDoorbell(cameraIdentifier: UUID)
    func showCameraPanelForMotion(cameraIdentifier: UUID)
    func notifyStreamStarted(cameraIdentifier: UUID)
    func dismissCameraPanel()
}

// MARK: - Service type constants

@objc public class ServiceTypes: NSObject {
    @objc public static let lightbulb = "00000043-0000-1000-8000-0026BB765291"
    @objc public static let `switch` = "00000049-0000-1000-8000-0026BB765291"
    @objc public static let outlet = "00000047-0000-1000-8000-0026BB765291"
    @objc public static let thermostat = "0000004A-0000-1000-8000-0026BB765291"
    @objc public static let heaterCooler = "000000BC-0000-1000-8000-0026BB765291"
    @objc public static let lock = "00000045-0000-1000-8000-0026BB765291"
    @objc public static let windowCovering = "0000008C-0000-1000-8000-0026BB765291"
    @objc public static let door = "00000081-0000-1000-8000-0026BB765291"
    @objc public static let window = "0000008B-0000-1000-8000-0026BB765291"
    @objc public static let temperatureSensor = "0000008A-0000-1000-8000-0026BB765291"
    @objc public static let humiditySensor = "00000082-0000-1000-8000-0026BB765291"
    @objc public static let motionSensor = "00000085-0000-1000-8000-0026BB765291"
    @objc public static let fan = "00000040-0000-1000-8000-0026BB765291"
    @objc public static let fanV2 = "000000B7-0000-1000-8000-0026BB765291"
    @objc public static let garageDoorOpener = "00000041-0000-1000-8000-0026BB765291"
    @objc public static let contactSensor = "00000080-0000-1000-8000-0026BB765291"
    @objc public static let occupancySensor = "00000086-0000-1000-8000-0026BB765291"
    @objc public static let leakSensor = "00000083-0000-1000-8000-0026BB765291"
    @objc public static let smokeSensor = "00000087-0000-1000-8000-0026BB765291"
    @objc public static let carbonMonoxideSensor = "0000007F-0000-1000-8000-0026BB765291"
    @objc public static let carbonDioxideSensor = "00000097-0000-1000-8000-0026BB765291"
    // Generic read-only Home Assistant sensors (no HomeKit equivalent). Not HAP
    // UUIDs – HA exposes arbitrary numeric (CO2 ppm, power, lux, ...) and binary
    // (gas, vibration, sound, ...) sensors that don't map to a fixed HK type.
    @objc public static let sensor = "ha.sensor.numeric"
    @objc public static let binarySensor = "ha.sensor.binary"
    @objc public static let humidifierDehumidifier = "000000BD-0000-1000-8000-0026BB765291"
    @objc public static let airPurifier = "000000BB-0000-1000-8000-0026BB765291"
    @objc public static let valve = "000000D0-0000-1000-8000-0026BB765291"
    @objc public static let faucet = "000000D7-0000-1000-8000-0026BB765291"
    @objc public static let slat = "000000B9-0000-1000-8000-0026BB765291"
    @objc public static let securitySystem = "0000007E-0000-1000-8000-0026BB765291"
}

// MARK: - Characteristic type constants

@objc public class CharacteristicTypes: NSObject {
    @objc public static let powerState = "00000025-0000-1000-8000-0026BB765291"
    @objc public static let outletInUse = "00000026-0000-1000-8000-0026BB765291"
    @objc public static let brightness = "00000008-0000-1000-8000-0026BB765291"
    @objc public static let hue = "00000013-0000-1000-8000-0026BB765291"
    @objc public static let saturation = "0000002F-0000-1000-8000-0026BB765291"
    @objc public static let colorTemperature = "000000CE-0000-1000-8000-0026BB765291"
    @objc public static let currentTemperature = "00000011-0000-1000-8000-0026BB765291"
    @objc public static let targetTemperature = "00000035-0000-1000-8000-0026BB765291"
    @objc public static let heatingCoolingState = "0000000F-0000-1000-8000-0026BB765291"
    @objc public static let targetHeatingCoolingState = "00000033-0000-1000-8000-0026BB765291"
    @objc public static let lockCurrentState = "0000001D-0000-1000-8000-0026BB765291"
    @objc public static let lockTargetState = "0000001E-0000-1000-8000-0026BB765291"
    @objc public static let currentPosition = "0000006D-0000-1000-8000-0026BB765291"
    @objc public static let targetPosition = "0000007C-0000-1000-8000-0026BB765291"
    @objc public static let currentHorizontalTiltAngle = "0000006C-0000-1000-8000-0026BB765291"
    @objc public static let targetHorizontalTiltAngle = "0000007B-0000-1000-8000-0026BB765291"
    @objc public static let currentVerticalTiltAngle = "0000006E-0000-1000-8000-0026BB765291"
    @objc public static let targetVerticalTiltAngle = "0000007D-0000-1000-8000-0026BB765291"
    @objc public static let positionState = "00000072-0000-1000-8000-0026BB765291"
    @objc public static let currentRelativeHumidity = "00000010-0000-1000-8000-0026BB765291"
    @objc public static let motionDetected = "00000022-0000-1000-8000-0026BB765291"
    // HeaterCooler (AC) characteristics
    @objc public static let active = "000000B0-0000-1000-8000-0026BB765291"
    @objc public static let currentHeaterCoolerState = "000000B1-0000-1000-8000-0026BB765291"
    @objc public static let targetHeaterCoolerState = "000000B2-0000-1000-8000-0026BB765291"
    @objc public static let coolingThresholdTemperature = "0000000D-0000-1000-8000-0026BB765291"
    @objc public static let heatingThresholdTemperature = "00000012-0000-1000-8000-0026BB765291"
    // Fan characteristics
    @objc public static let rotationSpeed = "00000029-0000-1000-8000-0026BB765291"
    @objc public static let rotationDirection = "00000028-0000-1000-8000-0026BB765291"
    @objc public static let targetFanState = "000000BF-0000-1000-8000-0026BB765291"
    @objc public static let currentFanState = "000000AF-0000-1000-8000-0026BB765291"
    @objc public static let swingMode = "000000B6-0000-1000-8000-0026BB765291"
    // Garage door characteristics
    @objc public static let currentDoorState = "0000000E-0000-1000-8000-0026BB765291"
    @objc public static let targetDoorState = "00000032-0000-1000-8000-0026BB765291"
    @objc public static let obstructionDetected = "00000024-0000-1000-8000-0026BB765291"
    // Contact sensor characteristics
    @objc public static let contactSensorState = "0000006A-0000-1000-8000-0026BB765291"
    // Safety / occupancy sensor characteristics
    @objc public static let occupancyDetected = "00000071-0000-1000-8000-0026BB765291"
    @objc public static let leakDetected = "00000070-0000-1000-8000-0026BB765291"
    @objc public static let smokeDetected = "00000076-0000-1000-8000-0026BB765291"
    @objc public static let carbonMonoxideDetected = "00000069-0000-1000-8000-0026BB765291"
    @objc public static let carbonDioxideDetected = "00000092-0000-1000-8000-0026BB765291"
    // Humidifier/Dehumidifier characteristics
    @objc public static let currentHumidifierDehumidifierState = "000000B3-0000-1000-8000-0026BB765291"
    @objc public static let targetHumidifierDehumidifierState = "000000B4-0000-1000-8000-0026BB765291"
    @objc public static let humidifierThreshold = "000000CA-0000-1000-8000-0026BB765291"
    @objc public static let dehumidifierThreshold = "000000C9-0000-1000-8000-0026BB765291"
    @objc public static let waterLevel = "000000B5-0000-1000-8000-0026BB765291"
    // Air Purifier characteristics
    @objc public static let currentAirPurifierState = "000000A9-0000-1000-8000-0026BB765291"
    @objc public static let targetAirPurifierState = "000000A8-0000-1000-8000-0026BB765291"
    // Valve characteristics
    @objc public static let inUse = "000000D2-0000-1000-8000-0026BB765291"
    @objc public static let valveType = "000000D5-0000-1000-8000-0026BB765291"
    @objc public static let setDuration = "000000D3-0000-1000-8000-0026BB765291"
    @objc public static let remainingDuration = "000000D4-0000-1000-8000-0026BB765291"
    // Security System characteristics
    @objc public static let securitySystemCurrentState = "00000066-0000-1000-8000-0026BB765291"
    @objc public static let securitySystemTargetState = "00000067-0000-1000-8000-0026BB765291"
    // Slat characteristics
    @objc public static let currentTiltAngle = "000000C1-0000-1000-8000-0026BB765291"
    @objc public static let targetTiltAngle = "000000C2-0000-1000-8000-0026BB765291"
    @objc public static let slatType = "000000C0-0000-1000-8000-0026BB765291"
    @objc public static let currentSlatState = "000000AA-0000-1000-8000-0026BB765291"
}

// MARK: - Camera window notifications (HA: macOSBridge → Catalyst bridge)

public extension Notification.Name {
    static let requestOpenCameraWindow = Notification.Name("com.itsyhome.requestOpenCameraWindow")
    static let requestCloseCameraWindow = Notification.Name("com.itsyhome.requestCloseCameraWindow")
    static let requestSetCameraWindowHidden = Notification.Name("com.itsyhome.requestSetCameraWindowHidden")
    static let autoOpenCamera = Notification.Name("com.itsyhome.autoOpenCamera")
}

// MARK: - String UUID conversion

public extension String {
    /// Converts string to UUID if valid UUID format
    var uuid: UUID? { UUID(uuidString: self) }
}
