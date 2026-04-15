//
//  HomeKitManager+DataFetching.swift
//  Itsyhome
//
//  Data fetching and serialization for HomeKit
//

import Foundation
import HomeKit
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeKitManager")

extension HomeKitManager {

    // MARK: - Data fetching

    func fetchDataAndReloadMenu() {
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

        guard let home = selectedHome else {
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
            ServiceTypes.door,
            ServiceTypes.window,
            HMServiceTypeTemperatureSensor,
            HMServiceTypeHumiditySensor,
            HMServiceTypeFan,
            ServiceTypes.fanV2,
            HMServiceTypeGarageDoorOpener,
            ServiceTypes.humidifierDehumidifier,
            ServiceTypes.airPurifier,
            ServiceTypes.valve,
            ServiceTypes.faucet,
            ServiceTypes.slat,
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

        // Subscribe to doorbell and motion events
        subscribeToDoorbellEvents()
        subscribeToMotionEvents()

        // Subscribe to all characteristic notifications for real-time updates
        subscribeToCharacteristicNotifications()

        // Serialize to JSON for safe cross-module transfer
        sendMenuDataAsJSON()
    }

    // MARK: - Characteristic notification subscriptions

    /// Characteristic types whose live updates actually drive menu state.
    /// Subscribing only to these avoids notification storms from metadata
    /// characteristics (firmware revision, manufacturer, model, etc.) that
    /// never change at runtime.
    static let observedCharacteristicTypes: Set<String> = [
        HMCharacteristicTypePowerState,
        CharacteristicTypes.outletInUse,
        HMCharacteristicTypeBrightness,
        CharacteristicTypes.hue,
        CharacteristicTypes.saturation,
        CharacteristicTypes.colorTemperature,
        HMCharacteristicTypeCurrentTemperature,
        HMCharacteristicTypeTargetTemperature,
        HMCharacteristicTypeCurrentHeatingCooling,
        HMCharacteristicTypeTargetHeatingCooling,
        CharacteristicTypes.lockCurrentState,
        CharacteristicTypes.lockTargetState,
        HMCharacteristicTypeCurrentPosition,
        HMCharacteristicTypeTargetPosition,
        CharacteristicTypes.currentHorizontalTiltAngle,
        CharacteristicTypes.targetHorizontalTiltAngle,
        CharacteristicTypes.currentVerticalTiltAngle,
        CharacteristicTypes.targetVerticalTiltAngle,
        CharacteristicTypes.positionState,
        HMCharacteristicTypeCurrentRelativeHumidity,
        HMCharacteristicTypeMotionDetected,
        CharacteristicTypes.active,
        CharacteristicTypes.currentHeaterCoolerState,
        CharacteristicTypes.targetHeaterCoolerState,
        CharacteristicTypes.coolingThresholdTemperature,
        CharacteristicTypes.heatingThresholdTemperature,
        CharacteristicTypes.rotationSpeed,
        CharacteristicTypes.rotationDirection,
        CharacteristicTypes.targetFanState,
        CharacteristicTypes.currentFanState,
        CharacteristicTypes.swingMode,
        CharacteristicTypes.currentDoorState,
        CharacteristicTypes.targetDoorState,
        CharacteristicTypes.obstructionDetected,
        CharacteristicTypes.contactSensorState,
        CharacteristicTypes.currentHumidifierDehumidifierState,
        CharacteristicTypes.targetHumidifierDehumidifierState,
        CharacteristicTypes.humidifierThreshold,
        CharacteristicTypes.dehumidifierThreshold,
        CharacteristicTypes.waterLevel,
        CharacteristicTypes.currentAirPurifierState,
        CharacteristicTypes.targetAirPurifierState,
        CharacteristicTypes.inUse,
        CharacteristicTypes.setDuration,
        CharacteristicTypes.remainingDuration,
        CharacteristicTypes.securitySystemCurrentState,
        CharacteristicTypes.securitySystemTargetState,
        CharacteristicTypes.currentTiltAngle,
        CharacteristicTypes.targetTiltAngle,
        CharacteristicTypes.currentSlatState
    ]

    func subscribeToCharacteristicNotifications() {
        guard let home = selectedHome else { return }

        // Collect characteristics that need subscription, grouped by accessory.
        // Filter to only types that drive ServiceData — subscribing to metadata
        // characteristics caused chatty bridges to keep the app awake 24/7.
        let observed = Self.observedCharacteristicTypes
        var accessoryBatches: [[HMCharacteristic]] = []
        for accessory in home.accessories {
            var batch: [HMCharacteristic] = []
            for service in accessory.services {
                for characteristic in service.characteristics {
                    guard observed.contains(characteristic.characteristicType) else { continue }
                    guard characteristic.properties.contains(
                        HMCharacteristicPropertySupportsEventNotification
                    ) else { continue }
                    guard !characteristic.isNotificationEnabled else { continue }
                    batch.append(characteristic)
                }
            }
            if !batch.isEmpty {
                accessoryBatches.append(batch)
            }
        }

        let totalCount = accessoryBatches.reduce(0) { $0 + $1.count }
        logger.info("Subscribing to notifications for \(totalCount) characteristics across \(accessoryBatches.count) accessories")

        // Stagger subscriptions per accessory to avoid overwhelming bridges
        for (index, batch) in accessoryBatches.enumerated() {
            let delay = Double(index) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for characteristic in batch {
                    characteristic.enableNotification(true) { error in
                        if let error = error {
                            logger.error("enableNotification failed for \(characteristic.characteristicType): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - JSON serialization

    func sendMenuDataAsJSON() {
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

        let motionSensorType = ServiceTypes.motionSensor
        let cameraData = cameraAccessories.map { acc in
            let hasMotion = acc.services.contains { $0.serviceType == motionSensorType }
            return CameraData(uniqueIdentifier: acc.uniqueIdentifier, name: acc.name, hasMotionSensor: hasMotion)
        }
        let menuData = MenuData(homes: homeData, rooms: roomData, accessories: accessoryData, scenes: sceneData, selectedHomeId: selectedHomeIdentifier, hasCameras: !cameraAccessories.isEmpty, cameras: cameraData)

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

    // MARK: - Service data building

    func buildServiceData(from svc: ServiceInfo) -> ServiceData {
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

        // Helper to find characteristic UUID by type
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

        // Get valid target states from characteristic metadata
        let validHCStates = findChar(CharacteristicTypes.targetHeaterCoolerState)?
            .metadata?.validValues?.compactMap { $0.intValue }
        let validHCoolingStates = findChar(HMCharacteristicTypeTargetHeatingCooling)?
            .metadata?.validValues?.compactMap { $0.intValue }

        // Get slat type value (stored directly, not as characteristic ID)
        let slatTypeChar = findChar(CharacteristicTypes.slatType)
        let slatTypeValue = slatTypeChar?.value as? Int

        return ServiceData(
            uniqueIdentifier: svc.uniqueIdentifier,
            name: svc.name,
            serviceType: svc.serviceType,
            accessoryName: svc.accessoryName,
            roomIdentifier: svc.roomIdentifier,
            isReachable: isReachable,
            powerStateId: charId(HMCharacteristicTypePowerState),
            outletInUseId: charId(CharacteristicTypes.outletInUse),
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
            validTargetHeatingCoolingStates: validHCoolingStates,
            lockCurrentStateId: charId(CharacteristicTypes.lockCurrentState),
            lockTargetStateId: charId(CharacteristicTypes.lockTargetState),
            currentPositionId: charId(HMCharacteristicTypeCurrentPosition),
            targetPositionId: charId(HMCharacteristicTypeTargetPosition),
            currentHorizontalTiltId: charId(CharacteristicTypes.currentHorizontalTiltAngle),
            targetHorizontalTiltId: charId(CharacteristicTypes.targetHorizontalTiltAngle),
            currentVerticalTiltId: charId(CharacteristicTypes.currentVerticalTiltAngle),
            targetVerticalTiltId: charId(CharacteristicTypes.targetVerticalTiltAngle),
            positionStateId: charId(CharacteristicTypes.positionState),
            humidityId: charId(HMCharacteristicTypeCurrentRelativeHumidity),
            motionDetectedId: charId(HMCharacteristicTypeMotionDetected),
            // HeaterCooler (AC) characteristics
            activeId: charId(CharacteristicTypes.active),
            currentHeaterCoolerStateId: charId(CharacteristicTypes.currentHeaterCoolerState),
            targetHeaterCoolerStateId: charId(CharacteristicTypes.targetHeaterCoolerState),
            validTargetHeaterCoolerStates: validHCStates,
            coolingThresholdTemperatureId: charId(CharacteristicTypes.coolingThresholdTemperature),
            heatingThresholdTemperatureId: charId(CharacteristicTypes.heatingThresholdTemperature),
            // Fan characteristics
            rotationSpeedId: charId(CharacteristicTypes.rotationSpeed),
            rotationSpeedMin: rotationSpeedMin,
            rotationSpeedMax: rotationSpeedMax,
            targetFanStateId: charId(CharacteristicTypes.targetFanState),
            currentFanStateId: charId(CharacteristicTypes.currentFanState),
            rotationDirectionId: charId(CharacteristicTypes.rotationDirection),
            swingModeId: charId(CharacteristicTypes.swingMode),
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
            waterLevelId: charId(CharacteristicTypes.waterLevel),
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
            securitySystemTargetStateId: charId(CharacteristicTypes.securitySystemTargetState),
            // Slat characteristics
            currentTiltAngleId: charId(CharacteristicTypes.currentTiltAngle),
            targetTiltAngleId: charId(CharacteristicTypes.targetTiltAngle),
            slatTypeValue: slatTypeValue,
            currentSlatStateId: charId(CharacteristicTypes.currentSlatState)
        )
    }

    // MARK: - Scene data building

    func buildSceneData(from scene: SceneInfo) -> SceneData {
        // Find the original HMActionSet to extract actions
        guard let home = selectedHome,
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
}
