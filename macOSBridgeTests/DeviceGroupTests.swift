//
//  DeviceGroupTests.swift
//  macOSBridgeTests
//
//  Tests for DeviceGroup model
//

import XCTest
@testable import macOSBridge

final class DeviceGroupTests: XCTestCase {

    // MARK: - Initialization tests

    func testInitWithDefaults() {
        let group = DeviceGroup(name: "Test Group")

        XCTAssertFalse(group.id.isEmpty)
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertEqual(group.icon, "folder")
        XCTAssertTrue(group.deviceIds.isEmpty)
    }

    func testInitWithCustomValues() {
        let group = DeviceGroup(
            id: "custom-id",
            name: "Living Room",
            icon: "lightbulb",
            deviceIds: ["device1", "device2"]
        )

        XCTAssertEqual(group.id, "custom-id")
        XCTAssertEqual(group.name, "Living Room")
        XCTAssertEqual(group.icon, "lightbulb")
        XCTAssertEqual(group.deviceIds, ["device1", "device2"])
    }

    func testIdIsUniqueByDefault() {
        let group1 = DeviceGroup(name: "Group 1")
        let group2 = DeviceGroup(name: "Group 2")

        XCTAssertNotEqual(group1.id, group2.id)
    }

    // MARK: - Codable tests

    func testEncodeDecode() throws {
        let original = DeviceGroup(
            id: "test-id",
            name: "Test Group",
            icon: "fan",
            deviceIds: ["a", "b", "c"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceGroup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.icon, original.icon)
        XCTAssertEqual(decoded.deviceIds, original.deviceIds)
    }

    func testEncodeDecodeArray() throws {
        let groups = [
            DeviceGroup(id: "1", name: "Group 1", icon: "lightbulb", deviceIds: ["a"]),
            DeviceGroup(id: "2", name: "Group 2", icon: "fan", deviceIds: ["b", "c"])
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(groups)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([DeviceGroup].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].id, "1")
        XCTAssertEqual(decoded[1].id, "2")
    }

    // MARK: - Mutability tests

    func testNameCanBeChanged() {
        var group = DeviceGroup(name: "Original")
        group.name = "Updated"
        XCTAssertEqual(group.name, "Updated")
    }

    func testIconCanBeChanged() {
        var group = DeviceGroup(name: "Test")
        group.icon = "lightbulb"
        XCTAssertEqual(group.icon, "lightbulb")
    }

    func testDeviceIdsCanBeChanged() {
        var group = DeviceGroup(name: "Test", deviceIds: ["a"])
        group.deviceIds.append("b")
        XCTAssertEqual(group.deviceIds, ["a", "b"])
    }

    // MARK: - Identifiable tests

    func testIdentifiable() {
        let group = DeviceGroup(id: "my-id", name: "Test")
        XCTAssertEqual(group.id, "my-id")
    }
}
