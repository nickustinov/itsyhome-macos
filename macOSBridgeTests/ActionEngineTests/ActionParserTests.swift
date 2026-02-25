//
//  ActionParserTests.swift
//  macOSBridgeTests
//
//  Tests for ActionParser
//

import XCTest
@testable import macOSBridge

final class ActionParserTests: XCTestCase {

    // MARK: - Toggle command tests

    func testParseToggle() {
        let result = ActionParser.parse("toggle light.bedroom")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "light.bedroom")
            XCTAssertEqual(command.action, .toggle)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseToggleCaseInsensitive() {
        let result = ActionParser.parse("TOGGLE Light.Bedroom")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "light.bedroom")
            XCTAssertEqual(command.action, .toggle)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - On/off shorthand tests

    func testParseOnShorthand() {
        let result = ActionParser.parse("on light.bedroom")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "light.bedroom")
            XCTAssertEqual(command.action, .turnOn)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseOffShorthand() {
        let result = ActionParser.parse("off all lights")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "all lights")
            XCTAssertEqual(command.action, .turnOff)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Turn on/off tests

    func testParseTurnOn() {
        let result = ActionParser.parse("turn on bedroom light")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom light")
            XCTAssertEqual(command.action, .turnOn)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseTurnOff() {
        let result = ActionParser.parse("turn off all lights")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "all lights")
            XCTAssertEqual(command.action, .turnOff)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Set brightness tests

    func testParseSetBrightness() {
        let result = ActionParser.parse("set brightness 50 bedroom light")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom light")
            XCTAssertEqual(command.action, .setBrightness(50))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseSetBrightnessInvalidValue() {
        let result = ActionParser.parse("set brightness abc bedroom light")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .invalidValue("abc"))
        }
    }

    // MARK: - Set position tests

    func testParseSetPosition() {
        let result = ActionParser.parse("set position 75 living room blinds")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "living room blinds")
            XCTAssertEqual(command.action, .setPosition(75))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Set temperature tests

    func testParseSetTemperature() {
        let result = ActionParser.parse("set temperature 22 thermostat")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "thermostat")
            XCTAssertEqual(command.action, .setTargetTemp(22.0))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseSetTempWithDecimal() {
        let result = ActionParser.parse("set temp 22.5 bedroom thermostat")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom thermostat")
            XCTAssertEqual(command.action, .setTargetTemp(22.5))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Set color tests

    func testParseSetColor() {
        let result = ActionParser.parse("set color 120 100 bedroom light")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom light")
            XCTAssertEqual(command.action, .setColor(hue: 120, saturation: 100))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Set color temp tests

    func testParseSetColorTemp() {
        let result = ActionParser.parse("set colortemp 300 bedroom light")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom light")
            XCTAssertEqual(command.action, .setColorTemp(mired: 300))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Set mode tests

    func testParseSetModeHeat() {
        let result = ActionParser.parse("set mode heat thermostat")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "thermostat")
            XCTAssertEqual(command.action, .setMode(.heat))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseSetModeCool() {
        let result = ActionParser.parse("set mode cool bedroom ac")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom ac")
            XCTAssertEqual(command.action, .setMode(.cool))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseSetModeAuto() {
        let result = ActionParser.parse("set mode auto thermostat")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.action, .setMode(.auto))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseSetModeOff() {
        let result = ActionParser.parse("set mode off thermostat")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.action, .setMode(.off))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Lock/unlock tests

    func testParseLock() {
        let result = ActionParser.parse("lock front door")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "front door")
            XCTAssertEqual(command.action, .lock)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseUnlock() {
        let result = ActionParser.parse("unlock back door")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "back door")
            XCTAssertEqual(command.action, .unlock)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Arm/disarm tests

    func testParseArmStay() {
        let result = ActionParser.parse("arm stay room/alarm")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "room/alarm")
            XCTAssertEqual(command.action, .arm(.stay))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseArmAway() {
        let result = ActionParser.parse("arm away room/alarm")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "room/alarm")
            XCTAssertEqual(command.action, .arm(.away))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseArmNight() {
        let result = ActionParser.parse("arm night room/alarm")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "room/alarm")
            XCTAssertEqual(command.action, .arm(.night))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseArmInvalidMode() {
        let result = ActionParser.parse("arm party room/alarm")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .invalidValue("party"))
        }
    }

    func testParseDisarm() {
        let result = ActionParser.parse("disarm room/alarm")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "room/alarm")
            XCTAssertEqual(command.action, .disarm)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseDisarmMissingTarget() {
        let result = ActionParser.parse("disarm")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .missingTarget)
        }
    }

    // MARK: - Open/close tests

    func testParseOpen() {
        let result = ActionParser.parse("open garage door")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "garage door")
            XCTAssertEqual(command.action, .setPosition(100))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseClose() {
        let result = ActionParser.parse("close bedroom blinds")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom blinds")
            XCTAssertEqual(command.action, .setPosition(0))
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Scene command tests

    func testParseExecuteScene() {
        let result = ActionParser.parse("execute scene goodnight")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "scene.goodnight")
            XCTAssertEqual(command.action, .executeScene)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseExecuteSceneWithoutPrefix() {
        let result = ActionParser.parse("execute goodnight")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "scene.goodnight")
            XCTAssertEqual(command.action, .executeScene)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseRunScene() {
        let result = ActionParser.parse("run good morning")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "scene.good morning")
            XCTAssertEqual(command.action, .executeScene)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseActivateScene() {
        let result = ActionParser.parse("activate movie time")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "scene.movie time")
            XCTAssertEqual(command.action, .executeScene)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Implicit toggle tests

    func testParseImplicitToggle() {
        let result = ActionParser.parse("bedroom light")

        switch result {
        case .success(let command):
            XCTAssertEqual(command.target, "bedroom light")
            XCTAssertEqual(command.action, .toggle)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Error tests

    func testParseEmptyCommand() {
        let result = ActionParser.parse("")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .emptyCommand)
        }
    }

    func testParseWhitespaceOnlyCommand() {
        let result = ActionParser.parse("   ")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .emptyCommand)
        }
    }

    func testParseToggleMissingTarget() {
        let result = ActionParser.parse("toggle")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .missingTarget)
        }
    }

    func testParseTurnInvalidDirection() {
        let result = ActionParser.parse("turn sideways light")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .unknownAction("turn sideways"))
        }
    }

    func testParseSetUnknownProperty() {
        let result = ActionParser.parse("set volume 50 speaker")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .unknownAction("set volume"))
        }
    }
}
