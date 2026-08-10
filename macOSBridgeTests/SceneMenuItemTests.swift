//
//  SceneMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for SceneMenuItem scene deactivation logic
//

import XCTest
@testable import macOSBridge

final class SceneMenuItemTests: XCTestCase {

    // MARK: - Test helpers

    private func action(type: String, target: Double) -> SceneActionData {
        SceneActionData(characteristicId: UUID(), characteristicType: type, targetValue: target)
    }

    // MARK: - Power state (lights, switches, plugs)

    func testPowerStateOnReturnsFalse() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.powerState, target: 1.0))
        XCTAssertEqual(result as? Bool, false)
    }

    func testPowerStateOffReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.powerState, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Active state

    func testActiveOnReturnsFalse() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.active, target: 1.0))
        XCTAssertEqual(result as? Bool, false)
    }

    func testActiveOffReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.active, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Brightness

    func testBrightnessNonZeroReturnsZero() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.brightness, target: 100.0))
        XCTAssertEqual(result as? Int, 0)
    }

    func testBrightnessZeroReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.brightness, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Rotation speed (fans)

    func testRotationSpeedNonZeroReturnsZero() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.rotationSpeed, target: 75.0))
        XCTAssertEqual(result as? Int, 0)
    }

    func testRotationSpeedZeroReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.rotationSpeed, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Target position (blinds)

    func testTargetPositionOpenReturnsZero() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.targetPosition, target: 100.0))
        XCTAssertEqual(result as? Int, 0)
    }

    func testTargetPositionClosedReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.targetPosition, target: 0.0))
        XCTAssertNil(result)
    }

    func testTargetPositionHalfOpenReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.targetPosition, target: 50.0))
        XCTAssertNil(result)
    }

    // MARK: - Lock target state (never unlock)

    func testLockSecuredReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.lockTargetState, target: 1.0))
        XCTAssertNil(result)
    }

    func testLockUnsecuredReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.lockTargetState, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Target door state (garage doors)

    func testDoorOpenReturnsClosed() {
        // targetDoorState: 0 = open, 1 = closed
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.targetDoorState, target: 0.0))
        XCTAssertEqual(result as? Int, 1)
    }

    func testDoorClosedReturnsNil() {
        let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.targetDoorState, target: 1.0))
        XCTAssertNil(result)
    }

    // MARK: - Colour characteristic tolerance (#157)

    func testToleranceForHueAndSaturation() {
        XCTAssertEqual(SceneStateHelper.tolerance(for: CharacteristicTypes.hue), 1.0)
        XCTAssertEqual(SceneStateHelper.tolerance(for: CharacteristicTypes.saturation), 1.0)
    }

    func testColourSceneWithinRoundingToleranceIsActive() {
        let charId = UUID()
        let bridge = SceneStubBridge()
        bridge.values[charId] = 244                       // device reports a rounded int
        let scene = SceneData(uniqueIdentifier: UUID(), name: "Cosy",
                              actions: [SceneActionData(characteristicId: charId,
                                                        characteristicType: CharacteristicTypes.hue,
                                                        targetValue: 244.6013061341441)])  // delta 0.60
        XCTAssertEqual(SceneStateHelper.isActive(scene: scene, bridge: bridge), true)
    }

    func testColourSceneOutsideToleranceIsInactive() {
        let charId = UUID()
        let bridge = SceneStubBridge()
        bridge.values[charId] = 200                       // delta |244.6013 - 200| = 44.6, far above any tolerance
        let scene = SceneData(uniqueIdentifier: UUID(), name: "Cosy",
                              actions: [SceneActionData(characteristicId: charId,
                                                        characteristicType: CharacteristicTypes.hue,
                                                        targetValue: 244.6013061341441)])
        XCTAssertEqual(SceneStateHelper.isActive(scene: scene, bridge: bridge), false)
    }
}

// Minimal Mac2iOS stub so isActive(scene:bridge:) can be driven in tests.
private final class SceneStubBridge: NSObject, Mac2iOS {
    var values: [UUID: Any] = [:]
    var homes: [HomeInfo] = []
    var selectedHomeIdentifier: UUID?
    var rooms: [RoomInfo] = []
    var accessories: [AccessoryInfo] = []
    var scenes: [SceneInfo] = []
    func reloadHomeKit() {}
    func executeScene(identifier: UUID) {}
    func readCharacteristic(identifier: UUID) {}
    func writeCharacteristic(identifier: UUID, value: Any) {}
    func getCharacteristicValue(identifier: UUID) -> Any? { values[identifier] }
    func openCameraWindow() {}
    func closeCameraWindow() {}
    func setCameraWindowHidden(_ hidden: Bool) {}
    func getRawHomeKitDump() -> String? { nil }
    func getCameraDebugJSON(entityId: String?, completion: @escaping (String?) -> Void) { completion(nil) }
}
