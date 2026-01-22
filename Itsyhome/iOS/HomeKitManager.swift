//
//  HomeKitManager.swift
//  Itsyhome
//
//  HomeKit manager that implements Mac2iOS protocol
//

import Foundation
import HomeKit
import os.log
import UIKit

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeKitManager")

class HomeKitManager: NSObject, Mac2iOS, HMHomeManagerDelegate {

    private var homeManager: HMHomeManager?
    private var currentHome: HMHome?

    weak var macOSDelegate: iOS2Mac?

    // MARK: - Cached data (stored properties for thread safety)

    private(set) var homes: [HomeInfo] = []
    private(set) var rooms: [RoomInfo] = []
    private(set) var accessories: [AccessoryInfo] = []
    private(set) var scenes: [SceneInfo] = []

    var selectedHomeIdentifier: UUID? {
        get { currentHome?.uniqueIdentifier }
        set {
            if let id = newValue, let manager = homeManager {
                currentHome = manager.homes.first { $0.uniqueIdentifier == id }
            } else {
                currentHome = homeManager?.primaryHome ?? homeManager?.homes.first
            }
            fetchDataAndReloadMenu()
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        logger.info("HomeKitManager init")
        
        // Initialize HomeManager
        homeManager = HMHomeManager()
        homeManager?.delegate = self
    }
    
    // MARK: - Data fetching
    
    private func fetchDataAndReloadMenu() {
        guard let manager = homeManager else {
            logger.error("No homeManager")
            return
        }
        
        // Populate homes
        homes = manager.homes.map { home in
            HomeInfo(
                uniqueIdentifier: home.uniqueIdentifier,
                name: home.name,
                isPrimary: home == manager.primaryHome
            )
        }
        
        guard let home = currentHome else {
            logger.info("No current home selected")
            rooms = []
            accessories = []
            scenes = []
            sendMenuDataAsJSON()
            return
        }
        
        logger.info("Fetching data for home: \(home.name, privacy: .public)")

        // Populate rooms
        rooms = home.rooms.map { room in
            RoomInfo(uniqueIdentifier: room.uniqueIdentifier, name: room.name)
        }.sorted { $0.name < $1.name }

        let supportedTypes: Set<String> = [
            HMServiceTypeLightbulb,
            HMServiceTypeSwitch,
            HMServiceTypeOutlet,
            HMServiceTypeThermostat,
            HMServiceTypeHeaterCooler,
            HMServiceTypeLockMechanism,
            HMServiceTypeWindowCovering,
            HMServiceTypeTemperatureSensor,
            HMServiceTypeHumiditySensor,
            HMServiceTypeMotionSensor,
            HMServiceTypeFan,
            HMServiceTypeGarageDoorOpener,
            HMServiceTypeContactSensor,
            ServiceTypes.humidifierDehumidifier,
            ServiceTypes.airPurifier,
            ServiceTypes.valve,
            ServiceTypes.securitySystem
        ]

        // Populate accessories
        accessories = home.accessories.map { accessory in
            let services = accessory.services.compactMap { service -> ServiceInfo? in
                guard supportedTypes.contains(service.serviceType) else { return nil }

                return ServiceInfo(
                    uniqueIdentifier: service.uniqueIdentifier,
                    name: service.name ?? accessory.name,
                    serviceType: service.serviceType,
                    accessoryName: accessory.name,
                    roomIdentifier: accessory.room?.uniqueIdentifier
                )
            }

            return AccessoryInfo(
                uniqueIdentifier: accessory.uniqueIdentifier,
                name: accessory.name,
                roomIdentifier: accessory.room?.uniqueIdentifier,
                services: services,
                isReachable: accessory.isReachable
            )
        }

        // Populate scenes - include all types but filter out empty scenes (0 actions)
        // and automation-owned scenes (TriggerOwned)
        scenes = home.actionSets
            .filter { $0.actionSetType != HMActionSetTypeTriggerOwned && $0.actions.count > 0 }
            .map { SceneInfo(uniqueIdentifier: $0.uniqueIdentifier, name: $0.name) }
            .sorted { $0.name < $1.name }

        let totalServices = accessories.reduce(0) { $0 + $1.services.count }
        logger.info("Data fetched - rooms: \(self.rooms.count), accessories: \(self.accessories.count), supported services: \(totalServices), scenes: \(self.scenes.count)")

        // Set up delegates
        home.delegate = self
        for accessory in home.accessories {
            accessory.delegate = self
        }
        
        // Serialize to JSON for safe cross-module transfer
        sendMenuDataAsJSON()
    }
    
    // MARK: - Mac2iOS Methods
    
    func reloadHomeKit() {
        fetchDataAndReloadMenu()
    }

    func executeScene(identifier: UUID) {
        guard let home = currentHome,
              let actionSet = home.actionSets.first(where: { $0.uniqueIdentifier == identifier }) else { return }
        
        home.executeActionSet(actionSet) { error in
            if let error = error {
                logger.error("Failed to execute scene: \(error.localizedDescription)")
                // Suppress partial success errors (unreachable devices) - similar to how we handle unreachable devices elsewhere
                let hmError = error as NSError
                if hmError.domain == HMErrorDomain && hmError.code == HMError.actionSetExecutionPartialSuccess.rawValue {
                    return
                }
                self.macOSDelegate?.showError(message: "Failed to execute scene: \(error.localizedDescription)")
            }
        }
    }
    
    func readCharacteristic(identifier: UUID) {
        guard let characteristic = findCharacteristic(identifier: identifier) else { return }

        // Check if characteristic is readable
        guard characteristic.properties.contains(HMCharacteristicPropertyReadable) else {
            return
        }

        // Check if accessory is reachable
        guard characteristic.service?.accessory?.isReachable == true else {
            return
        }

        characteristic.readValue { error in
            if error != nil {
                // Silently ignore read failures - device may be temporarily unreachable
                return
            }
            if let value = characteristic.value {
                DispatchQueue.main.async {
                    self.macOSDelegate?.updateCharacteristic(identifier: identifier, value: value)
                }
            }
        }
    }
    
    func writeCharacteristic(identifier: UUID, value: Any) {
        guard let characteristic = findCharacteristic(identifier: identifier) else {
            logger.error("Characteristic not found: \(identifier)")
            return
        }

        // Silently skip if accessory is not reachable
        let accessoryReachable = characteristic.service?.accessory?.isReachable ?? false
        logger.info("writeCharacteristic: accessory isReachable=\(accessoryReachable)")
        guard accessoryReachable else {
            logger.info("Skipping write - accessory not reachable")
            return
        }

        let metadata = characteristic.metadata
        let format = metadata?.format ?? "unknown"
        let minValue = metadata?.minimumValue
        let maxValue = metadata?.maximumValue
        logger.info("Writing to \(characteristic.characteristicType, privacy: .public): input=\(String(describing: value)) (\(type(of: value))), format=\(format, privacy: .public), range=\(String(describing: minValue))-\(String(describing: maxValue))")

        // Convert value to the format expected by the characteristic
        let convertedValue: Any
        if let format = metadata?.format {
            switch format {
            case HMCharacteristicMetadataFormatFloat:
                if let num = value as? NSNumber {
                    convertedValue = num.floatValue
                } else if let num = value as? Double {
                    convertedValue = Float(num)
                } else if let num = value as? Int {
                    convertedValue = Float(num)
                } else {
                    convertedValue = value
                }
            case HMCharacteristicMetadataFormatInt,
                 HMCharacteristicMetadataFormatUInt8,
                 HMCharacteristicMetadataFormatUInt16,
                 HMCharacteristicMetadataFormatUInt32,
                 HMCharacteristicMetadataFormatUInt64:
                if let num = value as? NSNumber {
                    convertedValue = num.intValue
                } else if let num = value as? Double {
                    convertedValue = Int(num)
                } else if let num = value as? Float {
                    convertedValue = Int(num)
                } else {
                    convertedValue = value
                }
            case HMCharacteristicMetadataFormatBool:
                if let num = value as? NSNumber {
                    convertedValue = num.boolValue
                } else if let num = value as? Int {
                    convertedValue = num != 0
                } else {
                    convertedValue = value
                }
            default:
                convertedValue = value
            }
        } else {
            convertedValue = value
        }

        logger.info("Converted value: \(String(describing: convertedValue)) (\(type(of: convertedValue)))")

        characteristic.writeValue(convertedValue) { error in
            if let error = error {
                // Log the error but don't show dialog - device may be temporarily unreachable
                logger.error("Write failed for \(characteristic.characteristicType, privacy: .public): \(error.localizedDescription)")
            } else {
                logger.info("Write succeeded for \(characteristic.characteristicType, privacy: .public)")
            }
        }
    }
    
    func getCharacteristicValue(identifier: UUID) -> Any? {
        return findCharacteristic(identifier: identifier)?.value
    }

    // MARK: - Helper Methods
    
    private func sendMenuDataAsJSON() {
        // Convert to Codable structs
        let homeData = homes.map { HomeData(uniqueIdentifier: $0.uniqueIdentifier, name: $0.name, isPrimary: $0.isPrimary) }
        let roomData = rooms.map { RoomData(uniqueIdentifier: $0.uniqueIdentifier, name: $0.name) }
        let accessoryData = accessories.map { acc in
            AccessoryData(
                uniqueIdentifier: acc.uniqueIdentifier,
                name: acc.name,
                roomIdentifier: acc.roomIdentifier,
                services: acc.services.map { svc in
                    self.buildServiceData(from: svc)
                },
                isReachable: acc.isReachable
            )
        }
        let sceneData = scenes.map { scene -> SceneData in
            buildSceneData(from: scene)
        }

        let menuData = MenuData(homes: homeData, rooms: roomData, accessories: accessoryData, scenes: sceneData, selectedHomeId: selectedHomeIdentifier)

        do {
            let jsonData = try JSONEncoder().encode(menuData)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.info("Sending JSON menu data (\(jsonString.count) chars)")
                DispatchQueue.main.async {
                    self.macOSDelegate?.reloadMenuWithJSON(jsonString)
                }
            }
        } catch {
            logger.error("Failed to encode menu data: \(error.localizedDescription)")
        }
    }

    private func buildServiceData(from svc: ServiceInfo) -> ServiceData {
        // Find the original HMService to extract characteristic UUIDs
        guard let hmService = findService(identifier: svc.uniqueIdentifier) else {
            return ServiceData(
                uniqueIdentifier: svc.uniqueIdentifier,
                name: svc.name,
                serviceType: svc.serviceType,
                accessoryName: svc.accessoryName,
                roomIdentifier: svc.roomIdentifier,
                isReachable: false
            )
        }

        let isReachable = hmService.accessory?.isReachable ?? false

        // Helper to find characteristic UUID by type (using our constants for unavailable HMCharacteristicType*)
        func charId(_ type: String) -> UUID? {
            hmService.characteristics.first { $0.characteristicType == type }?.uniqueIdentifier
        }

        // Helper to find characteristic by type
        func findChar(_ type: String) -> HMCharacteristic? {
            hmService.characteristics.first { $0.characteristicType == type }
        }

        // Get rotation speed min/max from metadata
        let rotationSpeedChar = findChar(CharacteristicTypes.rotationSpeed)
        let rotationSpeedMin = rotationSpeedChar?.metadata?.minimumValue?.doubleValue
        let rotationSpeedMax = rotationSpeedChar?.metadata?.maximumValue?.doubleValue

        // Get color temperature min/max from metadata
        let colorTempChar = findChar(CharacteristicTypes.colorTemperature)
        let colorTempMin = colorTempChar?.metadata?.minimumValue?.doubleValue
        let colorTempMax = colorTempChar?.metadata?.maximumValue?.doubleValue

        // Get valve type value (stored directly, not as characteristic ID)
        let valveTypeChar = findChar(CharacteristicTypes.valveType)
        let valveTypeValue = valveTypeChar?.value as? Int

        return ServiceData(
            uniqueIdentifier: svc.uniqueIdentifier,
            name: svc.name,
            serviceType: svc.serviceType,
            accessoryName: svc.accessoryName,
            roomIdentifier: svc.roomIdentifier,
            isReachable: isReachable,
            powerStateId: charId(HMCharacteristicTypePowerState),
            brightnessId: charId(HMCharacteristicTypeBrightness),
            hueId: charId(CharacteristicTypes.hue),
            saturationId: charId(CharacteristicTypes.saturation),
            colorTemperatureId: charId(CharacteristicTypes.colorTemperature),
            colorTemperatureMin: colorTempMin,
            colorTemperatureMax: colorTempMax,
            currentTemperatureId: charId(HMCharacteristicTypeCurrentTemperature),
            targetTemperatureId: charId(HMCharacteristicTypeTargetTemperature),
            heatingCoolingStateId: charId(HMCharacteristicTypeCurrentHeatingCooling),
            targetHeatingCoolingStateId: charId(HMCharacteristicTypeTargetHeatingCooling),
            lockCurrentStateId: charId(CharacteristicTypes.lockCurrentState),
            lockTargetStateId: charId(CharacteristicTypes.lockTargetState),
            currentPositionId: charId(HMCharacteristicTypeCurrentPosition),
            targetPositionId: charId(HMCharacteristicTypeTargetPosition),
            humidityId: charId(HMCharacteristicTypeCurrentRelativeHumidity),
            motionDetectedId: charId(HMCharacteristicTypeMotionDetected),
            // HeaterCooler (AC) characteristics
            activeId: charId(CharacteristicTypes.active),
            currentHeaterCoolerStateId: charId(CharacteristicTypes.currentHeaterCoolerState),
            targetHeaterCoolerStateId: charId(CharacteristicTypes.targetHeaterCoolerState),
            coolingThresholdTemperatureId: charId(CharacteristicTypes.coolingThresholdTemperature),
            heatingThresholdTemperatureId: charId(CharacteristicTypes.heatingThresholdTemperature),
            // Fan characteristics
            rotationSpeedId: charId(CharacteristicTypes.rotationSpeed),
            rotationSpeedMin: rotationSpeedMin,
            rotationSpeedMax: rotationSpeedMax,
            // Garage door characteristics
            currentDoorStateId: charId(CharacteristicTypes.currentDoorState),
            targetDoorStateId: charId(CharacteristicTypes.targetDoorState),
            obstructionDetectedId: charId(CharacteristicTypes.obstructionDetected),
            // Contact sensor characteristics
            contactSensorStateId: charId(CharacteristicTypes.contactSensorState),
            // Humidifier/Dehumidifier characteristics
            currentHumidifierDehumidifierStateId: charId(CharacteristicTypes.currentHumidifierDehumidifierState),
            targetHumidifierDehumidifierStateId: charId(CharacteristicTypes.targetHumidifierDehumidifierState),
            humidifierThresholdId: charId(CharacteristicTypes.humidifierThreshold),
            dehumidifierThresholdId: charId(CharacteristicTypes.dehumidifierThreshold),
            // Air Purifier characteristics
            currentAirPurifierStateId: charId(CharacteristicTypes.currentAirPurifierState),
            targetAirPurifierStateId: charId(CharacteristicTypes.targetAirPurifierState),
            // Valve characteristics
            inUseId: charId(CharacteristicTypes.inUse),
            valveTypeValue: valveTypeValue,
            setDurationId: charId(CharacteristicTypes.setDuration),
            remainingDurationId: charId(CharacteristicTypes.remainingDuration),
            // Security System characteristics
            securitySystemCurrentStateId: charId(CharacteristicTypes.securitySystemCurrentState),
            securitySystemTargetStateId: charId(CharacteristicTypes.securitySystemTargetState)
        )
    }

    private func buildSceneData(from scene: SceneInfo) -> SceneData {
        // Find the original HMActionSet to extract actions
        guard let home = currentHome,
              let actionSet = home.actionSets.first(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) else {
            return SceneData(uniqueIdentifier: scene.uniqueIdentifier, name: scene.name, actions: [])
        }

        // Extract characteristic write actions
        let actions: [SceneActionData] = actionSet.actions.compactMap { action in
            // HMCharacteristicWriteAction is generic, check class name
            let className = String(describing: type(of: action))
            guard className.contains("CharacteristicWriteAction") else { return nil }

            // Use KVC to access characteristic and targetValue since it's a generic type
            guard let characteristic = action.value(forKey: "characteristic") as? HMCharacteristic,
                  let targetValueAny = action.value(forKey: "targetValue") else { return nil }

            // Convert target value to Double for consistent comparison
            let targetValue: Double
            if let boolValue = targetValueAny as? Bool {
                targetValue = boolValue ? 1.0 : 0.0
            } else if let intValue = targetValueAny as? Int {
                targetValue = Double(intValue)
            } else if let doubleValue = targetValueAny as? Double {
                targetValue = doubleValue
            } else if let floatValue = targetValueAny as? Float {
                targetValue = Double(floatValue)
            } else if let numberValue = targetValueAny as? NSNumber {
                targetValue = numberValue.doubleValue
            } else {
                return nil  // Unknown value type
            }

            return SceneActionData(
                characteristicId: characteristic.uniqueIdentifier,
                characteristicType: characteristic.characteristicType,
                targetValue: targetValue
            )
        }

        return SceneData(uniqueIdentifier: scene.uniqueIdentifier, name: scene.name, actions: actions)
    }

    private func findService(identifier: UUID) -> HMService? {
        guard let home = currentHome else { return nil }

        for accessory in home.accessories {
            if let service = accessory.services.first(where: { $0.uniqueIdentifier == identifier }) {
                return service
            }
        }
        return nil
    }
    
    private func findCharacteristic(identifier: UUID) -> HMCharacteristic? {
        guard let home = currentHome else { return nil }

        for accessory in home.accessories {
            for service in accessory.services {
                if let characteristic = service.characteristics.first(where: { $0.uniqueIdentifier == identifier }) {
                    return characteristic
                }
            }
        }
        return nil
    }

    // MARK: - HMHomeManagerDelegate
    
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        logger.info("Authorization status: \(status.rawValue)")
        
        if status.contains(.authorized) {
            logger.info("HomeKit authorized")
        } else if status.contains(.determined) {
            logger.warning("HomeKit not authorized")
            DispatchQueue.main.async {
                self.macOSDelegate?.showError(message: "HomeKit access denied. Enable in System Settings > Privacy & Security > HomeKit")
            }
        }
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        logger.info("homeManagerDidUpdateHomes - count: \(manager.homes.count)")
        
        // Select home if none selected
        if currentHome == nil {
            currentHome = manager.primaryHome ?? manager.homes.first
            logger.info("Selected home: \(self.currentHome?.name ?? "none", privacy: .public)")
        }
        
        fetchDataAndReloadMenu()
    }
}

// MARK: - HMHomeDelegate

extension HomeKitManager: HMHomeDelegate {
    func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        accessory.delegate = self
        fetchDataAndReloadMenu()
    }
    
    func home(_ home: HMHome, didRemove accessory: HMAccessory) {
        fetchDataAndReloadMenu()
    }
    
    func home(_ home: HMHome, didAdd room: HMRoom) {
        fetchDataAndReloadMenu()
    }
    
    func home(_ home: HMHome, didRemove room: HMRoom) {
        fetchDataAndReloadMenu()
    }
    
    func home(_ home: HMHome, didAdd actionSet: HMActionSet) {
        fetchDataAndReloadMenu()
    }
    
    func home(_ home: HMHome, didRemove actionSet: HMActionSet) {
        fetchDataAndReloadMenu()
    }
}

// MARK: - HMAccessoryDelegate

extension HomeKitManager: HMAccessoryDelegate {
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        macOSDelegate?.setReachability(accessoryIdentifier: accessory.uniqueIdentifier, isReachable: accessory.isReachable)
    }

    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        if let value = characteristic.value {
            macOSDelegate?.updateCharacteristic(identifier: characteristic.uniqueIdentifier, value: value)
        }
    }
}
