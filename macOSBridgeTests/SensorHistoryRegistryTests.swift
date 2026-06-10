//
//  SensorHistoryRegistryTests.swift
//  macOSBridgeTests
//

import XCTest
@testable import macOSBridge

final class SensorHistoryRegistryTests: XCTestCase {

    func testBuildMapsTemperatureToNumericByCharacteristicId() {
        let tempId = UUID()
        let service = TestServiceFactory.sensor(
            serviceType: ServiceTypes.temperatureSensor,
            name: "Living Room",
            currentTemperatureId: tempId.uuidString
        )
        let data = TestServiceFactory.menuData(services: [service])

        let registry = SensorHistoryRegistry.build(from: data)

        XCTAssertEqual(registry[tempId], SensorMeta(seriesKind: .numeric, name: "Living Room"))
    }

    func testBuildMapsContactToBinary() {
        let contactId = UUID()
        let service = TestServiceFactory.sensor(
            serviceType: ServiceTypes.contactSensor,
            name: "Front Door",
            contactSensorStateId: contactId.uuidString
        )
        let data = TestServiceFactory.menuData(services: [service])

        let registry = SensorHistoryRegistry.build(from: data)

        XCTAssertEqual(registry[contactId], SensorMeta(seriesKind: .binary, name: "Front Door"))
    }

    func testNonSensorServiceIsIgnored() {
        let service = TestServiceFactory.sensor(serviceType: "unknown.service.type", name: "Lamp")
        let data = TestServiceFactory.menuData(services: [service])
        XCTAssertTrue(SensorHistoryRegistry.build(from: data).isEmpty)
    }

    // MARK: - Non-sensor service with temperature/humidity (thermostat, AC, etc.)

    func testThermostatServiceWithTemperatureIdIsRegisteredAsNumeric() {
        // A thermostat is not a SensorKind, but its currentTemperatureId should
        // still be captured as numeric.
        let tempId = UUID()
        let service = TestServiceFactory.sensor(
            serviceType: ServiceTypes.thermostat,
            name: "Living Room Thermostat",
            currentTemperatureId: tempId.uuidString
        )
        let data = TestServiceFactory.menuData(services: [service])

        let registry = SensorHistoryRegistry.build(from: data)

        XCTAssertEqual(registry[tempId], SensorMeta(seriesKind: .numeric, name: "Living Room Thermostat"))
    }

    func testDedicatedTemperatureSensorIsRegisteredExactlyOnce() {
        // A dedicated temperature sensor service has both a SensorKind path and a
        // currentTemperatureId. The registry must not double-count it: the final
        // result should contain the ID exactly once, as numeric.
        let tempId = UUID()
        let service = TestServiceFactory.sensor(
            serviceType: ServiceTypes.temperatureSensor,
            name: "Bedroom Sensor",
            currentTemperatureId: tempId.uuidString
        )
        let data = TestServiceFactory.menuData(services: [service])

        let registry = SensorHistoryRegistry.build(from: data)

        // Exactly one entry for this characteristic.
        XCTAssertEqual(registry.count, 1)
        XCTAssertEqual(registry[tempId], SensorMeta(seriesKind: .numeric, name: "Bedroom Sensor"))
    }
}
