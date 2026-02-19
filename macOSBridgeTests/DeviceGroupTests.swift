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
        XCTAssertEqual(group.icon, "squares-four")
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

    // MARK: - Room ID tests

    func testInitWithRoomId() {
        let group = DeviceGroup(
            id: "group-1",
            name: "Room Group",
            icon: "lightbulb",
            deviceIds: ["d1", "d2"],
            roomId: "room-123"
        )

        XCTAssertEqual(group.roomId, "room-123")
    }

    func testInitWithoutRoomIdDefaultsNil() {
        let group = DeviceGroup(name: "Global Group")
        XCTAssertNil(group.roomId)
    }

    func testRoomIdCanBeChanged() {
        var group = DeviceGroup(name: "Test")
        XCTAssertNil(group.roomId)

        group.roomId = "room-456"
        XCTAssertEqual(group.roomId, "room-456")

        group.roomId = nil
        XCTAssertNil(group.roomId)
    }

    func testEncodeDecodeWithRoomId() throws {
        let original = DeviceGroup(
            id: "test-id",
            name: "Room Group",
            icon: "fan",
            deviceIds: ["a", "b"],
            roomId: "room-789"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceGroup.self, from: data)

        XCTAssertEqual(decoded.roomId, original.roomId)
    }

    func testEncodeDecodeWithNilRoomId() throws {
        let original = DeviceGroup(
            id: "test-id",
            name: "Global Group",
            icon: "folder",
            deviceIds: ["a"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceGroup.self, from: data)

        XCTAssertNil(decoded.roomId)
    }

    // MARK: - Display options tests

    func testDisplayOptionsDefaults() {
        let group = DeviceGroup(name: "Test")

        XCTAssertTrue(group.showGroupSwitch)
        XCTAssertFalse(group.showAsSubmenu)
    }

    func testDisplayOptionsCustomValues() {
        let group = DeviceGroup(
            name: "Submenu Group",
            showGroupSwitch: false,
            showAsSubmenu: true
        )

        XCTAssertFalse(group.showGroupSwitch)
        XCTAssertTrue(group.showAsSubmenu)
    }

    func testDisplayOptionsBothEnabled() {
        let group = DeviceGroup(
            name: "Both",
            showGroupSwitch: true,
            showAsSubmenu: true
        )

        XCTAssertTrue(group.showGroupSwitch)
        XCTAssertTrue(group.showAsSubmenu)
    }

    func testEncodeDecodeDisplayOptions() throws {
        let original = DeviceGroup(
            id: "test-id",
            name: "Test",
            icon: "fan",
            deviceIds: ["a"],
            showGroupSwitch: false,
            showAsSubmenu: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceGroup.self, from: data)

        XCTAssertEqual(decoded.showGroupSwitch, false)
        XCTAssertEqual(decoded.showAsSubmenu, true)
    }

    func testDecodeWithoutDisplayOptionsUsesDefaults() throws {
        // Simulate JSON from an older version without the new fields
        let json = """
        {"id":"old-id","name":"Old Group","icon":"folder","deviceIds":["x","y"]}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DeviceGroup.self, from: data)

        XCTAssertEqual(decoded.id, "old-id")
        XCTAssertEqual(decoded.name, "Old Group")
        XCTAssertTrue(decoded.showGroupSwitch)
        XCTAssertFalse(decoded.showAsSubmenu)
    }

    func testDisplayOptionsCanBeChanged() {
        var group = DeviceGroup(name: "Test")

        group.showGroupSwitch = false
        group.showAsSubmenu = true

        XCTAssertFalse(group.showGroupSwitch)
        XCTAssertTrue(group.showAsSubmenu)
    }

    // MARK: - Resolve services tests

    private func makeService(id: String, name: String = "Service") -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(uuidString: id) ?? UUID(),
            name: name,
            serviceType: "light",
            accessoryName: name,
            roomIdentifier: nil
        )
    }

    private func makeMenuData(accessories: [AccessoryData]) -> MenuData {
        MenuData(
            homes: [],
            rooms: [],
            accessories: accessories,
            scenes: [],
            selectedHomeId: nil
        )
    }

    func testResolveServicesFindsMatchingDevices() {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let service1 = makeService(id: id1, name: "Light 1")
        let service2 = makeService(id: id2, name: "Light 2")
        let accessory = AccessoryData(
            uniqueIdentifier: UUID().uuidString,
            name: "Acc",
            roomIdentifier: nil,
            services: [service1, service2],
            isReachable: true
        )
        let data = makeMenuData(accessories: [accessory])
        let group = DeviceGroup(name: "Test", deviceIds: [id1, id2])

        let resolved = group.resolveServices(in: data)
        XCTAssertEqual(resolved.count, 2)
    }

    func testResolveServicesHandlesDuplicateServiceIds() {
        let sharedId = UUID().uuidString
        let service1 = makeService(id: sharedId, name: "Light A")
        let service2 = makeService(id: sharedId, name: "Light B")
        let acc1 = AccessoryData(
            uniqueIdentifier: UUID().uuidString,
            name: "Acc1",
            roomIdentifier: nil,
            services: [service1],
            isReachable: true
        )
        let acc2 = AccessoryData(
            uniqueIdentifier: UUID().uuidString,
            name: "Acc2",
            roomIdentifier: nil,
            services: [service2],
            isReachable: true
        )
        let data = makeMenuData(accessories: [acc1, acc2])
        let group = DeviceGroup(name: "Test", deviceIds: [sharedId])

        // Should not crash and should resolve to one service
        let resolved = group.resolveServices(in: data)
        XCTAssertEqual(resolved.count, 1)
    }
}
