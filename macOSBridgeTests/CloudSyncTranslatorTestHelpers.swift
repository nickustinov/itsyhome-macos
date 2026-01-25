//
//  CloudSyncTranslatorTestHelpers.swift
//  macOSBridgeTests
//
//  Shared test helpers for CloudSyncTranslator tests
//

import XCTest
@testable import macOSBridge

// MARK: - Test data factories

enum TestDataFactory {

    static func makeService(id: UUID = UUID(), name: String, accessoryName: String, roomId: UUID?) -> ServiceData {
        ServiceData(
            uniqueIdentifier: id,
            name: name,
            serviceType: "lightbulb",
            accessoryName: accessoryName,
            roomIdentifier: roomId
        )
    }

    static func makeAccessory(id: UUID = UUID(), name: String, roomId: UUID?, services: [ServiceData]) -> AccessoryData {
        AccessoryData(
            uniqueIdentifier: id,
            name: name,
            roomIdentifier: roomId,
            services: services,
            isReachable: true
        )
    }

    static func makeMenuData(
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
}

// MARK: - Base test case

class CloudSyncTranslatorTestCase: XCTestCase {

    var translator: CloudSyncTranslator!

    override func setUp() {
        super.setUp()
        translator = CloudSyncTranslator()
    }

    // Convenience accessors
    func makeService(id: UUID = UUID(), name: String, accessoryName: String, roomId: UUID?) -> ServiceData {
        TestDataFactory.makeService(id: id, name: name, accessoryName: accessoryName, roomId: roomId)
    }

    func makeAccessory(id: UUID = UUID(), name: String, roomId: UUID?, services: [ServiceData]) -> AccessoryData {
        TestDataFactory.makeAccessory(id: id, name: name, roomId: roomId, services: services)
    }

    func makeMenuData(
        rooms: [RoomData] = [],
        accessories: [AccessoryData] = [],
        scenes: [SceneData] = [],
        cameras: [CameraData] = []
    ) -> MenuData {
        TestDataFactory.makeMenuData(rooms: rooms, accessories: accessories, scenes: scenes, cameras: cameras)
    }
}
