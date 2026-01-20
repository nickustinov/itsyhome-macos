//
//  BridgeProtocols.swift
//  HomeBar
//
//  Protocol bridge between iOS/Catalyst and macOS plugin
//

import Foundation

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
    public let name: String
    public let serviceType: String
    public let accessoryName: String
    public let roomIdentifier: String?

    // Characteristic UUIDs - each service type uses different ones
    public let powerStateId: String?           // Lights, switches, outlets
    public let brightnessId: String?           // Dimmable lights
    public let currentTemperatureId: String?   // Thermostats, temperature sensors, AC
    public let targetTemperatureId: String?    // Thermostats
    public let heatingCoolingStateId: String?  // Thermostats (current mode)
    public let targetHeatingCoolingStateId: String? // Thermostats (target mode)
    public let lockCurrentStateId: String?     // Locks
    public let lockTargetStateId: String?      // Locks
    public let currentPositionId: String?      // Blinds/window coverings
    public let targetPositionId: String?       // Blinds/window coverings
    public let humidityId: String?             // Humidity sensors
    public let motionDetectedId: String?       // Motion sensors
    // HeaterCooler (AC) characteristics
    public let activeId: String?               // AC on/off
    public let currentHeaterCoolerStateId: String?  // AC current state (inactive/idle/heating/cooling)
    public let targetHeaterCoolerStateId: String?   // AC target mode (auto/heat/cool)
    public let coolingThresholdTemperatureId: String?  // AC cooling target temp
    public let heatingThresholdTemperatureId: String?  // AC heating target temp

    public init(
        uniqueIdentifier: UUID,
        name: String,
        serviceType: String,
        accessoryName: String,
        roomIdentifier: UUID?,
        powerStateId: UUID? = nil,
        brightnessId: UUID? = nil,
        currentTemperatureId: UUID? = nil,
        targetTemperatureId: UUID? = nil,
        heatingCoolingStateId: UUID? = nil,
        targetHeatingCoolingStateId: UUID? = nil,
        lockCurrentStateId: UUID? = nil,
        lockTargetStateId: UUID? = nil,
        currentPositionId: UUID? = nil,
        targetPositionId: UUID? = nil,
        humidityId: UUID? = nil,
        motionDetectedId: UUID? = nil,
        activeId: UUID? = nil,
        currentHeaterCoolerStateId: UUID? = nil,
        targetHeaterCoolerStateId: UUID? = nil,
        coolingThresholdTemperatureId: UUID? = nil,
        heatingThresholdTemperatureId: UUID? = nil
    ) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
        self.serviceType = serviceType
        self.accessoryName = accessoryName
        self.roomIdentifier = roomIdentifier?.uuidString
        self.powerStateId = powerStateId?.uuidString
        self.brightnessId = brightnessId?.uuidString
        self.currentTemperatureId = currentTemperatureId?.uuidString
        self.targetTemperatureId = targetTemperatureId?.uuidString
        self.heatingCoolingStateId = heatingCoolingStateId?.uuidString
        self.targetHeatingCoolingStateId = targetHeatingCoolingStateId?.uuidString
        self.lockCurrentStateId = lockCurrentStateId?.uuidString
        self.lockTargetStateId = lockTargetStateId?.uuidString
        self.currentPositionId = currentPositionId?.uuidString
        self.targetPositionId = targetPositionId?.uuidString
        self.humidityId = humidityId?.uuidString
        self.motionDetectedId = motionDetectedId?.uuidString
        self.activeId = activeId?.uuidString
        self.currentHeaterCoolerStateId = currentHeaterCoolerStateId?.uuidString
        self.targetHeaterCoolerStateId = targetHeaterCoolerStateId?.uuidString
        self.coolingThresholdTemperatureId = coolingThresholdTemperatureId?.uuidString
        self.heatingThresholdTemperatureId = heatingThresholdTemperatureId?.uuidString
    }
}

public struct SceneData: Codable {
    public let uniqueIdentifier: String
    public let name: String
    
    public init(uniqueIdentifier: UUID, name: String) {
        self.uniqueIdentifier = uniqueIdentifier.uuidString
        self.name = name
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
}

public struct MenuData: Codable {
    public let homes: [HomeData]
    public let rooms: [RoomData]
    public let accessories: [AccessoryData]
    public let scenes: [SceneData]
    public let selectedHomeId: String?
    
    public init(homes: [HomeData], rooms: [RoomData], accessories: [AccessoryData], scenes: [SceneData], selectedHomeId: UUID?) {
        self.homes = homes
        self.rooms = rooms
        self.accessories = accessories
        self.scenes = scenes
        self.selectedHomeId = selectedHomeId?.uuidString
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
    @objc public static let temperatureSensor = "0000008A-0000-1000-8000-0026BB765291"
    @objc public static let humiditySensor = "00000082-0000-1000-8000-0026BB765291"
    @objc public static let motionSensor = "00000085-0000-1000-8000-0026BB765291"
}

// MARK: - Characteristic type constants

@objc public class CharacteristicTypes: NSObject {
    @objc public static let powerState = "00000025-0000-1000-8000-0026BB765291"
    @objc public static let brightness = "00000008-0000-1000-8000-0026BB765291"
    @objc public static let hue = "00000013-0000-1000-8000-0026BB765291"
    @objc public static let saturation = "0000002F-0000-1000-8000-0026BB765291"
    @objc public static let currentTemperature = "00000011-0000-1000-8000-0026BB765291"
    @objc public static let targetTemperature = "00000035-0000-1000-8000-0026BB765291"
    @objc public static let heatingCoolingState = "0000000F-0000-1000-8000-0026BB765291"
    @objc public static let targetHeatingCoolingState = "00000033-0000-1000-8000-0026BB765291"
    @objc public static let lockCurrentState = "0000001D-0000-1000-8000-0026BB765291"
    @objc public static let lockTargetState = "0000001E-0000-1000-8000-0026BB765291"
    @objc public static let currentPosition = "0000006D-0000-1000-8000-0026BB765291"
    @objc public static let targetPosition = "0000007C-0000-1000-8000-0026BB765291"
    @objc public static let currentRelativeHumidity = "00000010-0000-1000-8000-0026BB765291"
    @objc public static let motionDetected = "00000022-0000-1000-8000-0026BB765291"
    // HeaterCooler (AC) characteristics
    @objc public static let active = "000000B0-0000-1000-8000-0026BB765291"
    @objc public static let currentHeaterCoolerState = "000000B1-0000-1000-8000-0026BB765291"
    @objc public static let targetHeaterCoolerState = "000000B2-0000-1000-8000-0026BB765291"
    @objc public static let coolingThresholdTemperature = "0000000D-0000-1000-8000-0026BB765291"
    @objc public static let heatingThresholdTemperature = "00000012-0000-1000-8000-0026BB765291"
}
