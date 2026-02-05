//
//  EntityMapperTests.swift
//  macOSBridgeTests
//
//  Tests for Home Assistant entity to ServiceData mapping
//

import XCTest
@testable import macOSBridge

final class EntityMapperTests: XCTestCase {

    private var mapper: EntityMapper!

    override func setUp() {
        super.setUp()
        mapper = EntityMapper()
    }

    override func tearDown() {
        mapper = nil
        super.tearDown()
    }

    // MARK: - Helper methods

    private func createEntityState(
        entityId: String,
        state: String,
        attributes: [String: Any] = [:]
    ) -> HAEntityState {
        var json: [String: Any] = [
            "entity_id": entityId,
            "state": state,
            "attributes": attributes
        ]
        return HAEntityState(json: json)!
    }

    private func loadData(states: [HAEntityState]) {
        mapper.loadData(
            states: states,
            entities: [],
            devices: [],
            areas: []
        )
    }

    // MARK: - Light mapping tests

    func testLightMapsToLightbulbServiceType() {
        let state = createEntityState(
            entityId: "light.kitchen",
            state: "on",
            attributes: ["friendly_name": "Kitchen Light"]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.lightbulb)
    }

    func testLightWithBrightnessGetsBrightnessId() {
        let state = createEntityState(
            entityId: "light.dimmable",
            state: "on",
            attributes: [
                "friendly_name": "Dimmable Light",
                "supported_color_modes": ["brightness"],
                "brightness": 200
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.brightnessId)
    }

    func testLightWithColorGetsHueAndSaturationIds() {
        let state = createEntityState(
            entityId: "light.rgb",
            state: "on",
            attributes: [
                "friendly_name": "RGB Light",
                "supported_color_modes": ["hs"],
                "hs_color": [180.0, 75.0]
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.hueId)
        XCTAssertNotNil(service?.saturationId)
    }

    func testLightWithColorTempGetsColorTempId() {
        let state = createEntityState(
            entityId: "light.warm",
            state: "on",
            attributes: [
                "friendly_name": "Warm Light",
                "supported_color_modes": ["color_temp"],
                "color_temp": 370,
                "min_mireds": 153,
                "max_mireds": 500
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.colorTemperatureId)
    }

    func testLightValuesReturnCorrectBrightness() {
        let state = createEntityState(
            entityId: "light.test",
            state: "on",
            attributes: [
                "supported_color_modes": ["brightness"],
                "brightness": 128  // ~50%
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "light.test")
        let brightnessUUID = mapper.characteristicUUID("light.test", "brightness")

        XCTAssertEqual(values[brightnessUUID] as? Int, 50)
    }

    func testLightValuesReturnCorrectHueSaturation() {
        let state = createEntityState(
            entityId: "light.color",
            state: "on",
            attributes: [
                "supported_color_modes": ["hs"],
                "hs_color": [240.0, 80.0]
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "light.color")
        let hueUUID = mapper.characteristicUUID("light.color", "hue")
        let satUUID = mapper.characteristicUUID("light.color", "saturation")

        XCTAssertEqual(values[hueUUID] as? Double, 240.0)
        XCTAssertEqual(values[satUUID] as? Double, 80.0)
    }

    // MARK: - Cover mapping tests

    func testCoverWithPositionGetsTargetPositionId() {
        let state = createEntityState(
            entityId: "cover.blinds",
            state: "open",
            attributes: [
                "friendly_name": "Window Blinds",
                "supported_features": 15,  // OPEN + CLOSE + SET_POSITION + STOP
                "current_position": 75
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.currentPositionId)
        XCTAssertNotNil(service?.targetPositionId)
    }

    func testCoverWithoutPositionNoTargetPositionId() {
        let state = createEntityState(
            entityId: "cover.simple",
            state: "open",
            attributes: [
                "friendly_name": "Simple Cover",
                "supported_features": 3  // OPEN + CLOSE only
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNil(service?.targetPositionId)
    }

    func testTiltOnlyCoverGetsTargetPositionId() {
        // Tilt-only cover should get targetPositionId so slider shows
        let state = createEntityState(
            entityId: "cover.pergola",
            state: "open",
            attributes: [
                "friendly_name": "Pergola Roof",
                "supported_features": 240,  // OPEN_TILT + CLOSE_TILT + STOP_TILT + SET_TILT_POSITION
                "current_tilt_position": 50
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.targetPositionId, "Tilt-only cover should have targetPositionId for slider UI")
    }

    func testTiltOnlyCoverNoSeparateTiltId() {
        // Tilt-only cover should NOT have separate tilt IDs (would be redundant)
        let state = createEntityState(
            entityId: "cover.pergola",
            state: "open",
            attributes: [
                "friendly_name": "Pergola Roof",
                "supported_features": 240,
                "current_tilt_position": 50
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNil(service?.currentHorizontalTiltId, "Tilt-only cover should not have separate tilt slider")
        XCTAssertNil(service?.targetHorizontalTiltId, "Tilt-only cover should not have separate tilt slider")
    }

    func testCoverWithBothPositionAndTiltGetsBothIds() {
        let state = createEntityState(
            entityId: "cover.full",
            state: "open",
            attributes: [
                "friendly_name": "Full Blind",
                "supported_features": 255,  // All features
                "current_position": 50,
                "current_tilt_position": 30
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.targetPositionId)
        XCTAssertNotNil(service?.targetHorizontalTiltId)
    }

    func testTiltOnlyCoverValuesMapsToPosition() {
        let state = createEntityState(
            entityId: "cover.pergola",
            state: "open",
            attributes: [
                "supported_features": 240,
                "current_tilt_position": 75
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "cover.pergola")
        let positionUUID = mapper.characteristicUUID("cover.pergola", "position")

        // Tilt value should be mapped to position for tilt-only covers
        XCTAssertEqual(values[positionUUID] as? Int, 75)
    }

    func testCoverPositionDerivedFromState() {
        // Cover without position attribute should derive from state
        let openState = createEntityState(
            entityId: "cover.simple_open",
            state: "open",
            attributes: ["supported_features": 3]
        )
        let closedState = createEntityState(
            entityId: "cover.simple_closed",
            state: "closed",
            attributes: ["supported_features": 3]
        )
        loadData(states: [openState, closedState])

        let openValues = mapper.getCharacteristicValues(for: "cover.simple_open")
        let closedValues = mapper.getCharacteristicValues(for: "cover.simple_closed")
        let openPosUUID = mapper.characteristicUUID("cover.simple_open", "position")
        let closedPosUUID = mapper.characteristicUUID("cover.simple_closed", "position")

        XCTAssertEqual(openValues[openPosUUID] as? Int, 100)
        XCTAssertEqual(closedValues[closedPosUUID] as? Int, 0)
    }

    func testGarageDoorMapsToGarageDoorOpener() {
        let state = createEntityState(
            entityId: "cover.garage",
            state: "closed",
            attributes: [
                "friendly_name": "Garage Door",
                "device_class": "garage"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.garageDoorOpener)
        XCTAssertNotNil(service?.currentDoorStateId)
        XCTAssertNotNil(service?.targetDoorStateId)
    }

    // MARK: - Climate mapping tests

    func testClimateMapsToThermostat() {
        let state = createEntityState(
            entityId: "climate.ac",
            state: "heat",
            attributes: [
                "friendly_name": "Air Conditioner",
                "current_temperature": 21.0,
                "temperature": 23.0,
                "hvac_modes": ["off", "heat", "cool"]
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.thermostat)
        XCTAssertNotNil(service?.currentTemperatureId)
        XCTAssertNotNil(service?.targetTemperatureId)
        XCTAssertNotNil(service?.targetHeatingCoolingStateId)
    }

    func testClimateHVACModeMapping() {
        let testCases: [(String, Int)] = [
            ("off", 0),
            ("heat", 1),
            ("cool", 2),
            ("heat_cool", 3),
            ("dry", 4),
            ("fan_only", 5),
            ("auto", 6)
        ]

        for (mode, expected) in testCases {
            let state = createEntityState(
                entityId: "climate.test_\(mode)",
                state: mode,
                attributes: ["hvac_modes": [mode]]
            )
            loadData(states: [state])

            let values = mapper.getCharacteristicValues(for: "climate.test_\(mode)")
            let modeUUID = mapper.characteristicUUID("climate.test_\(mode)", "hvac_mode")

            XCTAssertEqual(values[modeUUID] as? Int, expected, "Mode '\(mode)' should map to \(expected)")
        }
    }

    // MARK: - Lock mapping tests

    func testLockMapsToLockMechanism() {
        let state = createEntityState(
            entityId: "lock.front_door",
            state: "locked",
            attributes: ["friendly_name": "Front Door Lock"]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.lock)
        XCTAssertNotNil(service?.lockCurrentStateId)
        XCTAssertNotNil(service?.lockTargetStateId)
    }

    func testLockStateMapping() {
        let lockedState = createEntityState(entityId: "lock.locked", state: "locked", attributes: [:])
        let unlockedState = createEntityState(entityId: "lock.unlocked", state: "unlocked", attributes: [:])
        loadData(states: [lockedState, unlockedState])

        let lockedValues = mapper.getCharacteristicValues(for: "lock.locked")
        let unlockedValues = mapper.getCharacteristicValues(for: "lock.unlocked")
        let lockedUUID = mapper.characteristicUUID("lock.locked", "lock_state")
        let unlockedUUID = mapper.characteristicUUID("lock.unlocked", "lock_state")

        XCTAssertEqual(lockedValues[lockedUUID] as? Int, 1)  // Locked
        XCTAssertEqual(unlockedValues[unlockedUUID] as? Int, 0)  // Unlocked
    }

    // MARK: - Fan mapping tests

    func testFanMapsToFanV2() {
        let state = createEntityState(
            entityId: "fan.ceiling",
            state: "on",
            attributes: [
                "friendly_name": "Ceiling Fan",
                "percentage": 50
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.fanV2)
        XCTAssertNotNil(service?.powerStateId)
        XCTAssertNotNil(service?.rotationSpeedId)
    }

    // MARK: - Switch mapping tests

    func testSwitchMapsToSwitch() {
        let state = createEntityState(
            entityId: "switch.heater",
            state: "off",
            attributes: ["friendly_name": "Space Heater"]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.switch)
    }

    func testOutletMapsToOutlet() {
        let state = createEntityState(
            entityId: "switch.outlet",
            state: "on",
            attributes: [
                "friendly_name": "Smart Outlet",
                "device_class": "outlet"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.outlet)
    }

    // MARK: - Room assignment tests

    func testAccessoryAssignedToArea() {
        let state = createEntityState(
            entityId: "light.kitchen",
            state: "on",
            attributes: ["friendly_name": "Kitchen Light"]
        )
        let area = HAArea(json: [
            "area_id": "kitchen",
            "name": "Kitchen"
        ])!
        let entity = HAEntityRegistryEntry(json: [
            "entity_id": "light.kitchen",
            "platform": "hue",
            "area_id": "kitchen"
        ])!

        mapper.loadData(
            states: [state],
            entities: [entity],
            devices: [],
            areas: [area]
        )

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.rooms.count, 1)
        XCTAssertEqual(menuData.rooms.first?.name, "Kitchen")

        let accessory = menuData.accessories.first
        XCTAssertNotNil(accessory?.roomIdentifier)
    }

    // MARK: - Entity ID lookup tests

    func testGetEntityIdFromCharacteristic() {
        let state = createEntityState(
            entityId: "light.test",
            state: "on",
            attributes: ["supported_color_modes": ["brightness"]]
        )
        loadData(states: [state])

        let brightnessUUID = mapper.characteristicUUID("light.test", "brightness")
        let entityId = mapper.getEntityIdFromCharacteristic(brightnessUUID)

        XCTAssertEqual(entityId, "light.test")
    }

    func testGetCharacteristicType() {
        let state = createEntityState(entityId: "light.test", state: "on", attributes: [:])
        loadData(states: [state])

        let brightnessUUID = mapper.characteristicUUID("light.test", "brightness")
        let charType = mapper.getCharacteristicType(for: brightnessUUID, entityId: "light.test")

        XCTAssertEqual(charType, "brightness")
    }

    // MARK: - Tilt value tests

    func testTiltValuesUse0To100Directly() {
        let state = createEntityState(
            entityId: "cover.tilt",
            state: "open",
            attributes: [
                "supported_features": 255,
                "current_position": 100,
                "current_tilt_position": 75
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "cover.tilt")
        let tiltUUID = mapper.characteristicUUID("cover.tilt", "tilt")

        // Should be 0-100 directly, not converted to angle
        XCTAssertEqual(values[tiltUUID] as? Int, 75)
    }

    // MARK: - Alarm control panel mapping tests

    func testAlarmControlPanelMapping() {
        let state = createEntityState(
            entityId: "alarm_control_panel.home",
            state: "disarmed",
            attributes: [
                "friendly_name": "Home Alarm",
                "supported_features": 55,  // All modes
                "code_arm_required": true
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()
        let services = menuData.accessories.flatMap { $0.services }
        XCTAssertEqual(services.count, 1)

        let service = services.first!
        XCTAssertEqual(service.name, "Home Alarm")
        XCTAssertEqual(service.serviceType, ServiceTypes.securitySystem)
        XCTAssertNotNil(service.alarmSupportedModes)
        XCTAssertEqual(service.alarmSupportedModes?.count, 6)
        XCTAssertTrue(service.alarmSupportedModes?.contains("disarmed") ?? false)
        XCTAssertTrue(service.alarmSupportedModes?.contains("armed_home") ?? false)
        XCTAssertTrue(service.alarmSupportedModes?.contains("armed_away") ?? false)
        XCTAssertTrue(service.alarmRequiresCode ?? false)
    }

    func testAlarmControlPanelCodeNotRequired() {
        let state = createEntityState(
            entityId: "alarm_control_panel.office",
            state: "armed_away",
            attributes: [
                "friendly_name": "Office Alarm",
                "supported_features": 3,  // Just home + away
                "code_arm_required": false
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.flatMap { $0.services }.first!
        XCTAssertEqual(service.alarmSupportedModes?.count, 3)  // disarmed + home + away
        XCTAssertFalse(service.alarmRequiresCode ?? true)
    }

    func testAlarmControlPanelStateValues() {
        let state = createEntityState(
            entityId: "alarm_control_panel.home",
            state: "armed_away",
            attributes: ["supported_features": 3]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "alarm_control_panel.home")
        let targetUUID = mapper.characteristicUUID("alarm_control_panel.home", "alarm_target")

        // armed_away should map to 1 (HomeKit away)
        XCTAssertEqual(values[targetUUID] as? Int, 1)
    }
}
