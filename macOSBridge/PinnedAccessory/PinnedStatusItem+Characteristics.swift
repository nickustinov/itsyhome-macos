//
//  PinnedStatusItem+Characteristics.swift
//  macOSBridge
//
//  Characteristic tracking and updates for pinned status items
//

import AppKit

extension PinnedStatusItem {

    // MARK: - Characteristic updates

    var characteristicIdentifiers: [UUID] {
        switch itemType {
        case .service(let service):
            return extractCharacteristicIds(from: service)
        case .room(_, let services):
            return services.flatMap { extractCharacteristicIds(from: $0) }
        case .scene, .scenesSection:
            return []  // Scenes don't have characteristics to monitor
        case .group(_, let services):
            return services.flatMap { extractCharacteristicIds(from: $0) }
        }
    }

    func extractCharacteristicIds(from service: ServiceData) -> [UUID] {
        var ids: [UUID] = []
        if let id = service.powerStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.brightnessId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.hueId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.saturationId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.colorTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.currentTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.heatingCoolingStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetHeatingCoolingStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.activeId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetHeaterCoolerStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.coolingThresholdTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.heatingThresholdTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.lockCurrentStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.lockTargetStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.currentPositionId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetPositionId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.rotationSpeedId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.currentDoorStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetDoorStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.securitySystemCurrentStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.securitySystemTargetStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.humidityId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        return ids
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        // Cache the value for status display
        let oldValue = cachedValues[characteristicId]
        cachedValues[characteristicId] = value

        // Refresh button if value changed and this is a display characteristic
        if !valuesEqual(oldValue, value), isDisplayCharacteristic(characteristicId) {
            setupButton()
        }

        // Update any menu items that track this characteristic
        for item in menuItems {
            if let refreshable = item as? CharacteristicRefreshable,
               refreshable.characteristicIdentifiers.contains(characteristicId),
               let updatable = item as? CharacteristicUpdatable {
                updatable.updateValue(for: characteristicId, value: value, isLocalChange: false)
            }
        }
    }

    func valuesEqual(_ a: Any?, _ b: Any) -> Bool {
        if a == nil { return false }
        if let aInt = a as? Int, let bInt = b as? Int { return aInt == bInt }
        if let aDouble = a as? Double, let bDouble = b as? Double { return aDouble == bDouble }
        if let aBool = a as? Bool, let bBool = b as? Bool { return aBool == bBool }
        return false
    }

    func isDisplayCharacteristic(_ characteristicId: UUID) -> Bool {
        // Check if this characteristic affects the status bar display
        guard case .service(let service) = itemType else { return false }

        let displayIds: [String?] = [
            service.powerStateId,  // For lights, switches, outlets on/off state
            service.activeId,  // For heater/cooler, fans, valves on/off state
            service.currentTemperatureId,
            service.targetHeaterCoolerStateId,
            service.targetHeatingCoolingStateId,
            service.targetHumidifierDehumidifierStateId,  // For humidifier mode
            service.humidityId,
            service.currentPositionId,
            service.lockCurrentStateId,
            service.currentDoorStateId,
            service.securitySystemCurrentStateId
        ]

        return displayIds.compactMap { $0.flatMap { UUID(uuidString: $0) } }.contains(characteristicId)
    }
}
