//
//  SensorStateMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for SensorStateMenuItem (read-only binary sensor row)
//

import XCTest
import AppKit
@testable import macOSBridge

final class SensorStateMenuItemTests: XCTestCase {

    /// Build a ServiceData for one binary sensor, routing the characteristic id
    /// to the field that matches its service type.
    private func makeService(type: String, charId: UUID) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: "Test Sensor",
            serviceType: type,
            accessoryName: "Test Accessory",
            roomIdentifier: nil,
            motionDetectedId: type == ServiceTypes.motionSensor ? charId : nil,
            contactSensorStateId: type == ServiceTypes.contactSensor ? charId : nil,
            occupancyDetectedId: type == ServiceTypes.occupancySensor ? charId : nil,
            leakDetectedId: type == ServiceTypes.leakSensor ? charId : nil,
            smokeDetectedId: type == ServiceTypes.smokeSensor ? charId : nil,
            carbonMonoxideDetectedId: type == ServiceTypes.carbonMonoxideSensor ? charId : nil,
            carbonDioxideDetectedId: type == ServiceTypes.carbonDioxideSensor ? charId : nil
        )
    }

    private let allTypes = [
        ServiceTypes.contactSensor,
        ServiceTypes.motionSensor,
        ServiceTypes.occupancySensor,
        ServiceTypes.leakSensor,
        ServiceTypes.smokeSensor,
        ServiceTypes.carbonMonoxideSensor,
        ServiceTypes.carbonDioxideSensor
    ]

    // MARK: - Characteristic routing

    // Each kind must subscribe to its own detected-state characteristic; a
    // mis-wired routing would silently leave the row never updating.
    func testCharacteristicIdentifiersRouteToCorrectFieldPerKind() {
        for type in allTypes {
            let id = UUID()
            let item = SensorStateMenuItem(serviceData: makeService(type: type, charId: id), bridge: nil)
            XCTAssertEqual(item.characteristicIdentifiers, [id], "routing for \(type)")
        }
    }

    // MARK: - State words

    // Raw value 1 = active reading, 0 = resting, for every kind.
    func testStateWordsPerKind() {
        let cases: [(type: String, active: String, resting: String)] = [
            (ServiceTypes.contactSensor, "Open", "Closed"),
            (ServiceTypes.motionSensor, "Motion", "Clear"),
            (ServiceTypes.occupancySensor, "Occupied", "Clear"),
            (ServiceTypes.leakSensor, "Leak", "Dry"),
            (ServiceTypes.smokeSensor, "Smoke", "Clear"),
            (ServiceTypes.carbonMonoxideSensor, "CO", "Clear"),
            (ServiceTypes.carbonDioxideSensor, "CO2", "Clear")
        ]
        for c in cases {
            let id = UUID()
            let item = SensorStateMenuItem(serviceData: makeService(type: c.type, charId: id), bridge: nil)

            item.updateValue(for: id, value: 1)
            XCTAssertEqual(item.displayedState, c.active, "active word for \(c.type)")

            item.updateValue(for: id, value: 0)
            XCTAssertEqual(item.displayedState, c.resting, "resting word for \(c.type)")
        }
    }

    // HAP ContactSensorState 1 = "not detected" = physically open. This
    // inversion is load-bearing and asymmetric versus the safety sensors.
    func testContactInvertedSemantics() {
        let id = UUID()
        let item = SensorStateMenuItem(serviceData: makeService(type: ServiceTypes.contactSensor, charId: id), bridge: nil)

        item.updateValue(for: id, value: 1)
        XCTAssertEqual(item.displayedState, "Open")

        item.updateValue(for: id, value: 0)
        XCTAssertEqual(item.displayedState, "Closed")
    }

    // MARK: - Edge cases

    func testFreshRowShowsPlaceholder() {
        let item = SensorStateMenuItem(serviceData: makeService(type: ServiceTypes.leakSensor, charId: UUID()), bridge: nil)
        XCTAssertEqual(item.displayedState, "—")
    }

    func testOutOfRangeValueShowsPlaceholder() {
        let id = UUID()
        let item = SensorStateMenuItem(serviceData: makeService(type: ServiceTypes.smokeSensor, charId: id), bridge: nil)
        item.updateValue(for: id, value: 7)
        XCTAssertEqual(item.displayedState, "—")
    }

    func testIgnoresUnrelatedCharacteristic() {
        let id = UUID()
        let item = SensorStateMenuItem(serviceData: makeService(type: ServiceTypes.smokeSensor, charId: id), bridge: nil)
        item.updateValue(for: id, value: 1)
        XCTAssertEqual(item.displayedState, "Smoke")

        item.updateValue(for: UUID(), value: 0)  // different characteristic
        XCTAssertEqual(item.displayedState, "Smoke")
    }

    // MARK: - Construction

    func testViewIsCreated() {
        let item = SensorStateMenuItem(serviceData: makeService(type: ServiceTypes.contactSensor, charId: UUID()), bridge: nil)
        XCTAssertNotNil(item.view)
    }

    func testConformsToProtocols() {
        let item = SensorStateMenuItem(serviceData: makeService(type: ServiceTypes.contactSensor, charId: UUID()), bridge: nil)
        XCTAssertTrue(item is CharacteristicUpdatable)
        XCTAssertTrue(item is CharacteristicRefreshable)
    }
}
