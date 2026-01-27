//
//  HomeKitTypeNames.swift
//  Itsyhome
//
//  Human-readable names for HomeKit service and characteristic types
//

import Foundation
import HomeKit

enum HomeKitTypeNames {

    // MARK: - Service type names

    static func serviceName(_ type: String) -> String {
        switch type {
        case HMServiceTypeLightbulb: return "Lightbulb"
        case HMServiceTypeSwitch: return "Switch"
        case HMServiceTypeOutlet: return "Outlet"
        case HMServiceTypeFan: return "Fan"
        case ServiceTypes.fanV2: return "FanV2"
        case HMServiceTypeThermostat: return "Thermostat"
        case HMServiceTypeHeaterCooler: return "HeaterCooler"
        case HMServiceTypeLockMechanism: return "Lock"
        case HMServiceTypeWindowCovering: return "WindowCovering"
        case HMServiceTypeGarageDoorOpener: return "GarageDoor"
        case HMServiceTypeTemperatureSensor: return "TemperatureSensor"
        case HMServiceTypeHumiditySensor: return "HumiditySensor"
        case HMServiceTypeMotionSensor: return "MotionSensor"
        case HMServiceTypeContactSensor: return "ContactSensor"
        case HMServiceTypeSecuritySystem: return "SecuritySystem"
        case HMServiceTypeHumidifierDehumidifier: return "HumidifierDehumidifier"
        case HMServiceTypeAirPurifier: return "AirPurifier"
        case HMServiceTypeValve: return "Valve"
        case HMServiceTypeCameraControl: return "CameraControl"
        case HMServiceTypeCameraRTPStreamManagement: return "CameraStream"
        default: return ""
        }
    }

    // MARK: - Characteristic type names

    static func characteristicName(_ type: String) -> String {
        switch type {
        case HMCharacteristicTypePowerState: return "PowerState"
        case HMCharacteristicTypeTargetRelativeHumidity: return "TargetRelativeHumidity"
        case HMCharacteristicTypeCurrentRelativeHumidity: return "CurrentRelativeHumidity"
        case HMCharacteristicTypeBrightness: return "Brightness"
        case HMCharacteristicTypeHue: return "Hue"
        case HMCharacteristicTypeSaturation: return "Saturation"
        case HMCharacteristicTypeColorTemperature: return "ColorTemperature"
        case HMCharacteristicTypeCurrentTemperature: return "CurrentTemperature"
        case HMCharacteristicTypeTargetTemperature: return "TargetTemperature"
        case HMCharacteristicTypeCurrentHeatingCooling: return "CurrentHeatingCooling"
        case HMCharacteristicTypeTargetHeatingCooling: return "TargetHeatingCooling"
        case HMCharacteristicTypeCurrentHeaterCoolerState: return "CurrentHeaterCoolerState"
        case HMCharacteristicTypeTargetHeaterCoolerState: return "TargetHeaterCoolerState"
        case HMCharacteristicTypeCoolingThreshold: return "CoolingThreshold"
        case HMCharacteristicTypeHeatingThreshold: return "HeatingThreshold"
        case HMCharacteristicTypeCurrentLockMechanismState: return "CurrentLockMechanismState"
        case HMCharacteristicTypeTargetLockMechanismState: return "TargetLockMechanismState"
        case HMCharacteristicTypeCurrentPosition: return "CurrentPosition"
        case HMCharacteristicTypeTargetPosition: return "TargetPosition"
        case HMCharacteristicTypePositionState: return "PositionState"
        case HMCharacteristicTypeRotationSpeed: return "RotationSpeed"
        case HMCharacteristicTypeRotationDirection: return "RotationDirection"
        case HMCharacteristicTypeActive: return "Active"
        case HMCharacteristicTypeSwingMode: return "SwingMode"
        case HMCharacteristicTypeTargetFanState: return "TargetFanState"
        case HMCharacteristicTypeCurrentFanState: return "CurrentFanState"
        case HMCharacteristicTypeCurrentDoorState: return "CurrentDoorState"
        case HMCharacteristicTypeTargetDoorState: return "TargetDoorState"
        case HMCharacteristicTypeObstructionDetected: return "ObstructionDetected"
        case HMCharacteristicTypeMotionDetected: return "MotionDetected"
        case HMCharacteristicTypeContactState: return "ContactState"
        case CharacteristicTypes.securitySystemCurrentState: return "SecuritySystemCurrentState"
        case CharacteristicTypes.securitySystemTargetState: return "SecuritySystemTargetState"
        case HMCharacteristicTypeInUse: return "InUse"
        case HMCharacteristicTypeValveType: return "ValveType"
        case HMCharacteristicTypeSetDuration: return "SetDuration"
        case HMCharacteristicTypeRemainingDuration: return "RemainingDuration"
        default: return ""
        }
    }
}
