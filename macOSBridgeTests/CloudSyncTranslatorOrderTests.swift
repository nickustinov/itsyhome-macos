//
//  CloudSyncTranslatorOrderTests.swift
//  macOSBridgeTests
//
//  Tests for room and scene order translation
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorOrderTests: CloudSyncTranslatorTestCase {

    // MARK: - Room order translation

    func testRoomOrderTranslateIdsToStable() {
        let roomA = UUID()
        let roomB = UUID()
        let roomC = UUID()
        let data = makeMenuData(rooms: [
            RoomData(uniqueIdentifier: roomA, name: "Kitchen"),
            RoomData(uniqueIdentifier: roomB, name: "Bedroom"),
            RoomData(uniqueIdentifier: roomC, name: "Living Room")
        ])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable(
            [roomB.uuidString, roomC.uuidString, roomA.uuidString],
            type: .room
        )

        XCTAssertEqual(result, ["Bedroom", "Living Room", "Kitchen"])
    }

    func testRoomOrderTranslateStableToIds() {
        let roomA = UUID()
        let roomB = UUID()
        let data = makeMenuData(rooms: [
            RoomData(uniqueIdentifier: roomA, name: "Kitchen"),
            RoomData(uniqueIdentifier: roomB, name: "Bedroom")
        ])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Bedroom", "Kitchen"], type: .room)

        XCTAssertEqual(result, [roomB.uuidString, roomA.uuidString])
    }

    func testRoomOrderRoundTrip() {
        let roomA = UUID()
        let roomB = UUID()
        let roomC = UUID()
        let data = makeMenuData(rooms: [
            RoomData(uniqueIdentifier: roomA, name: "Kitchen"),
            RoomData(uniqueIdentifier: roomB, name: "Bedroom"),
            RoomData(uniqueIdentifier: roomC, name: "Living Room")
        ])
        translator.updateMenuData(data)

        let ids = [roomC.uuidString, roomA.uuidString, roomB.uuidString]
        let stableNames = translator.translateIdsToStable(ids, type: .room)
        let backToIds = translator.translateStableToIds(stableNames, type: .room)

        XCTAssertEqual(backToIds, ids)
    }

    func testRoomOrderCrossDeviceTranslation() {
        let mac1RoomA = UUID()
        let mac1RoomB = UUID()
        let mac1Data = makeMenuData(rooms: [
            RoomData(uniqueIdentifier: mac1RoomA, name: "Kitchen"),
            RoomData(uniqueIdentifier: mac1RoomB, name: "Bedroom")
        ])
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        let stableNames = mac1Translator.translateIdsToStable(
            [mac1RoomB.uuidString, mac1RoomA.uuidString],
            type: .room
        )

        // Mac 2 has different UUIDs for the same rooms
        let mac2RoomA = UUID()
        let mac2RoomB = UUID()
        let mac2Data = makeMenuData(rooms: [
            RoomData(uniqueIdentifier: mac2RoomA, name: "Kitchen"),
            RoomData(uniqueIdentifier: mac2RoomB, name: "Bedroom")
        ])
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        let mac2Ids = mac2Translator.translateStableToIds(stableNames, type: .room)

        XCTAssertEqual(mac2Ids, [mac2RoomB.uuidString, mac2RoomA.uuidString])
    }

    func testRoomOrderUnknownRoomsDropped() {
        let roomA = UUID()
        let data = makeMenuData(rooms: [
            RoomData(uniqueIdentifier: roomA, name: "Kitchen")
        ])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Kitchen", "Nonexistent"], type: .room)

        XCTAssertEqual(result, [roomA.uuidString])
    }

    // MARK: - Scene order translation

    func testSceneOrderTranslateIdsToStable() {
        let sceneA = UUID()
        let sceneB = UUID()
        let sceneC = UUID()
        let data = makeMenuData(scenes: [
            SceneData(uniqueIdentifier: sceneA, name: "Good Morning"),
            SceneData(uniqueIdentifier: sceneB, name: "Good Night"),
            SceneData(uniqueIdentifier: sceneC, name: "Movie Time")
        ])
        translator.updateMenuData(data)

        let result = translator.translateIdsToStable(
            [sceneC.uuidString, sceneA.uuidString, sceneB.uuidString],
            type: .scene
        )

        XCTAssertEqual(result, ["Movie Time", "Good Morning", "Good Night"])
    }

    func testSceneOrderTranslateStableToIds() {
        let sceneA = UUID()
        let sceneB = UUID()
        let data = makeMenuData(scenes: [
            SceneData(uniqueIdentifier: sceneA, name: "Good Morning"),
            SceneData(uniqueIdentifier: sceneB, name: "Good Night")
        ])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Good Night", "Good Morning"], type: .scene)

        XCTAssertEqual(result, [sceneB.uuidString, sceneA.uuidString])
    }

    func testSceneOrderRoundTrip() {
        let sceneA = UUID()
        let sceneB = UUID()
        let sceneC = UUID()
        let data = makeMenuData(scenes: [
            SceneData(uniqueIdentifier: sceneA, name: "Good Morning"),
            SceneData(uniqueIdentifier: sceneB, name: "Good Night"),
            SceneData(uniqueIdentifier: sceneC, name: "Movie Time")
        ])
        translator.updateMenuData(data)

        let ids = [sceneB.uuidString, sceneC.uuidString, sceneA.uuidString]
        let stableNames = translator.translateIdsToStable(ids, type: .scene)
        let backToIds = translator.translateStableToIds(stableNames, type: .scene)

        XCTAssertEqual(backToIds, ids)
    }

    func testSceneOrderCrossDeviceTranslation() {
        let mac1SceneA = UUID()
        let mac1SceneB = UUID()
        let mac1Data = makeMenuData(scenes: [
            SceneData(uniqueIdentifier: mac1SceneA, name: "Good Morning"),
            SceneData(uniqueIdentifier: mac1SceneB, name: "Good Night")
        ])
        var mac1Translator = CloudSyncTranslator()
        mac1Translator.updateMenuData(mac1Data)

        let stableNames = mac1Translator.translateIdsToStable(
            [mac1SceneB.uuidString, mac1SceneA.uuidString],
            type: .scene
        )

        // Mac 2 has different UUIDs for the same scenes
        let mac2SceneA = UUID()
        let mac2SceneB = UUID()
        let mac2Data = makeMenuData(scenes: [
            SceneData(uniqueIdentifier: mac2SceneA, name: "Good Morning"),
            SceneData(uniqueIdentifier: mac2SceneB, name: "Good Night")
        ])
        var mac2Translator = CloudSyncTranslator()
        mac2Translator.updateMenuData(mac2Data)

        let mac2Ids = mac2Translator.translateStableToIds(stableNames, type: .scene)

        XCTAssertEqual(mac2Ids, [mac2SceneB.uuidString, mac2SceneA.uuidString])
    }

    func testSceneOrderUnknownScenesDropped() {
        let sceneA = UUID()
        let data = makeMenuData(scenes: [
            SceneData(uniqueIdentifier: sceneA, name: "Good Morning")
        ])
        translator.updateMenuData(data)

        let result = translator.translateStableToIds(["Good Morning", "Nonexistent"], type: .scene)

        XCTAssertEqual(result, [sceneA.uuidString])
    }
}
