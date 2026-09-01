//
//  CloudSyncTranslatorCustomIconsTests.swift
//  macOSBridgeTests
//
//  Tests for custom-icon translation, including the room-name/prefix collision
//  where a service stable name starts with a reserved prefix
//  ("scene::Lamp::Light" for an accessory in a room named "scene").
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorCustomIconsTests: CloudSyncTranslatorTestCase {

    // MARK: - Normal round-trip (regression guard)

    func testServiceIconRoundTripsNormally() throws {
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        let localIcons = try JSONEncoder().encode([serviceId.uuidString: "star"])
        let cloud = translator.translateCustomIconsToCloud(localIcons)!
        let restored = translator.translateCustomIconsFromCloud(cloud)!
        let decoded = try JSONDecoder().decode([String: String].self, from: restored)

        XCTAssertEqual(decoded[serviceId.uuidString], "star")
    }

    // MARK: - The collision: room name matches a reserved prefix

    func testServiceIconRoundTripsWhenRoomNamedLikeScenePrefix() throws {
        // Room literally named "scene" -> the service stable name becomes
        // "scene::Lamp::Light", which collides with the "scene::" namespace
        // used for scene icons. The service icon must still round-trip to the
        // service id, not be dropped.
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "scene")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        // Sanity: the stable name really does start with the reserved prefix.
        XCTAssertEqual(translator.serviceIdToStable[serviceId.uuidString], "scene::Lamp::Light")

        let localIcons = try JSONEncoder().encode([serviceId.uuidString: "star"])
        let cloud = translator.translateCustomIconsToCloud(localIcons)!
        let restored = translator.translateCustomIconsFromCloud(cloud)!
        let decoded = try JSONDecoder().decode([String: String].self, from: restored)

        XCTAssertEqual(decoded[serviceId.uuidString], "star",
                       "service icon was dropped by the scene-prefix branch")
    }

    func testServiceIconRoundTripsWhenRoomNamedLikeRoomPrefix() throws {
        // Room named "room" -> stable "room::Lamp::Light" collides with the
        // "room::" namespace used for room icons.
        let roomId = UUID()
        let serviceId = UUID()
        let service = makeService(id: serviceId, name: "Light", accessoryName: "Lamp", roomId: roomId)
        let accessory = makeAccessory(name: "Lamp", roomId: roomId, services: [service])
        let data = makeMenuData(
            rooms: [RoomData(uniqueIdentifier: roomId, name: "room")],
            accessories: [accessory]
        )
        translator.updateMenuData(data)

        XCTAssertEqual(translator.serviceIdToStable[serviceId.uuidString], "room::Lamp::Light")

        let localIcons = try JSONEncoder().encode([serviceId.uuidString: "sun"])
        let cloud = translator.translateCustomIconsToCloud(localIcons)!
        let restored = translator.translateCustomIconsFromCloud(cloud)!
        let decoded = try JSONDecoder().decode([String: String].self, from: restored)

        XCTAssertEqual(decoded[serviceId.uuidString], "sun")
    }

    // MARK: - Prefix namespaces still decode after the reorder

    func testSceneIconRoundTrips() throws {
        let sceneId = UUID()
        let data = makeMenuData(scenes: [SceneData(uniqueIdentifier: sceneId, name: "Good Night")])
        translator.updateMenuData(data)

        let localIcons = try JSONEncoder().encode([sceneId.uuidString: "moon"])
        let cloud = translator.translateCustomIconsToCloud(localIcons)!
        let restored = translator.translateCustomIconsFromCloud(cloud)!
        let decoded = try JSONDecoder().decode([String: String].self, from: restored)

        XCTAssertEqual(decoded[sceneId.uuidString], "moon")
    }

    func testRoomIconRoundTrips() throws {
        let roomId = UUID()
        let data = makeMenuData(rooms: [RoomData(uniqueIdentifier: roomId, name: "Bedroom")])
        translator.updateMenuData(data)

        let localIcons = try JSONEncoder().encode([roomId.uuidString: "bed"])
        let cloud = translator.translateCustomIconsToCloud(localIcons)!
        let restored = translator.translateCustomIconsFromCloud(cloud)!
        let decoded = try JSONDecoder().decode([String: String].self, from: restored)

        XCTAssertEqual(decoded[roomId.uuidString], "bed")
    }
}
