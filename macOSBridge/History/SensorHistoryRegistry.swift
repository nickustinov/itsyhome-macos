//
//  SensorHistoryRegistry.swift
//  macOSBridge
//
//  Builds the characteristic-id -> SensorMeta map the HistoryStore uses to know
//  which incoming changes to capture and whether they are numeric or binary.
//

import Foundation

enum SensorHistoryRegistry {

    static func build(from data: MenuData) -> [UUID: SensorMeta] {
        var registry: [UUID: SensorMeta] = [:]
        for accessory in data.accessories {
            for service in accessory.services {
                // Recognised sensor services (contact, motion, temperature/humidity
                // sensors, ...) register their state characteristic.
                if let kind = SensorKind(serviceType: service.serviceType),
                   let idString = kind.stateCharacteristicId(from: service),
                   let id = UUID(uuidString: idString) {
                    registry[id] = SensorMeta(seriesKind: kind.seriesKind, name: service.name)
                }

                // Temperature/humidity also ride along on thermostats, AC units,
                // humidifiers, etc. Capture those readings too (as numeric), unless
                // the id was already registered above by a dedicated sensor service.
                if let idString = service.currentTemperatureId,
                   let id = UUID(uuidString: idString), registry[id] == nil {
                    registry[id] = SensorMeta(seriesKind: .numeric, name: service.name)
                }
                if let idString = service.humidityId,
                   let id = UUID(uuidString: idString), registry[id] == nil {
                    registry[id] = SensorMeta(seriesKind: .numeric, name: service.name)
                }
            }
        }
        return registry
    }
}
