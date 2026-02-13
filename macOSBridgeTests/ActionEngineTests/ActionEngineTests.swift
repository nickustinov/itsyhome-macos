//
//  ActionEngineTests.swift
//  macOSBridgeTests
//
//  Tests for ActionEngine
//

import XCTest
@testable import macOSBridge

final class ActionEngineTests: XCTestCase {

    // MARK: - Test fixtures

    private var engine: ActionEngine!
    private var mockBridge: MockMac2iOS!
    private var testMenuData: MenuData!
    private let lightId = UUID()
    private let powerStateId = UUID()
    private let brightnessId = UUID()
    private let lockId = UUID()
    private let lockTargetStateId = UUID()
    private let sceneId = UUID()

    override func setUp() {
        super.setUp()
        mockBridge = MockMac2iOS()
        engine = ActionEngine(bridge: mockBridge)
        testMenuData = createTestMenuData()
        engine.updateMenuData(testMenuData)
    }

    private func createTestMenuData() -> MenuData {
        let roomId = UUID()

        let light = ServiceData(
            uniqueIdentifier: lightId,
            name: "Room/Test Light",
            serviceType: ServiceTypes.lightbulb,
            accessoryName: "Room/Test Light",
            roomIdentifier: roomId,
            powerStateId: powerStateId,
            brightnessId: brightnessId
        )

        let lock = ServiceData(
            uniqueIdentifier: lockId,
            name: "Room/Test Lock",
            serviceType: ServiceTypes.lock,
            accessoryName: "Room/Test Lock",
            roomIdentifier: roomId,
            lockCurrentStateId: UUID(),
            lockTargetStateId: lockTargetStateId
        )

        let accessories = [
            AccessoryData(
                uniqueIdentifier: UUID(),
                name: "Room/Test Light",
                roomIdentifier: roomId,
                services: [light],
                isReachable: true
            ),
            AccessoryData(
                uniqueIdentifier: UUID(),
                name: "Room/Test Lock",
                roomIdentifier: roomId,
                services: [lock],
                isReachable: true
            )
        ]

        let scenes = [
            SceneData(uniqueIdentifier: sceneId, name: "Test Scene")
        ]

        return MenuData(
            homes: [HomeData(uniqueIdentifier: UUID(), name: "Home", isPrimary: true)],
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Room")],
            accessories: accessories,
            scenes: scenes,
            selectedHomeId: nil
        )
    }

    // MARK: - Bridge unavailable tests

    func testExecuteWithNoBridgeReturnsError() {
        let noBridgeEngine = ActionEngine(bridge: nil)
        noBridgeEngine.updateMenuData(testMenuData)

        let result = noBridgeEngine.execute(target: "Room/Test Light", action: .toggle)

        XCTAssertEqual(result, .error(.bridgeUnavailable))
    }

    func testExecuteWithNoMenuDataReturnsError() {
        let noDataEngine = ActionEngine(bridge: mockBridge)

        let result = noDataEngine.execute(target: "Room/Test Light", action: .toggle)

        XCTAssertEqual(result, .error(.bridgeUnavailable))
    }

    // MARK: - Toggle action tests

    func testToggleWritesPowerState() {
        mockBridge.characteristicValues[powerStateId] = false

        let result = engine.execute(target: "Room/Test Light", action: .toggle)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[powerStateId] as? Bool, true)
    }

    func testToggleInvertsPowerState() {
        mockBridge.characteristicValues[powerStateId] = true

        let result = engine.execute(target: "Room/Test Light", action: .toggle)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[powerStateId] as? Bool, false)
    }

    // MARK: - Turn on/off tests

    func testTurnOnSetsPowerStateTrue() {
        mockBridge.characteristicValues[powerStateId] = false

        let result = engine.execute(target: "Room/Test Light", action: .turnOn)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[powerStateId] as? Bool, true)
    }

    func testTurnOffSetsPowerStateFalse() {
        mockBridge.characteristicValues[powerStateId] = true

        let result = engine.execute(target: "Room/Test Light", action: .turnOff)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[powerStateId] as? Bool, false)
    }

    // MARK: - Brightness tests

    func testSetBrightnessWritesValue() {
        let result = engine.execute(target: "Room/Test Light", action: .setBrightness(75))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[brightnessId] as? Int, 75)
    }

    func testSetBrightnessClampsTooHigh() {
        let result = engine.execute(target: "Room/Test Light", action: .setBrightness(150))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[brightnessId] as? Int, 100)
    }

    func testSetBrightnessClampsTooLow() {
        let result = engine.execute(target: "Room/Test Light", action: .setBrightness(-10))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[brightnessId] as? Int, 0)
    }

    // MARK: - Lock tests

    func testLockWritesLockedState() {
        let result = engine.execute(target: "Room/Test Lock", action: .lock)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[lockTargetStateId] as? Int, 1)
    }

    func testUnlockWritesUnlockedState() {
        let result = engine.execute(target: "Room/Test Lock", action: .unlock)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.writtenCharacteristics[lockTargetStateId] as? Int, 0)
    }

    // MARK: - Scene tests

    func testExecuteSceneCallsBridge() {
        let result = engine.execute(target: "scene.Test Scene", action: .executeScene)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockBridge.executedScenes.count, 1)
        XCTAssertEqual(mockBridge.executedScenes.first, sceneId)
    }

    // MARK: - Error tests

    func testTargetNotFoundReturnsError() {
        let result = engine.execute(target: "Nonexistent Device", action: .toggle)

        if case .error(.targetNotFound(let target)) = result {
            XCTAssertEqual(target, "Nonexistent Device")
        } else {
            XCTFail("Expected targetNotFound error")
        }
    }

    func testUnsupportedActionOnServiceReturnsError() {
        // Trying to set brightness on a lock (which doesn't support it)
        let result = engine.execute(target: "Room/Test Lock", action: .setBrightness(50))

        if case .error(.executionFailed) = result {
            // Expected
        } else {
            XCTFail("Expected executionFailed error")
        }
    }

    // MARK: - Multiple targets tests

    func testExecuteMultipleTargets() {
        mockBridge.characteristicValues[powerStateId] = false

        let result = engine.executeMultiple(targets: ["Room/Test Light"], action: .toggle)

        XCTAssertEqual(result, .success)
    }

    func testExecuteMultipleWithPartialFailure() {
        mockBridge.characteristicValues[powerStateId] = false

        let result = engine.executeMultiple(targets: ["Room/Test Light", "Nonexistent"], action: .toggle)

        if case .partial(let succeeded, let failed) = result {
            XCTAssertEqual(succeeded, 1)
            XCTAssertEqual(failed, 1)
        } else {
            XCTFail("Expected partial result")
        }
    }

    // MARK: - onCharacteristicWrite callback tests

    func testOnCharacteristicWriteCalledOnToggle() {
        mockBridge.characteristicValues[powerStateId] = false
        var writes: [(UUID, Any)] = []
        engine.onCharacteristicWrite = { id, value in
            writes.append((id, value))
        }

        _ = engine.execute(target: "Room/Test Light", action: .toggle)

        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0].0, powerStateId)
        XCTAssertEqual(writes[0].1 as? Bool, true)
    }

    func testOnCharacteristicWriteCalledOnTurnOn() {
        var writes: [(UUID, Any)] = []
        engine.onCharacteristicWrite = { id, value in
            writes.append((id, value))
        }

        _ = engine.execute(target: "Room/Test Light", action: .turnOn)

        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0].0, powerStateId)
        XCTAssertEqual(writes[0].1 as? Bool, true)
    }

    func testOnCharacteristicWriteCalledOnBrightness() {
        var writes: [(UUID, Any)] = []
        engine.onCharacteristicWrite = { id, value in
            writes.append((id, value))
        }

        _ = engine.execute(target: "Room/Test Light", action: .setBrightness(75))

        // Brightness write also writes power state (on), so expect 2 writes
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes[0].0, powerStateId)
        XCTAssertEqual(writes[0].1 as? Bool, true)
        XCTAssertEqual(writes[1].0, brightnessId)
        XCTAssertEqual(writes[1].1 as? Int, 75)
    }

    func testOnCharacteristicWriteCalledOnLock() {
        var writes: [(UUID, Any)] = []
        engine.onCharacteristicWrite = { id, value in
            writes.append((id, value))
        }

        _ = engine.execute(target: "Room/Test Lock", action: .lock)

        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0].0, lockTargetStateId)
        XCTAssertEqual(writes[0].1 as? Int, 1)
    }

    func testOnCharacteristicWriteCalledOnUnlock() {
        var writes: [(UUID, Any)] = []
        engine.onCharacteristicWrite = { id, value in
            writes.append((id, value))
        }

        _ = engine.execute(target: "Room/Test Lock", action: .unlock)

        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0].0, lockTargetStateId)
        XCTAssertEqual(writes[0].1 as? Int, 0)
    }

    func testOnCharacteristicWriteNotCalledForNotFound() {
        var writeCount = 0
        engine.onCharacteristicWrite = { _, _ in
            writeCount += 1
        }

        _ = engine.execute(target: "Nonexistent", action: .toggle)

        XCTAssertEqual(writeCount, 0)
    }

    func testOnCharacteristicWriteNotCalledWhenNil() {
        // Ensure no crash when callback is nil
        engine.onCharacteristicWrite = nil
        mockBridge.characteristicValues[powerStateId] = false

        let result = engine.execute(target: "Room/Test Light", action: .toggle)

        XCTAssertEqual(result, .success)
    }
}

// MARK: - Mock bridge

private class MockMac2iOS: NSObject, Mac2iOS {
    var homes: [HomeInfo] = []
    var selectedHomeIdentifier: UUID?
    var rooms: [RoomInfo] = []
    var accessories: [AccessoryInfo] = []
    var scenes: [SceneInfo] = []

    var characteristicValues: [UUID: Any] = [:]
    var writtenCharacteristics: [UUID: Any] = [:]
    var executedScenes: [UUID] = []

    func reloadHomeKit() {}

    func executeScene(identifier: UUID) {
        executedScenes.append(identifier)
    }

    func readCharacteristic(identifier: UUID) {}

    func writeCharacteristic(identifier: UUID, value: Any) {
        writtenCharacteristics[identifier] = value
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        return characteristicValues[identifier]
    }

    func openCameraWindow() {}
    func closeCameraWindow() {}
    func setCameraWindowHidden(_ hidden: Bool) {}
    func getRawHomeKitDump() -> String? { nil }
}
