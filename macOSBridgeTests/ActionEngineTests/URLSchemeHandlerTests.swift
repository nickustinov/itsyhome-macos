//
//  URLSchemeHandlerTests.swift
//  macOSBridgeTests
//
//  Tests for URLSchemeHandler
//

import XCTest
@testable import macOSBridge

final class URLSchemeHandlerTests: XCTestCase {

    // MARK: - Simple action tests

    func testHandleToggle() {
        let url = URL(string: "itsyhome://toggle/Office/Spotlights")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "toggle Office/Spotlights")
    }

    func testHandleOn() {
        let url = URL(string: "itsyhome://on/Kitchen/Light")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "on Kitchen/Light")
    }

    func testHandleOff() {
        let url = URL(string: "itsyhome://off/Living%20Room/Lamp")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "off Living Room/Lamp")
    }

    func testHandleLock() {
        let url = URL(string: "itsyhome://lock/Front%20Door")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "lock Front Door")
    }

    func testHandleUnlock() {
        let url = URL(string: "itsyhome://unlock/Back%20Door")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "unlock Back Door")
    }

    func testHandleOpen() {
        let url = URL(string: "itsyhome://open/Garage/Door")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "open Garage/Door")
    }

    func testHandleClose() {
        let url = URL(string: "itsyhome://close/Bedroom/Blinds")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "close Bedroom/Blinds")
    }

    // MARK: - Value action tests

    func testHandleBrightness() {
        let url = URL(string: "itsyhome://brightness/50/Bedroom/Lamp")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "set brightness 50 Bedroom/Lamp")
    }

    func testHandlePosition() {
        let url = URL(string: "itsyhome://position/75/Living%20Room/Blinds")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "set position 75 Living Room/Blinds")
    }

    func testHandleTemperature() {
        let url = URL(string: "itsyhome://temp/22/Hallway/Thermostat")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "set temperature 22 Hallway/Thermostat")
    }

    // MARK: - Color action tests

    func testHandleColor() {
        let url = URL(string: "itsyhome://color/120/100/Bedroom/Light")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "set color 120 100 Bedroom/Light")
    }

    // MARK: - Scene action tests

    func testHandleScene() {
        let url = URL(string: "itsyhome://scene/Goodnight")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "execute Goodnight")
    }

    func testHandleSceneWithSpaces() {
        let url = URL(string: "itsyhome://scene/Good%20Morning")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "execute Good Morning")
    }

    // MARK: - Security system action tests

    func testHandleArmStay() {
        let url = URL(string: "itsyhome://arm/stay/Room/Alarm")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "arm stay Room/Alarm")
    }

    func testHandleArmAway() {
        let url = URL(string: "itsyhome://arm/away/Room/Alarm")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "arm away Room/Alarm")
    }

    func testHandleArmNight() {
        let url = URL(string: "itsyhome://arm/night/Room/Alarm")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "arm night Room/Alarm")
    }

    func testHandleDisarm() {
        let url = URL(string: "itsyhome://disarm/Room/Alarm")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "disarm Room/Alarm")
    }

    func testHandleArmNoMode() {
        let url = URL(string: "itsyhome://arm/Room/Alarm")!
        let result = URLSchemeHandler.handle(url)

        // Mode becomes first path component – parses as "arm Room Alarm"
        XCTAssertEqual(result, "arm Room Alarm")
    }

    // MARK: - Device name only tests

    func testHandleToggleDeviceOnly() {
        let url = URL(string: "itsyhome://toggle/Spotlights")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertEqual(result, "toggle Spotlights")
    }

    // MARK: - Invalid URL tests

    func testHandleWrongScheme() {
        let url = URL(string: "otherscheme://toggle/light")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }

    func testHandleEmptyHost() {
        let url = URL(string: "itsyhome:///Office/Spotlights")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }

    func testHandleUnknownAction() {
        let url = URL(string: "itsyhome://unknown/target")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }

    func testHandleSimpleActionMissingTarget() {
        let url = URL(string: "itsyhome://toggle")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }

    func testHandleBrightnessMissingTarget() {
        let url = URL(string: "itsyhome://brightness/50")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }

    func testHandleColorMissingComponents() {
        let url = URL(string: "itsyhome://color/120")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }

    func testHandleSceneMissingName() {
        let url = URL(string: "itsyhome://scene")!
        let result = URLSchemeHandler.handle(url)

        XCTAssertNil(result)
    }
}
