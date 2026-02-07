//
//  HACoverMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for HACoverMenuItem (3-button control for HA covers without position support)
//

import XCTest
import AppKit
@testable import macOSBridge

final class HACoverMenuItemTests: XCTestCase {

    // MARK: - Test helpers

    private func createTestServiceData(
        currentPositionId: UUID? = UUID(),
        targetDoorStateId: UUID? = nil
    ) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: "Test Cover",
            serviceType: ServiceTypes.windowCovering,
            accessoryName: "Test Accessory",
            roomIdentifier: nil,
            currentPositionId: currentPositionId,
            targetDoorStateId: targetDoorStateId
        )
    }

    // MARK: - Initialisation tests

    func testInitSetsServiceData() {
        let serviceData = createTestServiceData()
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertEqual(menuItem.serviceData.name, "Test Cover")
        XCTAssertEqual(menuItem.serviceData.serviceType, ServiceTypes.windowCovering)
    }

    func testInitCreatesView() {
        let serviceData = createTestServiceData()
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Characteristic identifier tests

    func testCharacteristicIdentifiersContainsPositionId() {
        let positionId = UUID()
        let serviceData = createTestServiceData(currentPositionId: positionId)
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(positionId))
    }

    func testCharacteristicIdentifiersEmptyWhenNoPositionId() {
        let serviceData = createTestServiceData(currentPositionId: nil)
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.isEmpty)
    }

    // MARK: - Value update tests

    func testUpdatePositionValue() {
        let positionId = UUID()
        let serviceData = createTestServiceData(currentPositionId: positionId)
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: positionId, value: 100)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueIgnoresUnknownCharacteristicId() {
        let positionId = UUID()
        let unknownId = UUID()
        let serviceData = createTestServiceData(currentPositionId: positionId)
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: unknownId, value: 50)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Protocol conformance tests

    func testConformsToCharacteristicUpdatable() {
        let serviceData = createTestServiceData()
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicUpdatable)
    }

    func testConformsToCharacteristicRefreshable() {
        let serviceData = createTestServiceData()
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicRefreshable)
    }

    func testConformsToLocalChangeNotifiable() {
        let serviceData = createTestServiceData()
        let menuItem = HACoverMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is LocalChangeNotifiable)
    }
}
