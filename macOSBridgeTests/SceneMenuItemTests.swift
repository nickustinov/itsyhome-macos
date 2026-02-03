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
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.powerState, target: 1.0))
        XCTAssertEqual(result as? Bool, false)
    }

    func testPowerStateOffReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.powerState, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Active state

    func testActiveOnReturnsFalse() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.active, target: 1.0))
        XCTAssertEqual(result as? Bool, false)
    }

    func testActiveOffReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.active, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Brightness

    func testBrightnessNonZeroReturnsZero() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.brightness, target: 100.0))
        XCTAssertEqual(result as? Int, 0)
    }

    func testBrightnessZeroReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.brightness, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Rotation speed (fans)

    func testRotationSpeedNonZeroReturnsZero() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.rotationSpeed, target: 75.0))
        XCTAssertEqual(result as? Int, 0)
    }

    func testRotationSpeedZeroReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.rotationSpeed, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Target position (blinds)

    func testTargetPositionOpenReturnsZero() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.targetPosition, target: 100.0))
        XCTAssertEqual(result as? Int, 0)
    }

    func testTargetPositionClosedReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.targetPosition, target: 0.0))
        XCTAssertNil(result)
    }

    func testTargetPositionHalfOpenReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.targetPosition, target: 50.0))
        XCTAssertNil(result)
    }

    // MARK: - Lock target state (never unlock)

    func testLockSecuredReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.lockTargetState, target: 1.0))
        XCTAssertNil(result)
    }

    func testLockUnsecuredReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.lockTargetState, target: 0.0))
        XCTAssertNil(result)
    }

    // MARK: - Target door state (garage doors)

    func testDoorOpenReturnsClosed() {
        // targetDoorState: 0 = open, 1 = closed
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.targetDoorState, target: 0.0))
        XCTAssertEqual(result as? Int, 1)
    }

    func testDoorClosedReturnsNil() {
        let result = SceneMenuItem.offValue(for: action(type: CharacteristicTypes.targetDoorState, target: 1.0))
        XCTAssertNil(result)
    }
}
