//
//  CloudSyncTranslatorShortcutsTests.swift
//  macOSBridgeTests
//
//  Tests for shortcuts translation including group shortcuts
//

import XCTest
@testable import macOSBridge

final class CloudSyncTranslatorShortcutsTests: CloudSyncTranslatorTestCase {

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

    func testTranslateShortcutsFromInvalidData() {
        translator.updateMenuData(makeMenuData())
        let invalidData = "not json".data(using: .utf8)!

        let result = translator.translateShortcutsFromCloud(invalidData)

        XCTAssertNil(result)
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
}
