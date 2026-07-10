//
//  BatteriesMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for the "Batteries" submenu (#144): device extraction, dedup by
//  battery characteristic, and live sorting by charge level.
//

import XCTest
import AppKit
@testable import macOSBridge

final class BatteriesMenuItemTests: XCTestCase {

    private func makeService(name: String = "Device", levelId: UUID? = nil, lowId: UUID? = nil) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: name,
            serviceType: ServiceTypes.contactSensor,
            accessoryName: name,
            roomIdentifier: nil,
            batteryLevelId: levelId,
            statusLowBatteryId: lowId
        )
    }

    private func makeAccessory(name: String, services: [ServiceData]) -> AccessoryData {
        AccessoryData(uniqueIdentifier: UUID(), name: name, roomIdentifier: nil, services: services, isReachable: true)
    }

    // MARK: - Device extraction

    // Every service of an accessory carries the same battery sensor (sibling
    // battery service on HomeKit, same-device battery sensor on HA), so the
    // submenu must show one row per battery, not one per service.
    func testDevicesDedupeServicesSharingABattery() {
        let levelId = UUID()
        let accessory = makeAccessory(name: "Thermostat", services: [
            makeService(name: "Thermostat", levelId: levelId),
            makeService(name: "Thermostat temperature", levelId: levelId)
        ])

        let devices = BatteriesMenuItem.devices(from: [accessory])

        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.name, "Thermostat")
    }

    func testDevicesSkipServicesWithoutBattery() {
        let accessory = makeAccessory(name: "Lamp", services: [makeService(name: "Lamp")])
        XCTAssertTrue(BatteriesMenuItem.devices(from: [accessory]).isEmpty)
    }

    func testInitReturnsNilWithoutBatteryDevices() {
        let accessory = makeAccessory(name: "Lamp", services: [makeService(name: "Lamp")])
        XCTAssertNil(BatteriesMenuItem(accessories: [accessory], bridge: nil))
    }

    // MARK: - Characteristic routing

    // The item must subscribe to both battery characteristics so menuWillOpen
    // refreshes them and updates reach the rows.
    func testCharacteristicIdentifiersIncludeLevelAndLowIds() {
        let levelId = UUID()
        let lowId = UUID()
        let accessory = makeAccessory(name: "Sensor", services: [
            makeService(name: "Sensor", levelId: levelId, lowId: lowId)
        ])

        let item = BatteriesMenuItem(accessories: [accessory], bridge: nil)

        XCTAssertEqual(Set(item?.characteristicIdentifiers ?? []), [levelId, lowId])
    }

    // MARK: - Sorting

    // Rows re-sort as levels arrive: lowest battery first, so devices that
    // need charging surface at the top.
    func testRowsSortByLevelAscendingAsValuesArrive() {
        let ids = (0..<3).map { _ in UUID() }
        let accessories = [
            makeAccessory(name: "Doorbell", services: [makeService(name: "Doorbell", levelId: ids[0])]),
            makeAccessory(name: "Lock", services: [makeService(name: "Lock", levelId: ids[1])]),
            makeAccessory(name: "Remote", services: [makeService(name: "Remote", levelId: ids[2])])
        ]

        let item = BatteriesMenuItem(accessories: accessories, bridge: nil)
        item?.updateValue(for: ids[0], value: 80, isLocalChange: false)
        item?.updateValue(for: ids[1], value: 15, isLocalChange: false)
        item?.updateValue(for: ids[2], value: 50, isLocalChange: false)

        XCTAssertEqual(item?.orderedDeviceNames, ["Lock", "Remote", "Doorbell"])
    }

    func testDevicesWithoutKnownLevelSortLast() {
        let ids = (0..<2).map { _ in UUID() }
        let accessories = [
            makeAccessory(name: "Alpha", services: [makeService(name: "Alpha", levelId: ids[0])]),
            makeAccessory(name: "Beta", services: [makeService(name: "Beta", levelId: ids[1])])
        ]

        let item = BatteriesMenuItem(accessories: accessories, bridge: nil)
        // Only Beta has reported a level; Alpha (unknown) must sink below it.
        item?.updateValue(for: ids[1], value: 90, isLocalChange: false)

        XCTAssertEqual(item?.orderedDeviceNames, ["Beta", "Alpha"])
    }
}
