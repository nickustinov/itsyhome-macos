//
//  CloudSyncTranslatorDeviceGroupsTests.swift
//  macOSBridgeTests
//
//  Tests for device groups translation
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorDeviceGroupsTests: CloudSyncTranslatorTestCase {

    // MARK: - Device groups translation tests

    func testTranslateDeviceGroupsToCloud() throws {
        let roomId = UUID()
        let id1 = UUID()
        let id2 = UUID()
        let s1 = makeService(id: id1, name: "Light 1", accessoryName: "Lamp A", roomId: roomId)
        let s2 = makeService(id: id2, name: "Light 2", accessoryName: "Lamp B", roomId: roomId)
        let acc1 = makeAccessory(name: "Lamp A", roomId: roomId, services: [s1])
        let acc2 = makeAccessory(name: "Lamp B", roomId: roomId, services: [s2])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [acc1, acc2]
        )
        translator.updateMenuData(data)

        let groups = [DeviceGroup(id: "g1", name: "All Lights", icon: "lightbulb", deviceIds: [id1.uuidString, id2.uuidString])]
        let localData = try JSONEncoder().encode(groups)

        let cloudData = translator.translateDeviceGroupsToCloud(localData)

        XCTAssertNotNil(cloudData)
        let parsed = try JSONSerialization.jsonObject(with: cloudData!) as! [[String: Any]]
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0]["id"] as? String, "g1")
        XCTAssertEqual(parsed[0]["name"] as? String, "All Lights")
        XCTAssertEqual(parsed[0]["icon"] as? String, "lightbulb")
        let stableIds = parsed[0]["deviceIds"] as! [String]
        XCTAssertTrue(stableIds.contains("Bedroom::Lamp A::Light 1"))
        XCTAssertTrue(stableIds.contains("Bedroom::Lamp B::Light 2"))
    }

    func testTranslateDeviceGroupsFromCloud() throws {
        let roomId = UUID()
        let id1 = UUID()
        let id2 = UUID()
        let s1 = makeService(id: id1, name: "Light 1", accessoryName: "Lamp A", roomId: roomId)
        let s2 = makeService(id: id2, name: "Light 2", accessoryName: "Lamp B", roomId: roomId)
        let acc1 = makeAccessory(name: "Lamp A", roomId: roomId, services: [s1])
        let acc2 = makeAccessory(name: "Lamp B", roomId: roomId, services: [s2])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [acc1, acc2]
        )
        translator.updateMenuData(data)

        let cloudGroups: [[String: Any]] = [
            ["id": "g1", "name": "All Lights", "icon": "lightbulb", "deviceIds": ["Bedroom::Lamp A::Light 1", "Bedroom::Lamp B::Light 2"]]
        ]
        let cloudData = try JSONSerialization.data(withJSONObject: cloudGroups)

        let localData = translator.translateDeviceGroupsFromCloud(cloudData)

        XCTAssertNotNil(localData)
        let decoded = try JSONDecoder().decode([DeviceGroup].self, from: localData!)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].id, "g1")
        XCTAssertEqual(decoded[0].name, "All Lights")
        XCTAssertEqual(decoded[0].deviceIds.count, 2)
        XCTAssertTrue(decoded[0].deviceIds.contains(id1.uuidString))
        XCTAssertTrue(decoded[0].deviceIds.contains(id2.uuidString))
    }

    func testDeviceGroupsRoundTrip() throws {
        let roomId = UUID()
        let id1 = UUID()
        let s1 = makeService(id: id1, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let acc = makeAccessory(name: "Lamp", roomId: roomId, services: [s1])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [acc]
        )
        translator.updateMenuData(data)

        let original = [DeviceGroup(id: "g1", name: "Group", icon: "folder", deviceIds: [id1.uuidString])]
        let localData = try JSONEncoder().encode(original)

        let cloudData = translator.translateDeviceGroupsToCloud(localData)!
        let roundTripped = translator.translateDeviceGroupsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([DeviceGroup].self, from: roundTripped)

        XCTAssertEqual(decoded[0].id, "g1")
        XCTAssertEqual(decoded[0].deviceIds, [id1.uuidString])
    }

    func testDeviceGroupsDropsUnknownDeviceIds() throws {
        let roomId = UUID()
        let knownId = UUID()
        let s1 = makeService(id: knownId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let acc = makeAccessory(name: "Lamp", roomId: roomId, services: [s1])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [acc]
        )
        translator.updateMenuData(data)

        let cloudGroups: [[String: Any]] = [
            ["id": "g1", "name": "Mixed", "icon": "folder", "deviceIds": ["Bedroom::Lamp::Light", "NonExistent::Room::Service"]]
        ]
        let cloudData = try JSONSerialization.data(withJSONObject: cloudGroups)

        let localData = translator.translateDeviceGroupsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([DeviceGroup].self, from: localData)

        XCTAssertEqual(decoded[0].deviceIds.count, 1)
        XCTAssertEqual(decoded[0].deviceIds[0], knownId.uuidString)
    }

    func testDeviceGroupsCrossDevice() throws {
        // Mac 1 setup
        let mac1RoomId = UUID()
        let mac1Id = UUID()
        let mac1Service = makeService(id: mac1Id, name: "Light", accessoryName: "Lamp", roomId: mac1RoomId)
        let mac1Acc = makeAccessory(name: "Lamp", roomId: mac1RoomId, services: [mac1Service])
        let mac1Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: mac1RoomId, name: "Bedroom")],
            accessories: [mac1Acc]
        )
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        // Mac 1 uploads a group
        let groups = [DeviceGroup(id: "g1", name: "Lights", icon: "lightbulb", deviceIds: [mac1Id.uuidString])]
        let localData = try JSONEncoder().encode(groups)
        let cloudData = mac1Translator.translateDeviceGroupsToCloud(localData)!

        // Mac 2 setup (different UUIDs, same device names)
        let mac2RoomId = UUID()
        let mac2Id = UUID()
        let mac2Service = makeService(id: mac2Id, name: "Light", accessoryName: "Lamp", roomId: mac2RoomId)
        let mac2Acc = makeAccessory(name: "Lamp", roomId: mac2RoomId, services: [mac2Service])
        let mac2Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: mac2RoomId, name: "Bedroom")],
            accessories: [mac2Acc]
        )
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        // Mac 2 pulls and translates
        let mac2LocalData = mac2Translator.translateDeviceGroupsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([DeviceGroup].self, from: mac2LocalData)

        XCTAssertEqual(decoded[0].deviceIds, [mac2Id.uuidString])
    }

    // MARK: - Invalid data tests

    func testTranslateDeviceGroupsFromInvalidData() {
        translator.updateMenuData(makeMenuData())
        let invalidData = "not json".data(using: .utf8)!

        let result = translator.translateDeviceGroupsFromCloud(invalidData)

        XCTAssertNil(result)
    }

    func testTranslateDeviceGroupsToCloudFromInvalidData() {
        translator.updateMenuData(makeMenuData())
        let invalidData = "not json".data(using: .utf8)!

        let result = translator.translateDeviceGroupsToCloud(invalidData)

        XCTAssertNil(result)
    }

    func testTranslateDeviceGroupsFromCloudMissingFields() throws {
        translator.updateMenuData(makeMenuData())
        let incompleteGroups: [[String: Any]] = [
            ["id": "g1", "name": "Test"]  // missing icon and deviceIds
        ]
        let cloudData = try JSONSerialization.data(withJSONObject: incompleteGroups)

        let result = translator.translateDeviceGroupsFromCloud(cloudData)

        XCTAssertNotNil(result)
        let decoded = try JSONDecoder().decode([DeviceGroup].self, from: result!)
        XCTAssertTrue(decoded.isEmpty)  // group was dropped due to missing fields
    }

    func testTranslateEmptyDeviceGroups() throws {
        translator.updateMenuData(makeMenuData())
        let emptyGroups: [DeviceGroup] = []
        let data = try JSONEncoder().encode(emptyGroups)

        let cloudData = translator.translateDeviceGroupsToCloud(data)
        XCTAssertNotNil(cloudData)

        let roundTripped = translator.translateDeviceGroupsFromCloud(cloudData!)
        XCTAssertNotNil(roundTripped)
        let decoded = try JSONDecoder().decode([DeviceGroup].self, from: roundTripped!)
        XCTAssertTrue(decoded.isEmpty)
    }
}
