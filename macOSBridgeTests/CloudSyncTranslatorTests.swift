//
//  CloudSyncTranslatorTests.swift
//  macOSBridgeTests
//
//  Tests for CloudSyncTranslator UUID-to-stable-name translation
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorTests: XCTestCase {

    private var translator: CloudSyncTranslator!

    override func setUp() {
        super.setUp()
        translator = CloudSyncTranslator()
    }

    // MARK: - Test helpers

    private func makeService(id: UUID = UUID(), name: String, accessoryName: String, roomId: UUID?) -> ServiceData {
        ServiceData(
            uniqueIdentifier: id,
            name: name,
            serviceType: "lightbulb",
            accessoryName: accessoryName,
            roomIdentifier: roomId
        )
    }

    private func makeAccessory(id: UUID = UUID(), name: String, roomId: UUID?, services: [ServiceData]) -> AccessoryData {
        AccessoryData(
            uniqueIdentifier: id,
            name: name,
            roomIdentifier: roomId,
            services: services,
            isReachable: true
        )
    }

    private func makeMenuData(
        rooms: [RoomData] = [],
        accessories: [AccessoryData] = [],
        scenes: [SceneData] = [],
        cameras: [CameraData] = []
    ) -> MenuData {
        let homeId = UUID()
        return MenuData(
            homes: [HomeData(uniqueIdentifier: homeId, name: "Home", isPrimary: true)],
            rooms: rooms,
            accessories: accessories,
            scenes: scenes,
            selectedHomeId: homeId,
            cameras: cameras
        )
    }

    // MARK: - updateMenuData tests

    func testHasDataIsFalseBeforeUpdate() {
        XCTAssertFalse(translator.hasData)
    }

    func testHasDataIsTrueAfterUpdate() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )

        translator.updateMenuData(data)

        XCTAssertTrue(translator.hasData)
    }

    func testUpdateMenuDataBuildsServiceLookups() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )

        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[serviceId.uuidString], "Bedroom::Lamp::Light")
        XCTAssertEqual(translator.stableToServiceId["Bedroom::Lamp::Light"], serviceId.uuidString)
    }

    func testUpdateMenuDataBuildsSceneLookups() {
        let sceneId = UUID()
        let data = makeMenuData(
            scenes: [SceneData(uniqueIdentifier: sceneId, name: "Good Night")]
        )

        translator.updateMenuData(data)

        XCTAssertEqual(translator.sceneIdToName[sceneId.uuidString], "Good Night")
        XCTAssertEqual(translator.sceneNameToId["Good Night"], sceneId.uuidString)
    }

    func testUpdateMenuDataBuildsRoomLookups() {
        let roomId = UUID()
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Living Room")]
        )

        translator.updateMenuData(data)

        XCTAssertEqual(translator.roomIdToName[roomId.uuidString], "Living Room")
        XCTAssertEqual(translator.roomNameToId["Living Room"], roomId.uuidString)
    }

    func testUpdateMenuDataHandlesMultipleServicesPerAccessory() {
        let roomId = UUID()
        let lightId = UUID()
        let fanId = UUID()
        let light = makeService(id: lightId, name: "Light", accessoryName: "Combo", roomId: roomId)
        let fan = makeService(id: fanId, name: "Fan", accessoryName: "Combo", roomId: roomId)
        let accessory = makeAccessory(name: "Combo", roomId: roomId, services: [light, fan])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )

        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[lightId.uuidString], "Bedroom::Combo::Light")
        XCTAssertEqual(translator.serviceIdToStable[fanId.uuidString], "Bedroom::Combo::Fan")
    }

    func testUpdateMenuDataHandlesSameNameDifferentRooms() {
        let room1Id = UUID()
        let room2Id = UUID()
        let service1Id = UUID()
        let service2Id = UUID()
        let service1 = makeService(id: service1Id, name: "Light", accessoryName: "Lamp", roomId: room1Id)
        let service2 = makeService(id: service2Id, name: "Light", accessoryName: "Lamp", roomId: room2Id)
        let accessory1 = makeAccessory(name: "Lamp", roomId: room1Id, services: [service1])
        let accessory2 = makeAccessory(name: "Lamp", roomId: room2Id, services: [service2])
        let data = makeMenuData(
            rooms: [
                RoomData(uniqueIdentifier: room1Id, name: "Bedroom"),
                RoomData(uniqueIdentifier: room2Id, name: "Kitchen")
            ],
            accessories: [accessory1, accessory2]
        )

        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[service1Id.uuidString], "Bedroom::Lamp::Light")
        XCTAssertEqual(translator.serviceIdToStable[service2Id.uuidString], "Kitchen::Lamp::Light")
        XCTAssertNotEqual(
            translator.serviceIdToStable[service1Id.uuidString],
            translator.serviceIdToStable[service2Id.uuidString]
        )
    }

    func testUpdateMenuDataHandlesMissingRoom() {
        let serviceId = UUID()
        let unknownRoomId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: unknownRoomId)
        let accessory = makeAccessory(name: "Lamp", roomId: unknownRoomId, services: [service])
        let data = makeMenuData(accessories: [accessory])

        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[serviceId.uuidString], "Unknown::Lamp::Light")
    }

    func testUpdateMenuDataHandlesNilRoomIdentifier() {
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: nil)
        let accessory = makeAccessory(name: "Lamp", roomId: nil, services: [service])
        let data = makeMenuData(accessories: [accessory])

        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[serviceId.uuidString], "Unknown::Lamp::Light")
    }

    func testUpdateMenuDataHandlesSpacesInNames() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Ceiling Light", accessoryName: "Smart Lamp Pro", roomId: roomId)
        let accessory = makeAccessory(name: "Smart Lamp Pro", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Living Room")],
            accessories: [accessory]
        )

        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[serviceId.uuidString], "Living Room::Smart Lamp Pro::Ceiling Light")
        XCTAssertEqual(translator.stableToServiceId["Living Room::Smart Lamp Pro::Ceiling Light"], serviceId.uuidString)
    }

    func testUpdateMenuDataClearsPreviousData() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data1 = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data1)

        // Update with empty data
        let data2 = makeMenuData()
        translator.updateMenuData(data2)

        XCTAssertFalse(translator.hasData)
        XCTAssertNil(translator.serviceIdToStable[serviceId.uuidString])
    }

    // MARK: - translateIdsToStable tests

    func testTranslateServiceIdsToStable() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([serviceId.uuidString], type: .service)

        XCTAssertEqual(result, ["Bedroom::Lamp::Light"])
    }

    func testTranslateServiceTypeAlsoMatchesScenes() {
        let sceneId = UUID()
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            scenes: [SceneData(uniqueIdentifier: sceneId, name: "Good Night")]
        )
        translator.updateMenuData(data)

        // orderedFavouriteIds can contain both service and scene IDs
        let result = translator.translateIdsToStable(
            [serviceId.uuidString, sceneId.uuidString],
            type: .service
        )

        XCTAssertEqual(result, ["Bedroom::Lamp::Light", "Good Night"])
    }

    func testTranslateSceneIdsToStable() {
        let sceneId = UUID()
        let data = makeMenuData(scenes: [SceneData(uniqueIdentifier: sceneId, name: "Movie Time")])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([sceneId.uuidString], type: .scene)

        XCTAssertEqual(result, ["Movie Time"])
    }

    func testTranslateRoomIdsToStable() {
        let roomId = UUID()
        let data = makeMenuData(rooms: [RoomData(uniqueIdentifier: roomId, name: "Kitchen")])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([roomId.uuidString], type: .room)

        XCTAssertEqual(result, ["Kitchen"])
    }

    func testTranslateUnknownIdsAreDropped() {
        let data = makeMenuData()
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([UUID().uuidString, UUID().uuidString], type: .service)

        XCTAssertTrue(result.isEmpty)
    }

    func testTranslatePreservesOrder() {
        let roomId = UUID()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let s1 = makeService(id: id1, name: "Light A", accessoryName: "Lamp", roomId: roomId)
        let s2 = makeService(id: id2, name: "Light B", accessoryName: "Lamp", roomId: roomId)
        let s3 = makeService(id: id3, name: "Light C", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [s1, s2, s3])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Room")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable(
            [id3.uuidString, id1.uuidString, id2.uuidString],
            type: .service
        )

        XCTAssertEqual(result, ["Room::Lamp::Light C", "Room::Lamp::Light A", "Room::Lamp::Light B"])
    }

    // MARK: - translateStableToIds tests

    func testTranslateStableServiceNamesToIds() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Bedroom::Lamp::Light"], type: .service)

        XCTAssertEqual(result, [serviceId.uuidString])
    }

    func testTranslateStableServiceTypeAlsoMatchesSceneNames() {
        let sceneId = UUID()
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            scenes: [SceneData(uniqueIdentifier: sceneId, name: "Good Night")]
        )
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(
            ["Bedroom::Lamp::Light", "Good Night"],
            type: .service
        )

        XCTAssertEqual(result, [serviceId.uuidString, sceneId.uuidString])
    }

    func testTranslateStableSceneNamesToIds() {
        let sceneId = UUID()
        let data = makeMenuData(scenes: [SceneData(uniqueIdentifier: sceneId, name: "Movie Time")])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Movie Time"], type: .scene)

        XCTAssertEqual(result, [sceneId.uuidString])
    }

    func testTranslateStableRoomNamesToIds() {
        let roomId = UUID()
        let data = makeMenuData(rooms: [RoomData(uniqueIdentifier: roomId, name: "Kitchen")])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Kitchen"], type: .room)

        XCTAssertEqual(result, [roomId.uuidString])
    }

    func testTranslateUnknownStableNamesAreDropped() {
        let data = makeMenuData()
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Unknown::Device::Service"], type: .service)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Round-trip tests

    func testServiceIdRoundTrip() {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let ids = [serviceId.uuidString]
        let stableNames = translator.translateIdsToStable(ids, type: .service)
        let backToIds = translator.translateStableToIds(stableNames, type: .service)

        XCTAssertEqual(backToIds, ids)
    }

    func testSceneIdRoundTrip() {
        let sceneId = UUID()
        let data = makeMenuData(scenes: [SceneData(uniqueIdentifier: sceneId, name: "Relax")])
        translator.updateMenuData(data)

        let ids = [sceneId.uuidString]
        let names = translator.translateIdsToStable(ids, type: .scene)
        let backToIds = translator.translateStableToIds(names, type: .scene)

        XCTAssertEqual(backToIds, ids)
    }

    func testMixedFavouritesRoundTrip() {
        let roomId = UUID()
        let serviceId = UUID()
        let sceneId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            scenes: [SceneData(uniqueIdentifier: sceneId, name: "Relax")]
        )
        translator.updateMenuData(data)

        let ids = [serviceId.uuidString, sceneId.uuidString]
        let stableNames = translator.translateIdsToStable(ids, type: .service)
        let backToIds = translator.translateStableToIds(stableNames, type: .service)

        XCTAssertEqual(backToIds, ids)
    }

    // MARK: - Cross-device simulation

    func testCrossDeviceTranslation() {
        // Mac 1: has its own UUIDs
        let mac1RoomId = UUID()
        let mac1ServiceId = UUID()
        let mac1Service = makeService(id: mac1ServiceId, name: "Light", accessoryName: "Lamp", roomId: mac1RoomId)
        let mac1Accessory = makeAccessory(name: "Lamp", roomId: mac1RoomId, services: [mac1Service])
        let mac1Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: mac1RoomId, name: "Bedroom")],
            accessories: [mac1Accessory]
        )

        // Mac 2: has DIFFERENT UUIDs for the same physical devices
        let mac2RoomId = UUID()
        let mac2ServiceId = UUID()
        let mac2Service = makeService(id: mac2ServiceId, name: "Light", accessoryName: "Lamp", roomId: mac2RoomId)
        let mac2Accessory = makeAccessory(name: "Lamp", roomId: mac2RoomId, services: [mac2Service])
        let mac2Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: mac2RoomId, name: "Bedroom")],
            accessories: [mac2Accessory]
        )

        // Mac 1 translates its ID to stable name
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)
        let stableNames = mac1Translator.translateIdsToStable([mac1ServiceId.uuidString], type: .service)

        // Mac 2 translates stable name back to its local ID
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)
        let mac2Ids = mac2Translator.translateStableToIds(stableNames, type: .service)

        // Mac 2 should get its own UUID, not Mac 1's
        XCTAssertEqual(mac2Ids, [mac2ServiceId.uuidString])
        XCTAssertNotEqual(mac2Ids, [mac1ServiceId.uuidString])
    }

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

    // MARK: - Shortcuts translation tests

    func testTranslateShortcutsToCloud() throws {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let shortcuts: [String: PreferencesManager.ShortcutData] = [
            serviceId.uuidString: PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command)
        ]
        let localData = try JSONEncoder().encode(shortcuts)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: cloudData)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertNotNil(decoded["Bedroom::Lamp::Light"])
        XCTAssertEqual(decoded["Bedroom::Lamp::Light"]?.keyCode, 0)
    }

    func testTranslateShortcutsFromCloud() throws {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let cloudShortcuts: [String: PreferencesManager.ShortcutData] = [
            "Bedroom::Lamp::Light": PreferencesManager.ShortcutData(keyCode: 12, modifiers: .option)
        ]
        let cloudData = try JSONEncoder().encode(cloudShortcuts)

        let localData = translator.translateShortcutsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: localData)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertNotNil(decoded[serviceId.uuidString])
        XCTAssertEqual(decoded[serviceId.uuidString]?.keyCode, 12)
    }

    func testShortcutsRoundTrip() throws {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let original: [String: PreferencesManager.ShortcutData] = [
            serviceId.uuidString: PreferencesManager.ShortcutData(keyCode: 5, modifiers: [.command, .shift])
        ]
        let localData = try JSONEncoder().encode(original)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let roundTripped = translator.translateShortcutsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: roundTripped)

        XCTAssertEqual(decoded[serviceId.uuidString]?.keyCode, 5)
        XCTAssertEqual(decoded[serviceId.uuidString]?.modifiers, original[serviceId.uuidString]?.modifiers)
    }

    func testShortcutsForScenesTranslate() throws {
        let sceneId = UUID()
        let data = makeMenuData(scenes: [SceneData(uniqueIdentifier: sceneId, name: "Relax")])
        translator.updateMenuData(data)

        let shortcuts: [String: PreferencesManager.ShortcutData] = [
            sceneId.uuidString: PreferencesManager.ShortcutData(keyCode: 1, modifiers: .control)
        ]
        let localData = try JSONEncoder().encode(shortcuts)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let cloudDecoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: cloudData)

        XCTAssertNotNil(cloudDecoded["Relax"])

        let roundTripped = translator.translateShortcutsFromCloud(cloudData)!
        let localDecoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: roundTripped)

        XCTAssertEqual(localDecoded[sceneId.uuidString]?.keyCode, 1)
    }

    func testShortcutsDropsUnknownKeys() throws {
        let data = makeMenuData()
        translator.updateMenuData(data)

        let shortcuts: [String: PreferencesManager.ShortcutData] = [
            UUID().uuidString: PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command)
        ]
        let localData = try JSONEncoder().encode(shortcuts)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: cloudData)

        XCTAssertTrue(decoded.isEmpty)
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

    func testTranslateShortcutsFromInvalidData() {
        translator.updateMenuData(makeMenuData())
        let invalidData = "not json".data(using: .utf8)!

        let result = translator.translateShortcutsFromCloud(invalidData)

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

    // MARK: - Empty data tests

    func testTranslateEmptyArrays() {
        translator.updateMenuData(makeMenuData())

        XCTAssertTrue(translator.translateIdsToStable([], type: .service).isEmpty)
        XCTAssertTrue(translator.translateStableToIds([], type: .service).isEmpty)
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

    // MARK: - Group shortcuts translation tests

    func testTranslateGroupShortcutToCloud() throws {
        translator.updateMenuData(makeMenuData())
        translator.updateGroupIds(["g1", "g2"])

        let shortcuts: [String: PreferencesManager.ShortcutData] = [
            "g1": PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command)
        ]
        let localData = try JSONEncoder().encode(shortcuts)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: cloudData)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertNotNil(decoded["group::g1"])
        XCTAssertEqual(decoded["group::g1"]?.keyCode, 0)
    }

    func testTranslateGroupShortcutFromCloud() throws {
        translator.updateMenuData(makeMenuData())

        let cloudShortcuts: [String: PreferencesManager.ShortcutData] = [
            "group::g1": PreferencesManager.ShortcutData(keyCode: 12, modifiers: .option)
        ]
        let cloudData = try JSONEncoder().encode(cloudShortcuts)

        let localData = translator.translateShortcutsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: localData)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertNotNil(decoded["g1"])
        XCTAssertEqual(decoded["g1"]?.keyCode, 12)
    }

    func testGroupShortcutRoundTrip() throws {
        translator.updateMenuData(makeMenuData())
        translator.updateGroupIds(["g1"])

        let original: [String: PreferencesManager.ShortcutData] = [
            "g1": PreferencesManager.ShortcutData(keyCode: 5, modifiers: [.command, .shift])
        ]
        let localData = try JSONEncoder().encode(original)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let roundTripped = translator.translateShortcutsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: roundTripped)

        XCTAssertEqual(decoded["g1"]?.keyCode, 5)
        XCTAssertEqual(decoded["g1"]?.modifiers, original["g1"]?.modifiers)
    }

    func testMixedServiceAndGroupShortcutsRoundTrip() throws {
        let roomId = UUID()
        let serviceId = UUID()
        let sceneId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            scenes: [SceneData(uniqueIdentifier: sceneId, name: "Relax")]
        )
        translator.updateMenuData(data)
        translator.updateGroupIds(["g1"])

        let original: [String: PreferencesManager.ShortcutData] = [
            serviceId.uuidString: PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command),
            sceneId.uuidString: PreferencesManager.ShortcutData(keyCode: 1, modifiers: .option),
            "g1": PreferencesManager.ShortcutData(keyCode: 2, modifiers: .control)
        ]
        let localData = try JSONEncoder().encode(original)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let cloudDecoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: cloudData)

        // Verify cloud format
        XCTAssertNotNil(cloudDecoded["Bedroom::Lamp::Light"])
        XCTAssertNotNil(cloudDecoded["Relax"])
        XCTAssertNotNil(cloudDecoded["group::g1"])

        let roundTripped = translator.translateShortcutsFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: roundTripped)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[serviceId.uuidString]?.keyCode, 0)
        XCTAssertEqual(decoded[sceneId.uuidString]?.keyCode, 1)
        XCTAssertEqual(decoded["g1"]?.keyCode, 2)
    }

    func testGroupShortcutNotTranslatedWithoutGroupId() throws {
        translator.updateMenuData(makeMenuData())
        // Don't register "g1" as a known group ID

        let shortcuts: [String: PreferencesManager.ShortcutData] = [
            "g1": PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command)
        ]
        let localData = try JSONEncoder().encode(shortcuts)

        let cloudData = translator.translateShortcutsToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: cloudData)

        // Unknown IDs are dropped
        XCTAssertTrue(decoded.isEmpty)
    }

    // MARK: - Camera ID translation tests

    func testUpdateMenuDataBuildsCameraLookups() {
        let cameraId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: cameraId, name: "Front Door")])

        translator.updateMenuData(data)

        XCTAssertEqual(translator.cameraIdToName[cameraId.uuidString], "Front Door")
        XCTAssertEqual(translator.cameraNameToId["Front Door"], cameraId.uuidString)
    }

    func testTranslateCameraIdsToStable() {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Backyard")])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([camId.uuidString], type: .camera)

        XCTAssertEqual(result, ["Backyard"])
    }

    func testTranslateStableToCameraIds() {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Backyard")])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Backyard"], type: .camera)

        XCTAssertEqual(result, [camId.uuidString])
    }

    func testCameraIdRoundTrip() {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Garage")])
        translator.updateMenuData(data)

        let ids = [camId.uuidString]
        let names = translator.translateIdsToStable(ids, type: .camera)
        let backToIds = translator.translateStableToIds(names, type: .camera)

        XCTAssertEqual(backToIds, ids)
    }

    func testCameraTranslationPreservesOrder() {
        let cam1 = UUID()
        let cam2 = UUID()
        let cam3 = UUID()
        let data = makeMenuData(cameras: [
            CameraData(uniqueIdentifier: cam1, name: "Front"),
            CameraData(uniqueIdentifier: cam2, name: "Back"),
            CameraData(uniqueIdentifier: cam3, name: "Side")
        ])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable(
            [cam3.uuidString, cam1.uuidString, cam2.uuidString],
            type: .camera
        )

        XCTAssertEqual(result, ["Side", "Front", "Back"])
    }

    func testCameraTranslationDropsUnknownIds() {
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: UUID(), name: "Known")])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable([UUID().uuidString], type: .camera)

        XCTAssertTrue(result.isEmpty)
    }

    func testCameraCrossDeviceTranslation() {
        let mac1CamId = UUID()
        let mac1Data = makeMenuData(cameras: [CameraData(uniqueIdentifier: mac1CamId, name: "Front Door")])
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        let stableNames = mac1Translator.translateIdsToStable([mac1CamId.uuidString], type: .camera)

        let mac2CamId = UUID()
        let mac2Data = makeMenuData(cameras: [CameraData(uniqueIdentifier: mac2CamId, name: "Front Door")])
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        let mac2Ids = mac2Translator.translateStableToIds(stableNames, type: .camera)

        XCTAssertEqual(mac2Ids, [mac2CamId.uuidString])
        XCTAssertNotEqual(mac2Ids, [mac1CamId.uuidString])
    }

    // MARK: - Camera overlay accessories translation tests

    func testTranslateCameraOverlaysToCloud() throws {
        let roomId = UUID()
        let camId = UUID()
        let svcId = UUID()
        let service = makeService(id: svcId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")]
        )
        translator.updateMenuData(data)

        let overlays: [String: [String]] = [camId.uuidString: [svcId.uuidString]]
        let localData = try JSONEncoder().encode(overlays)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: cloudData)

        XCTAssertEqual(decoded["Hallway"], ["Bedroom::Lamp::Light"])
    }

    func testTranslateCameraOverlaysFromCloud() throws {
        let roomId = UUID()
        let camId = UUID()
        let svcId = UUID()
        let service = makeService(id: svcId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")]
        )
        translator.updateMenuData(data)

        let cloudOverlays: [String: [String]] = ["Hallway": ["Bedroom::Lamp::Light"]]
        let cloudData = try JSONEncoder().encode(cloudOverlays)

        let localData = translator.translateCameraOverlaysFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: localData)

        XCTAssertEqual(decoded[camId.uuidString], [svcId.uuidString])
    }

    func testCameraOverlaysRoundTrip() throws {
        let roomId = UUID()
        let camId = UUID()
        let svc1Id = UUID()
        let svc2Id = UUID()
        let s1 = makeService(id: svc1Id, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let s2 = makeService(id: svc2Id, name: "Fan", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [s1, s2])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory],
            cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")]
        )
        translator.updateMenuData(data)

        let original: [String: [String]] = [camId.uuidString: [svc1Id.uuidString, svc2Id.uuidString]]
        let localData = try JSONEncoder().encode(original)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let roundTripped = translator.translateCameraOverlaysFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: roundTripped)

        XCTAssertEqual(decoded[camId.uuidString], [svc1Id.uuidString, svc2Id.uuidString])
    }

    func testCameraOverlaysDropsUnknownCamera() throws {
        let roomId = UUID()
        let svcId = UUID()
        let service = makeService(id: svcId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
            // No cameras
        )
        translator.updateMenuData(data)

        let overlays: [String: [String]] = [UUID().uuidString: [svcId.uuidString]]
        let localData = try JSONEncoder().encode(overlays)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: cloudData)

        XCTAssertTrue(decoded.isEmpty)
    }

    func testCameraOverlaysDropsUnknownServices() throws {
        let camId = UUID()
        let data = makeMenuData(cameras: [CameraData(uniqueIdentifier: camId, name: "Hallway")])
        translator.updateMenuData(data)

        let overlays: [String: [String]] = [camId.uuidString: [UUID().uuidString]]
        let localData = try JSONEncoder().encode(overlays)

        let cloudData = translator.translateCameraOverlaysToCloud(localData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: cloudData)

        // Camera with no translatable services is dropped
        XCTAssertTrue(decoded.isEmpty)
    }

    func testCameraOverlaysCrossDevice() throws {
        let roomId1 = UUID()
        let mac1CamId = UUID()
        let mac1SvcId = UUID()
        let mac1Service = makeService(id: mac1SvcId, name: "Light", accessoryName: "Lamp", roomId: roomId1)
        let mac1Acc = makeAccessory(name: "Lamp", roomId: roomId1, services: [mac1Service])
        let mac1Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId1, name: "Bedroom")],
            accessories: [mac1Acc],
            cameras: [CameraData(uniqueIdentifier: mac1CamId, name: "Hallway")]
        )
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        let overlays: [String: [String]] = [mac1CamId.uuidString: [mac1SvcId.uuidString]]
        let localData = try JSONEncoder().encode(overlays)
        let cloudData = mac1Translator.translateCameraOverlaysToCloud(localData)!

        // Mac 2 has different UUIDs
        let roomId2 = UUID()
        let mac2CamId = UUID()
        let mac2SvcId = UUID()
        let mac2Service = makeService(id: mac2SvcId, name: "Light", accessoryName: "Lamp", roomId: roomId2)
        let mac2Acc = makeAccessory(name: "Lamp", roomId: roomId2, services: [mac2Service])
        let mac2Data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId2, name: "Bedroom")],
            accessories: [mac2Acc],
            cameras: [CameraData(uniqueIdentifier: mac2CamId, name: "Hallway")]
        )
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        let mac2LocalData = mac2Translator.translateCameraOverlaysFromCloud(cloudData)!
        let decoded = try JSONDecoder().decode([String: [String]].self, from: mac2LocalData)

        XCTAssertEqual(decoded[mac2CamId.uuidString], [mac2SvcId.uuidString])
    }

    func testCameraOverlaysFromInvalidData() {
        translator.updateMenuData(makeMenuData())
        let invalidData = "not json".data(using: .utf8)!

        XCTAssertNil(translator.translateCameraOverlaysToCloud(invalidData))
        XCTAssertNil(translator.translateCameraOverlaysFromCloud(invalidData))
    }
}
