//
//  TestServiceFactory.swift
//  macOSBridgeTests
//
//  Convenience factory that builds ServiceData / MenuData values for tests.
//  Uses the real ServiceData/AccessoryData/MenuData initializers from
//  BridgeProtocols.swift - all characteristic id parameters accept UUID strings
//  (matching how tests hold IDs) and are converted internally to UUID for the
//  real init.
//

import Foundation
@testable import macOSBridge

enum TestServiceFactory {

    /// Build a ServiceData for a sensor service. All characteristic id parameters
    /// are optional UUID strings; pass only the ones relevant to the service type
    /// under test. Unrecognised service types produce a service with no
    /// characteristic ids, which exercises the "non-sensor is ignored" path.
    static func sensor(
        serviceType: String,
        name: String,
        currentTemperatureId: String? = nil,
        humidityId: String? = nil,
        motionDetectedId: String? = nil,
        contactSensorStateId: String? = nil,
        occupancyDetectedId: String? = nil,
        leakDetectedId: String? = nil,
        smokeDetectedId: String? = nil,
        carbonMonoxideDetectedId: String? = nil,
        carbonDioxideDetectedId: String? = nil
    ) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: name,
            serviceType: serviceType,
            accessoryName: name,
            roomIdentifier: nil,
            currentTemperatureId: currentTemperatureId.flatMap(UUID.init(uuidString:)),
            humidityId: humidityId.flatMap(UUID.init(uuidString:)),
            motionDetectedId: motionDetectedId.flatMap(UUID.init(uuidString:)),
            contactSensorStateId: contactSensorStateId.flatMap(UUID.init(uuidString:)),
            occupancyDetectedId: occupancyDetectedId.flatMap(UUID.init(uuidString:)),
            leakDetectedId: leakDetectedId.flatMap(UUID.init(uuidString:)),
            smokeDetectedId: smokeDetectedId.flatMap(UUID.init(uuidString:)),
            carbonMonoxideDetectedId: carbonMonoxideDetectedId.flatMap(UUID.init(uuidString:)),
            carbonDioxideDetectedId: carbonDioxideDetectedId.flatMap(UUID.init(uuidString:))
        )
    }

    /// Wrap one or more ServiceData values in a single AccessoryData inside a
    /// MenuData. Sufficient for all SensorHistoryRegistry tests.
    static func menuData(services: [ServiceData]) -> MenuData {
        let accessory = AccessoryData(
            uniqueIdentifier: UUID(),
            name: "Test Accessory",
            roomIdentifier: nil as UUID?,
            services: services,
            isReachable: true
        )
        return MenuData(
            homes: [],
            rooms: [],
            accessories: [accessory],
            scenes: [],
            selectedHomeId: nil as UUID?
        )
    }
}
