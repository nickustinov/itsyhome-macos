//
//  CloudSyncTranslatorTests.swift
//  macOSBridgeTests
//
//  Core tests for CloudSyncTranslator UUID-to-stable-name translation
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorTests: CloudSyncTranslatorTestCase {

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

    // MARK: - Empty data tests

    func testTranslateEmptyArrays() {
        translator.updateMenuData(makeMenuData())

        XCTAssertTrue(translator.translateIdsToStable([], type: .service).isEmpty)
        XCTAssertTrue(translator.translateStableToIds([], type: .service).isEmpty)
    }
}
