//
//  SwitchMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for SwitchMenuItem
//

import XCTest
import AppKit
@testable import macOSBridge

final class SwitchMenuItemTests: XCTestCase {

    // MARK: - Test helpers

    private func createTestServiceData(
        powerStateId: UUID? = UUID()
    ) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: "Test Switch",
            serviceType: ServiceTypes.switch,
            accessoryName: "Test Accessory",
            roomIdentifier: nil,
            powerStateId: powerStateId
        )
    }

    // MARK: - Initialisation tests

    func testInitSetsServiceData() {
        let serviceData = createTestServiceData()
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertEqual(menuItem.serviceData.name, "Test Switch")
        XCTAssertEqual(menuItem.serviceData.serviceType, ServiceTypes.switch)
    }

    func testInitCreatesView() {
        let serviceData = createTestServiceData()
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Characteristic identifier tests

    func testCharacteristicIdentifiersContainsPowerStateId() {
        let powerStateId = UUID()
        let serviceData = createTestServiceData(powerStateId: powerStateId)
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(powerStateId))
    }

    func testCharacteristicIdentifiersEmptyWhenNoPowerStateId() {
        let serviceData = ServiceData(
            uniqueIdentifier: UUID(),
            name: "Test Switch",
            serviceType: ServiceTypes.switch,
            accessoryName: "Test Accessory",
            roomIdentifier: nil,
            powerStateId: nil
        )
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.isEmpty)
    }

    // MARK: - Value update tests

    func testUpdateValueWithBoolTrue() {
        let powerStateId = UUID()
        let serviceData = createTestServiceData(powerStateId: powerStateId)
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: powerStateId, value: true)

        // The switch should be on (we can't directly check internal state,
        // but the view should exist and not crash)
        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueWithBoolFalse() {
        let powerStateId = UUID()
        let serviceData = createTestServiceData(powerStateId: powerStateId)
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: powerStateId, value: false)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueWithIntOne() {
        let powerStateId = UUID()
        let serviceData = createTestServiceData(powerStateId: powerStateId)
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: powerStateId, value: 1)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueWithIntZero() {
        let powerStateId = UUID()
        let serviceData = createTestServiceData(powerStateId: powerStateId)
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: powerStateId, value: 0)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueIgnoresUnknownCharacteristicId() {
        let powerStateId = UUID()
        let unknownId = UUID()
        let serviceData = createTestServiceData(powerStateId: powerStateId)
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        // Should not crash when receiving unknown characteristic
        menuItem.updateValue(for: unknownId, value: true)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Protocol conformance tests

    func testConformsToCharacteristicUpdatable() {
        let serviceData = createTestServiceData()
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicUpdatable)
    }

    func testConformsToCharacteristicRefreshable() {
        let serviceData = createTestServiceData()
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicRefreshable)
    }

    func testConformsToLocalChangeNotifiable() {
        let serviceData = createTestServiceData()
        let menuItem = SwitchMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is LocalChangeNotifiable)
    }
}
