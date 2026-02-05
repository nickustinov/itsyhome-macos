//
//  HAModelsTests.swift
//  macOSBridgeTests
//
//  Tests for Home Assistant model parsing
//

import XCTest
@testable import macOSBridge

final class HAModelsTests: XCTestCase {

    // MARK: - HAEntityState tests

    func testEntityStateParsesBasicFields() {
        let json: [String: Any] = [
            "entity_id": "light.kitchen",
            "state": "on",
            "attributes": ["friendly_name": "Kitchen Light"]
        ]

        let state = HAEntityState(json: json)

        XCTAssertNotNil(state)
        XCTAssertEqual(state?.entityId, "light.kitchen")
        XCTAssertEqual(state?.state, "on")
        XCTAssertEqual(state?.friendlyName, "Kitchen Light")
    }

    func testEntityStateDomainExtraction() {
        let json: [String: Any] = [
            "entity_id": "climate.living_room",
            "state": "heat"
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.domain, "climate")
        XCTAssertEqual(state?.objectId, "living_room")
    }

    func testEntityStateReturnNilForInvalidJson() {
        let json: [String: Any] = [
            "entity_id": "light.test"
            // Missing required "state" field
        ]

        let state = HAEntityState(json: json)

        XCTAssertNil(state)
    }

    func testEntityStateFriendlyNameFallback() {
        let json: [String: Any] = [
            "entity_id": "light.living_room_lamp",
            "state": "off",
            "attributes": [:]  // No friendly_name
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.friendlyName, "Living Room Lamp")
    }

    func testEntityStateSupportedFeatures() {
        let json: [String: Any] = [
            "entity_id": "cover.blinds",
            "state": "open",
            "attributes": ["supported_features": 143]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.supportedFeatures, 143)
    }

    func testEntityStateDeviceClass() {
        let json: [String: Any] = [
            "entity_id": "cover.garage",
            "state": "closed",
            "attributes": ["device_class": "garage"]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.deviceClass, "garage")
    }

    // MARK: - Light attribute tests

    func testLightBrightnessAttribute() {
        let json: [String: Any] = [
            "entity_id": "light.bedroom",
            "state": "on",
            "attributes": ["brightness": 200]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.brightness, 200)
        XCTAssertEqual(state?.brightnessPercent, 78)  // 200/255 * 100
    }

    func testLightColorModes() {
        let json: [String: Any] = [
            "entity_id": "light.rgb",
            "state": "on",
            "attributes": [
                "supported_color_modes": ["hs", "color_temp"],
                "color_mode": "hs"
            ]
        ]

        let state = HAEntityState(json: json)

        XCTAssertTrue(state?.supportsColor ?? false)
        XCTAssertTrue(state?.supportsColorTemp ?? false)
        XCTAssertEqual(state?.supportedColorModes, ["hs", "color_temp"])
    }

    func testLightHsColor() {
        let json: [String: Any] = [
            "entity_id": "light.color",
            "state": "on",
            "attributes": [
                "hs_color": [240.0, 100.0]
            ]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.hsColor?.hue, 240.0)
        XCTAssertEqual(state?.hsColor?.saturation, 100.0)
    }

    func testLightColorTemp() {
        let json: [String: Any] = [
            "entity_id": "light.warm",
            "state": "on",
            "attributes": [
                "color_temp_kelvin": 2700,  // ~370 mireds
                "min_color_temp_kelvin": 2000,
                "max_color_temp_kelvin": 6500
            ]
        ]

        let state = HAEntityState(json: json)

        // 1,000,000 / 2700 = 370 mireds
        XCTAssertEqual(state?.colorTempMireds, 370)
    }

    // MARK: - Cover attribute tests

    func testCoverPosition() {
        let json: [String: Any] = [
            "entity_id": "cover.blinds",
            "state": "open",
            "attributes": ["current_position": 75]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.currentPosition, 75)
    }

    func testCoverTiltPosition() {
        let json: [String: Any] = [
            "entity_id": "cover.pergola",
            "state": "open",
            "attributes": ["current_tilt_position": 50]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.currentTiltPosition, 50)
    }

    func testCoverSupportedFeaturesDecoding() {
        // OPEN=1, CLOSE=2, SET_POSITION=4, STOP=8, OPEN_TILT=16, CLOSE_TILT=32, STOP_TILT=64, SET_TILT_POSITION=128
        let json: [String: Any] = [
            "entity_id": "cover.full",
            "state": "open",
            "attributes": ["supported_features": 255]  // All features
        ]

        let state = HAEntityState(json: json)
        let features = state?.supportedFeatures ?? 0

        XCTAssertTrue((features & 1) != 0, "Should support OPEN")
        XCTAssertTrue((features & 2) != 0, "Should support CLOSE")
        XCTAssertTrue((features & 4) != 0, "Should support SET_POSITION")
        XCTAssertTrue((features & 8) != 0, "Should support STOP")
        XCTAssertTrue((features & 128) != 0, "Should support SET_TILT_POSITION")
    }

    func testCoverTiltOnlyFeatures() {
        // Tilt-only cover: OPEN_TILT=16 + CLOSE_TILT=32 + STOP_TILT=64 + SET_TILT_POSITION=128 = 240
        let json: [String: Any] = [
            "entity_id": "cover.pergola",
            "state": "open",
            "attributes": ["supported_features": 240]
        ]

        let state = HAEntityState(json: json)
        let features = state?.supportedFeatures ?? 0

        XCTAssertFalse((features & 4) != 0, "Should NOT support SET_POSITION")
        XCTAssertTrue((features & 128) != 0, "Should support SET_TILT_POSITION")
    }

    // MARK: - Climate attribute tests

    func testClimateTemperatures() {
        let json: [String: Any] = [
            "entity_id": "climate.ac",
            "state": "heat",
            "attributes": [
                "current_temperature": 21.5,
                "temperature": 23.0
            ]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.currentTemperature, 21.5)
        XCTAssertEqual(state?.targetTemperature, 23.0)
    }

    func testClimateHVACModes() {
        let json: [String: Any] = [
            "entity_id": "climate.ac",
            "state": "cool",
            "attributes": [
                "hvac_modes": ["off", "heat", "cool", "heat_cool", "dry", "fan_only"],
                "hvac_action": "cooling"
            ]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.hvacModes, ["off", "heat", "cool", "heat_cool", "dry", "fan_only"])
        XCTAssertEqual(state?.hvacAction, "cooling")
        XCTAssertEqual(state?.hvacMode, "cool")
    }

    func testClimateDualSetpoint() {
        let json: [String: Any] = [
            "entity_id": "climate.hvac",
            "state": "heat_cool",
            "attributes": [
                "target_temp_high": 25.0,
                "target_temp_low": 20.0
            ]
        ]

        let state = HAEntityState(json: json)

        XCTAssertEqual(state?.targetTempHigh, 25.0)
        XCTAssertEqual(state?.targetTempLow, 20.0)
    }

    // MARK: - HAArea tests

    func testAreaParsesBasicFields() {
        let json: [String: Any] = [
            "area_id": "living_room",
            "name": "Living Room"
        ]

        let area = HAArea(json: json)

        XCTAssertNotNil(area)
        XCTAssertEqual(area?.areaId, "living_room")
        XCTAssertEqual(area?.name, "Living Room")
    }

    func testAreaReturnsNilForInvalidJson() {
        let json: [String: Any] = [
            "area_id": "test"
            // Missing "name"
        ]

        let area = HAArea(json: json)

        XCTAssertNil(area)
    }

    // MARK: - HADevice tests

    func testDeviceParsesBasicFields() {
        let json: [String: Any] = [
            "id": "abc123",
            "name": "Smart Bulb",
            "area_id": "bedroom",
            "manufacturer": "Philips",
            "model": "Hue White"
        ]

        let device = HADevice(json: json)

        XCTAssertNotNil(device)
        XCTAssertEqual(device?.id, "abc123")
        XCTAssertEqual(device?.name, "Smart Bulb")
        XCTAssertEqual(device?.areaId, "bedroom")
        XCTAssertEqual(device?.manufacturer, "Philips")
        XCTAssertEqual(device?.model, "Hue White")
    }

    func testDeviceDisabledStatus() {
        let json: [String: Any] = [
            "id": "disabled_device",
            "disabled_by": "user"
        ]

        let device = HADevice(json: json)

        XCTAssertTrue(device?.disabled ?? false)
    }

    // MARK: - HAEntityRegistryEntry tests

    func testEntityRegistryParsesBasicFields() {
        let json: [String: Any] = [
            "entity_id": "light.test",
            "platform": "hue"
        ]

        let entry = HAEntityRegistryEntry(json: json)

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.entityId, "light.test")
        XCTAssertEqual(entry?.platform, "hue")
    }

    func testEntityRegistryHiddenAndDisabled() {
        let json: [String: Any] = [
            "entity_id": "light.hidden",
            "platform": "test",
            "hidden_by": "user",
            "disabled_by": "integration"
        ]

        let entry = HAEntityRegistryEntry(json: json)

        XCTAssertTrue(entry?.hidden ?? false)
        XCTAssertTrue(entry?.disabled ?? false)
    }

    // MARK: - HAEvent tests

    func testEventParsesBasicFields() {
        let json: [String: Any] = [
            "event_type": "state_changed",
            "data": ["entity_id": "light.test"],
            "origin": "LOCAL"
        ]

        let event = HAEvent(json: json)

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.eventType, "state_changed")
        XCTAssertEqual(event?.data["entity_id"] as? String, "light.test")
        XCTAssertEqual(event?.origin, "LOCAL")
    }

    // MARK: - Alarm control panel tests

    func testAlarmSupportedModesAll() {
        // All features enabled: ARM_HOME=1, ARM_AWAY=2, ARM_NIGHT=4, ARM_CUSTOM_BYPASS=16, ARM_VACATION=32
        let json: [String: Any] = [
            "entity_id": "alarm_control_panel.home",
            "state": "disarmed",
            "attributes": ["supported_features": 55]  // 1 + 2 + 4 + 16 + 32
        ]

        let state = HAEntityState(json: json)

        XCTAssertNotNil(state)
        let modes = state!.alarmSupportedModes
        XCTAssertTrue(modes.contains("disarmed"))
        XCTAssertTrue(modes.contains("armed_home"))
        XCTAssertTrue(modes.contains("armed_away"))
        XCTAssertTrue(modes.contains("armed_night"))
        XCTAssertTrue(modes.contains("armed_custom_bypass"))
        XCTAssertTrue(modes.contains("armed_vacation"))
        XCTAssertEqual(modes.count, 6)
    }

    func testAlarmSupportedModesPartial() {
        // Only ARM_HOME=1 and ARM_AWAY=2
        let json: [String: Any] = [
            "entity_id": "alarm_control_panel.home",
            "state": "armed_away",
            "attributes": ["supported_features": 3]  // 1 + 2
        ]

        let state = HAEntityState(json: json)

        XCTAssertNotNil(state)
        let modes = state!.alarmSupportedModes
        XCTAssertTrue(modes.contains("disarmed"))
        XCTAssertTrue(modes.contains("armed_home"))
        XCTAssertTrue(modes.contains("armed_away"))
        XCTAssertFalse(modes.contains("armed_night"))
        XCTAssertFalse(modes.contains("armed_custom_bypass"))
        XCTAssertFalse(modes.contains("armed_vacation"))
        XCTAssertEqual(modes.count, 3)
    }

    func testAlarmCodeRequired() {
        let json: [String: Any] = [
            "entity_id": "alarm_control_panel.home",
            "state": "disarmed",
            "attributes": ["code_arm_required": true]
        ]

        let state = HAEntityState(json: json)

        XCTAssertNotNil(state)
        XCTAssertTrue(state!.codeArmRequired)
    }

    func testAlarmCodeNotRequired() {
        let json: [String: Any] = [
            "entity_id": "alarm_control_panel.home",
            "state": "disarmed",
            "attributes": ["code_arm_required": false]
        ]

        let state = HAEntityState(json: json)

        XCTAssertNotNil(state)
        XCTAssertFalse(state!.codeArmRequired)
    }

    func testAlarmCodeRequiredDefault() {
        // When not specified, defaults to true
        let json: [String: Any] = [
            "entity_id": "alarm_control_panel.home",
            "state": "disarmed",
            "attributes": [:]
        ]

        let state = HAEntityState(json: json)

        XCTAssertNotNil(state)
        XCTAssertTrue(state!.codeArmRequired)
    }
}
