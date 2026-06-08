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

        // lock_state returns raw state string
        let lockedStateUUID = mapper.characteristicUUID("lock.locked", "lock_state")
        let unlockedStateUUID = mapper.characteristicUUID("lock.unlocked", "lock_state")
        XCTAssertEqual(lockedValues[lockedStateUUID] as? String, "locked")
        XCTAssertEqual(unlockedValues[unlockedStateUUID] as? String, "unlocked")

        // lock_target returns Int (1=locked, 0=unlocked)
        let lockedTargetUUID = mapper.characteristicUUID("lock.locked", "lock_target")
        let unlockedTargetUUID = mapper.characteristicUUID("lock.unlocked", "lock_target")
        XCTAssertEqual(lockedValues[lockedTargetUUID] as? Int, 1)
        XCTAssertEqual(unlockedValues[unlockedTargetUUID] as? Int, 0)
    }

    // MARK: - Fan mapping tests

    func testFanMapsToFanV2() {
        let state = createEntityState(
            entityId: "fan.ceiling",
            state: "on",
            attributes: [
                "friendly_name": "Ceiling Fan",
                "percentage": 50,
                "supported_features": 1  // SET_PERCENTAGE bit
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

    // MARK: - Humidifier mapping tests

    func testHumidifierMapsToHumidifierDehumidifier() {
        let state = createEntityState(
            entityId: "humidifier.bedroom",
            state: "on",
            attributes: [
                "friendly_name": "Bedroom Humidifier",
                "current_humidity": 45,
                "humidity": 55,
                "available_modes": ["normal", "eco", "boost"]
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.humidifierDehumidifier)
        XCTAssertNotNil(service?.powerStateId)
        XCTAssertNotNil(service?.humidifierThresholdId)
    }

    func testHumidifierWithModes() {
        let state = createEntityState(
            entityId: "humidifier.living_room",
            state: "on",
            attributes: [
                "friendly_name": "Living Room Humidifier",
                "available_modes": ["normal", "eco", "boost"],
                "mode": "eco"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.targetHumidifierDehumidifierStateId)
        XCTAssertEqual(service?.humidifierAvailableModes, ["normal", "eco", "boost"])
    }

    func testHumidifierValues() {
        let state = createEntityState(
            entityId: "humidifier.test",
            state: "on",
            attributes: [
                "humidity": 60,
                "current_humidity": 45,
                "available_modes": ["normal"],
                "mode": "normal"
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "humidifier.test")
        let powerUUID = mapper.characteristicUUID("humidifier.test", "power")
        let targetHumidityUUID = mapper.characteristicUUID("humidifier.test", "target_humidity")
        let modeUUID = mapper.characteristicUUID("humidifier.test", "hum_mode")

        XCTAssertEqual(values[powerUUID] as? Bool, true)
        XCTAssertEqual(values[targetHumidityUUID] as? Int, 60)
        XCTAssertEqual(values[modeUUID] as? String, "normal")
    }

    func testHumidifierOffState() {
        let state = createEntityState(
            entityId: "humidifier.off_test",
            state: "off",
            attributes: ["humidity": 50]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "humidifier.off_test")
        let powerUUID = mapper.characteristicUUID("humidifier.off_test", "power")

        XCTAssertEqual(values[powerUUID] as? Bool, false)
    }

    // MARK: - Valve mapping tests

    func testValveMapsToValve() {
        let state = createEntityState(
            entityId: "valve.irrigation",
            state: "open",
            attributes: [
                "friendly_name": "Garden Irrigation"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.valve)
        XCTAssertNotNil(service?.valveStateId)
        XCTAssertNotNil(service?.activeId)
    }

    func testValveWithPosition() {
        // SET_POSITION is bit 4
        let state = createEntityState(
            entityId: "valve.position_valve",
            state: "open",
            attributes: [
                "friendly_name": "Position Valve",
                "supported_features": 4,
                "current_position": 75
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertNotNil(service?.currentPositionId)
        XCTAssertNotNil(service?.targetPositionId)
    }

    func testValveValues() {
        let state = createEntityState(
            entityId: "valve.test",
            state: "open",
            attributes: [
                "supported_features": 4,
                "current_position": 80
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "valve.test")
        let valveStateUUID = mapper.characteristicUUID("valve.test", "valve_state")
        let activeUUID = mapper.characteristicUUID("valve.test", "active")
        let positionUUID = mapper.characteristicUUID("valve.test", "position")

        XCTAssertEqual(values[valveStateUUID] as? String, "open")
        XCTAssertEqual(values[activeUUID] as? Int, 1)
        XCTAssertEqual(values[positionUUID] as? Int, 80)
    }

    func testValveClosedState() {
        let state = createEntityState(
            entityId: "valve.closed_test",
            state: "closed",
            attributes: [:]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "valve.closed_test")
        let activeUUID = mapper.characteristicUUID("valve.closed_test", "active")

        XCTAssertEqual(values[activeUUID] as? Int, 0)
    }

    // MARK: - Scene mapping tests

    func testSceneMapsToSceneData() {
        let state = createEntityState(
            entityId: "scene.movie_time",
            state: "scening",
            attributes: [
                "friendly_name": "Movie Time",
                "id": "movie_time_internal"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.scenes.count, 1)
        let scene = menuData.scenes.first!
        XCTAssertEqual(scene.name, "Movie Time")
    }

    func testMultipleScenesAreSorted() {
        let scene1 = createEntityState(
            entityId: "scene.zebra",
            state: "scening",
            attributes: ["friendly_name": "Zebra Scene"]
        )
        let scene2 = createEntityState(
            entityId: "scene.alpha",
            state: "scening",
            attributes: ["friendly_name": "Alpha Scene"]
        )
        loadData(states: [scene1, scene2])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.scenes.count, 2)
        XCTAssertEqual(menuData.scenes[0].name, "Alpha Scene")
        XCTAssertEqual(menuData.scenes[1].name, "Zebra Scene")
    }

    func testSceneWithConfigGeneratesActions() {
        let sceneState = createEntityState(
            entityId: "scene.bedtime",
            state: "scening",
            attributes: ["friendly_name": "Bedtime", "id": "bedtime_internal"]
        )
        let lightState = createEntityState(
            entityId: "light.bedroom",
            state: "on",
            attributes: ["friendly_name": "Bedroom Light"]
        )

        // Create scene config (requires id field)
        let sceneConfig = HASceneConfig(json: [
            "id": "bedtime_internal",
            "name": "Bedtime",
            "entities": [
                "light.bedroom": ["state": "on", "brightness": 128]
            ]
        ])!

        mapper.loadData(
            states: [sceneState, lightState],
            entities: [],
            devices: [],
            areas: [],
            sceneConfigs: ["scene.bedtime": sceneConfig]
        )

        let menuData = mapper.generateMenuData()

        let scene = menuData.scenes.first { $0.name == "Bedtime" }
        XCTAssertNotNil(scene)
        XCTAssertFalse(scene!.actions.isEmpty)
        XCTAssertEqual(scene!.actions.count, 2)  // power + brightness
    }

    // MARK: - Camera mapping tests

    func testCameraMapsToMenuData() {
        let state = createEntityState(
            entityId: "camera.front_door",
            state: "streaming",
            attributes: [
                "friendly_name": "Front Door Camera",
                "supported_features": 2
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.cameras.count, 1)
        XCTAssertTrue(menuData.hasCameras)
        let camera = menuData.cameras.first!
        XCTAssertEqual(camera.name, "Front Door Camera")
        XCTAssertEqual(camera.entityId, "camera.front_door")
    }

    func testMultipleCamerasAreSorted() {
        let cam1 = createEntityState(
            entityId: "camera.backyard",
            state: "streaming",
            attributes: ["friendly_name": "Backyard Camera", "supported_features": 2]
        )
        let cam2 = createEntityState(
            entityId: "camera.front",
            state: "streaming",
            attributes: ["friendly_name": "Front Camera", "supported_features": 2]
        )
        loadData(states: [cam1, cam2])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.cameras.count, 2)
        XCTAssertEqual(menuData.cameras[0].name, "Backyard Camera")
        XCTAssertEqual(menuData.cameras[1].name, "Front Camera")
    }

    func testCameraWithoutStreamFeatureShownInMenu() {
        let frigate = createEntityState(
            entityId: "camera.front_door",
            state: "recording",
            attributes: [
                "friendly_name": "Front Door",
                "supported_features": 0,
                "client_id": "frigate"
            ]
        )
        loadData(states: [frigate])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.cameras.count, 1)
        XCTAssertTrue(menuData.hasCameras)
        XCTAssertEqual(menuData.cameras.first?.entityId, "camera.front_door")
    }

    func testUnavailableCameraExcludedFromMenu() {
        let available = createEntityState(
            entityId: "camera.front_door",
            state: "idle",
            attributes: [
                "friendly_name": "Front Door Camera",
                "supported_features": 2
            ]
        )
        let unavailable = createEntityState(
            entityId: "camera.test_fluent",
            state: "unavailable",
            attributes: [
                "friendly_name": "Fluent",
                "supported_features": 2,
                "restored": true
            ]
        )
        loadData(states: [available, unavailable])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.cameras.count, 1)
        XCTAssertEqual(menuData.cameras.first?.entityId, "camera.front_door")
    }

    func testNoCamerasReturnsEmptyAndFalse() {
        let state = createEntityState(
            entityId: "light.test",
            state: "on",
            attributes: ["friendly_name": "Test Light"]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        XCTAssertEqual(menuData.cameras.count, 0)
        XCTAssertFalse(menuData.hasCameras)
    }

    // MARK: - Sensor mapping tests

    func testTemperatureSensorMapping() {
        let state = createEntityState(
            entityId: "sensor.outdoor_temp",
            state: "23.5",
            attributes: [
                "friendly_name": "Outdoor Temperature",
                "device_class": "temperature",
                "unit_of_measurement": "°C"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.temperatureSensor)
        XCTAssertNotNil(service?.currentTemperatureId)
    }

    func testTemperatureSensorValues() {
        let state = createEntityState(
            entityId: "sensor.living_room_temp",
            state: "21.5",
            attributes: [
                "device_class": "temperature"
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "sensor.living_room_temp")
        let tempUUID = mapper.characteristicUUID("sensor.living_room_temp", "current_temp")

        XCTAssertEqual(values[tempUUID] as? Double, 21.5)
    }

    func testHumiditySensorMapping() {
        let state = createEntityState(
            entityId: "sensor.bathroom_humidity",
            state: "65",
            attributes: [
                "friendly_name": "Bathroom Humidity",
                "device_class": "humidity",
                "unit_of_measurement": "%"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.humiditySensor)
        XCTAssertNotNil(service?.humidityId)
    }

    func testHumiditySensorValues() {
        let state = createEntityState(
            entityId: "sensor.bedroom_humidity",
            state: "55",
            attributes: [
                "device_class": "humidity"
            ]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "sensor.bedroom_humidity")
        let humidityUUID = mapper.characteristicUUID("sensor.bedroom_humidity", "humidity")

        XCTAssertEqual(values[humidityUUID] as? Double, 55.0)
    }

    // Any numeric sensor (incl. battery) is now supported as a generic sensor.
    // Diagnostic noise is governed separately by the entity-category filter.
    func testNumericSensorMapsToGenericSensor() {
        let state = createEntityState(
            entityId: "sensor.battery",
            state: "80",
            attributes: [
                "device_class": "battery",
                "unit_of_measurement": "%"
            ]
        )
        loadData(states: [state])

        let service = mapper.generateMenuData().accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.sensor)
        XCTAssertEqual(service?.sensorUnit, "%")
    }

    // MARK: - Binary sensor mapping tests

    func testBinarySensorDeviceClassesMapToSensorServiceTypes() {
        let cases: [(deviceClass: String, type: String)] = [
            ("door", ServiceTypes.contactSensor),
            ("window", ServiceTypes.contactSensor),
            ("opening", ServiceTypes.contactSensor),
            ("garage_door", ServiceTypes.contactSensor),
            ("motion", ServiceTypes.motionSensor),
            ("moving", ServiceTypes.motionSensor),
            ("occupancy", ServiceTypes.occupancySensor),
            ("presence", ServiceTypes.occupancySensor),
            ("moisture", ServiceTypes.leakSensor),
            ("smoke", ServiceTypes.smokeSensor),
            ("carbon_monoxide", ServiceTypes.carbonMonoxideSensor)
        ]
        for c in cases {
            let entityId = "binary_sensor.\(c.deviceClass)"
            loadData(states: [createEntityState(entityId: entityId, state: "off", attributes: ["device_class": c.deviceClass])])
            let service = mapper.generateMenuData().accessories.first?.services.first
            XCTAssertEqual(service?.serviceType, c.type, "mapping for \(c.deviceClass)")
        }
    }

    // Each kind populates its own detected-state characteristic id.
    func testBinarySensorPopulatesCorrectCharacteristicId() {
        loadData(states: [
            createEntityState(entityId: "binary_sensor.front_door", state: "off", attributes: ["device_class": "door"]),
            createEntityState(entityId: "binary_sensor.hall", state: "off", attributes: ["device_class": "motion"]),
            createEntityState(entityId: "binary_sensor.office", state: "off", attributes: ["device_class": "occupancy"]),
            createEntityState(entityId: "binary_sensor.sink", state: "off", attributes: ["device_class": "moisture"]),
            createEntityState(entityId: "binary_sensor.kitchen", state: "off", attributes: ["device_class": "smoke"]),
            createEntityState(entityId: "binary_sensor.garage", state: "off", attributes: ["device_class": "carbon_monoxide"])
        ])
        let services = mapper.generateMenuData().accessories.flatMap { $0.services }
        func service(_ id: String) -> ServiceData? { services.first { $0.haEntityId == id } }

        XCTAssertNotNil(service("binary_sensor.front_door")?.contactSensorStateId)
        XCTAssertNotNil(service("binary_sensor.hall")?.motionDetectedId)
        XCTAssertNotNil(service("binary_sensor.office")?.occupancyDetectedId)
        XCTAssertNotNil(service("binary_sensor.sink")?.leakDetectedId)
        XCTAssertNotNil(service("binary_sensor.kitchen")?.smokeDetectedId)
        XCTAssertNotNil(service("binary_sensor.garage")?.carbonMonoxideDetectedId)
    }

    // HA reports on = detected; contact-style classes report on = open, which
    // matches HomeKit's ContactSensorState 1 = open.
    func testBinarySensorValuesMapOnOffToOneZero() {
        let cases: [(deviceClass: String, charName: String)] = [
            ("door", "contact_state"),
            ("motion", "motion"),
            ("occupancy", "occupancy"),
            ("moisture", "leak"),
            ("smoke", "smoke"),
            ("carbon_monoxide", "co")
        ]
        for c in cases {
            let onId = "binary_sensor.on_\(c.deviceClass)"
            let offId = "binary_sensor.off_\(c.deviceClass)"
            loadData(states: [
                createEntityState(entityId: onId, state: "on", attributes: ["device_class": c.deviceClass]),
                createEntityState(entityId: offId, state: "off", attributes: ["device_class": c.deviceClass])
            ])
            let onValue = mapper.getCharacteristicValues(for: onId)[mapper.characteristicUUID(onId, c.charName)] as? Int
            let offValue = mapper.getCharacteristicValues(for: offId)[mapper.characteristicUUID(offId, c.charName)] as? Int
            XCTAssertEqual(onValue, 1, "on value for \(c.deviceClass)")
            XCTAssertEqual(offValue, 0, "off value for \(c.deviceClass)")
        }
    }

    // Unavailable must read as unknown (no value), never a false "clear" – a
    // false clear on a smoke/CO/leak sensor is the worst silent failure.
    func testUnavailableBinarySensorHasNoValue() {
        let entityId = "binary_sensor.unavailable_smoke"
        loadData(states: [createEntityState(entityId: entityId, state: "unavailable", attributes: ["device_class": "smoke"])])
        let values = mapper.getCharacteristicValues(for: entityId)
        XCTAssertNil(values[mapper.characteristicUUID(entityId, "smoke")])
    }

    // Binary sensors without a HomeKit-equivalent device_class become generic
    // binary sensors (shown as On/Off) rather than being dropped.
    func testUnmappedBinarySensorsBecomeGeneric() {
        loadData(states: [
            createEntityState(entityId: "binary_sensor.connectivity", state: "on", attributes: ["device_class": "connectivity"]),
            createEntityState(entityId: "binary_sensor.problem", state: "off", attributes: ["device_class": "problem"]),
            createEntityState(entityId: "binary_sensor.plain", state: "on", attributes: [:])
        ])
        let services = mapper.generateMenuData().accessories.flatMap { $0.services }
        XCTAssertEqual(services.count, 3)
        XCTAssertTrue(services.allSatisfy { $0.serviceType == ServiceTypes.binarySensor })
    }

    // The webhook/read path resolves a sensor characteristic back to its entity.
    func testBinarySensorCharacteristicResolvesToEntity() {
        let entityId = "binary_sensor.leak_detector"
        loadData(states: [createEntityState(entityId: entityId, state: "on", attributes: ["device_class": "moisture"])])
        let leakUUID = mapper.characteristicUUID(entityId, "leak")
        XCTAssertEqual(mapper.getEntityIdFromCharacteristic(leakUUID), entityId)
    }

    // MARK: - Generic sensor tests

    // Any numeric sensor without a HomeKit equivalent (CO2, power, pressure, ...)
    // becomes a generic sensor carrying its unit and device_class.
    func testGenericNumericSensorMapping() {
        let state = createEntityState(
            entityId: "sensor.co2",
            state: "812",
            attributes: [
                "friendly_name": "Living Room CO2",
                "device_class": "carbon_dioxide",
                "unit_of_measurement": "ppm"
            ]
        )
        loadData(states: [state])

        let service = mapper.generateMenuData().accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.sensor)
        XCTAssertNotNil(service?.sensorReadingId)
        XCTAssertEqual(service?.sensorUnit, "ppm")
        XCTAssertEqual(service?.sensorDeviceClass, "carbon_dioxide")
    }

    func testGenericNumericSensorValue() {
        let state = createEntityState(
            entityId: "sensor.power",
            state: "42.5",
            attributes: ["device_class": "power", "unit_of_measurement": "W"]
        )
        loadData(states: [state])

        let values = mapper.getCharacteristicValues(for: "sensor.power")
        XCTAssertEqual(values[mapper.characteristicUUID("sensor.power", "sensor_reading")] as? Double, 42.5)
    }

    // Sensors with no numeric value (text/enum/timestamp) are skipped.
    func testNonNumericSensorIsIgnored() {
        loadData(states: [
            createEntityState(entityId: "sensor.washer", state: "running", attributes: ["friendly_name": "Washer"]),
            createEntityState(entityId: "sensor.last_boot", state: "2026-01-01T00:00:00+00:00", attributes: ["device_class": "timestamp"])
        ])
        XCTAssertEqual(mapper.generateMenuData().accessories.count, 0)
    }

    // Binary sensors without a HomeKit equivalent become generic binary sensors.
    func testGenericBinarySensorMapping() {
        let state = createEntityState(
            entityId: "binary_sensor.vibration",
            state: "on",
            attributes: ["friendly_name": "Washer Vibration", "device_class": "vibration"]
        )
        loadData(states: [state])

        let service = mapper.generateMenuData().accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.binarySensor)
        XCTAssertNotNil(service?.sensorReadingId)
        XCTAssertEqual(service?.sensorDeviceClass, "vibration")
    }

    func testGenericBinarySensorValue() {
        loadData(states: [
            createEntityState(entityId: "binary_sensor.gas_on", state: "on", attributes: ["device_class": "gas"]),
            createEntityState(entityId: "binary_sensor.gas_off", state: "off", attributes: ["device_class": "gas"])
        ])
        let onUUID = mapper.characteristicUUID("binary_sensor.gas_on", "sensor_reading")
        let offUUID = mapper.characteristicUUID("binary_sensor.gas_off", "sensor_reading")
        XCTAssertEqual(mapper.getCharacteristicValues(for: "binary_sensor.gas_on")[onUUID] as? Int, 1)
        XCTAssertEqual(mapper.getCharacteristicValues(for: "binary_sensor.gas_off")[offUUID] as? Int, 0)
    }

    // MARK: - Battery tests

    private func registryEntry(_ entityId: String, deviceId: String) -> HAEntityRegistryEntry {
        HAEntityRegistryEntry(json: ["entity_id": entityId, "platform": "test", "device_id": deviceId])!
    }

    // A device's battery sensor badges its sibling rows and is not its own row.
    func testHABatterySensorBadgesSiblingsAndIsHidden() {
        let light = createEntityState(entityId: "light.lamp", state: "on", attributes: ["friendly_name": "Lamp"])
        let battery = createEntityState(entityId: "sensor.lamp_battery", state: "60", attributes: ["device_class": "battery", "unit_of_measurement": "%"])
        mapper.loadData(
            states: [light, battery],
            entities: [registryEntry("light.lamp", deviceId: "dev1"), registryEntry("sensor.lamp_battery", deviceId: "dev1")],
            devices: [], areas: []
        )

        let services = mapper.generateMenuData().accessories.flatMap { $0.services }
        XCTAssertEqual(services.count, 1, "battery sensor should badge the light, not add a row")
        let lightService = services.first { $0.haEntityId == "light.lamp" }
        XCTAssertEqual(lightService?.batteryLevelId, mapper.characteristicUUID("sensor.lamp_battery", "sensor_reading").uuidString)
    }

    // A device that is only a battery sensor still shows as a normal sensor row.
    func testHABatteryOnlyDeviceShownAsSensor() {
        let battery = createEntityState(entityId: "sensor.leak_battery", state: "75", attributes: ["device_class": "battery", "unit_of_measurement": "%"])
        mapper.loadData(states: [battery], entities: [registryEntry("sensor.leak_battery", deviceId: "dev2")], devices: [], areas: [])

        let services = mapper.generateMenuData().accessories.flatMap { $0.services }
        XCTAssertEqual(services.count, 1)
        XCTAssertEqual(services.first?.serviceType, ServiceTypes.sensor)
    }

    // MARK: - Gate/door cover mapping tests

    func testGateMapsToWindowCovering() {
        // Gates without explicit "garage" device_class map to window covering
        let state = createEntityState(
            entityId: "cover.driveway_gate",
            state: "closed",
            attributes: [
                "friendly_name": "Driveway Gate",
                "device_class": "gate"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        // Gate device_class maps to windowCovering (only "garage" maps to garageDoorOpener)
        XCTAssertEqual(service?.serviceType, ServiceTypes.windowCovering)
    }

    func testDoorMapsToWindowCovering() {
        let state = createEntityState(
            entityId: "cover.front_door",
            state: "closed",
            attributes: [
                "friendly_name": "Front Door",
                "device_class": "door"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.door)
    }

    func testWindowMapsToWindow() {
        let state = createEntityState(
            entityId: "cover.skylight",
            state: "open",
            attributes: [
                "friendly_name": "Skylight",
                "device_class": "window"
            ]
        )
        loadData(states: [state])

        let menuData = mapper.generateMenuData()

        let service = menuData.accessories.first?.services.first
        XCTAssertEqual(service?.serviceType, ServiceTypes.window)
    }

    // MARK: - Climate swing mode visibility

    func testClimateSwingModePassesAvailableModes() {
        loadData(states: [
            createEntityState(
                entityId: "climate.ac",
                state: "cool",
                attributes: [
                    "swing_mode": "both",
                    "swing_modes": ["off", "both", "vertical", "horizontal"],
                    "hvac_modes": ["off", "cool"]
                ]
            )
        ])

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertNotNil(service?.swingModeId)
        XCTAssertEqual(service?.availableSwingModes, ["off", "both", "vertical", "horizontal"])
    }

    func testClimateSwingModeWithoutOffMode() {
        loadData(states: [
            createEntityState(
                entityId: "climate.ac",
                state: "cool",
                attributes: [
                    "swing_mode": "both",
                    "swing_modes": ["both", "vertical", "horizontal"],
                    "hvac_modes": ["off", "cool"]
                ]
            )
        ])

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertNotNil(service?.swingModeId)
        XCTAssertEqual(service?.availableSwingModes, ["both", "vertical", "horizontal"])
        XCTAssertFalse(service!.availableSwingModes!.contains("off"))
    }

    // MARK: - getAllCameraEntities tests

    func testGetAllCameraEntitiesIncludesWithoutStreamFlag() {
        let withStream = createEntityState(
            entityId: "camera.front_door",
            state: "idle",
            attributes: [
                "friendly_name": "Front Door",
                "supported_features": 2
            ]
        )
        let withoutStream = createEntityState(
            entityId: "camera.frigate",
            state: "idle",
            attributes: [
                "friendly_name": "Frigate Camera",
                "supported_features": 0
            ]
        )
        loadData(states: [withStream, withoutStream])

        let cameras = mapper.getAllCameraEntities()

        XCTAssertEqual(cameras.count, 2)
        let entityIds = Set(cameras.map { $0.entityId })
        XCTAssertTrue(entityIds.contains("camera.front_door"))
        XCTAssertTrue(entityIds.contains("camera.frigate"))
    }

    func testGetAllCameraEntitiesExcludesNonCameras() {
        let camera = createEntityState(
            entityId: "camera.backyard",
            state: "streaming",
            attributes: [
                "friendly_name": "Backyard Camera",
                "supported_features": 2
            ]
        )
        let light = createEntityState(
            entityId: "light.kitchen",
            state: "on",
            attributes: ["friendly_name": "Kitchen Light"]
        )
        let sensor = createEntityState(
            entityId: "sensor.temperature",
            state: "22.5",
            attributes: ["device_class": "temperature"]
        )
        loadData(states: [camera, light, sensor])

        let cameras = mapper.getAllCameraEntities()

        XCTAssertEqual(cameras.count, 1)
        XCTAssertEqual(cameras.first?.entityId, "camera.backyard")
    }

    func testGetAllCameraEntitiesReturnsEmptyWhenNoCameras() {
        let light = createEntityState(
            entityId: "light.kitchen",
            state: "on",
            attributes: ["friendly_name": "Kitchen Light"]
        )
        loadData(states: [light])

        let cameras = mapper.getAllCameraEntities()

        XCTAssertTrue(cameras.isEmpty)
    }

    func testClimateSwingModeNilWhenNoSwingModes() {
        loadData(states: [
            createEntityState(
                entityId: "climate.ac",
                state: "cool",
                attributes: [
                    "hvac_modes": ["off", "cool"]
                ]
            )
        ])

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertNil(service?.swingModeId)
        XCTAssertNil(service?.availableSwingModes)
    }
}
