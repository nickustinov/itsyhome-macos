//
//  HubitatDeviceMapperTests.swift
//  macOSBridgeTests
//
//  Tests for HubitatDeviceMapper capability mapping and value conversions
//

import XCTest
@testable import macOSBridge

final class HubitatDeviceMapperTests: XCTestCase {

    var mapper: HubitatDeviceMapper!

    override func setUp() {
        super.setUp()
        mapper = HubitatDeviceMapper()
    }

    override func tearDown() {
        mapper = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeDevice(
        id: String,
        name: String,
        label: String? = nil,
        type: String? = nil,
        capabilities: [String],
        attributes: [String: Any] = [:]
    ) -> HubitatDevice {
        var json: [String: Any] = [
            "id": id,
            "name": name,
            "capabilities": capabilities,
            "attributes": attributes,
            "commands": [] as [[String: Any]]
        ]
        if let label = label { json["label"] = label }
        if let type = type { json["type"] = type }
        return HubitatDevice(json: json)!
    }

    private func loadSingle(_ device: HubitatDevice) {
        mapper.loadDevices([device])
    }

    // MARK: - Service type mapping

    func testSwitchDeviceMapping() {
        let device = makeDevice(id: "1", name: "Hall Switch", capabilities: ["Switch"],
                                attributes: ["switch": "off"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.`switch`)
        XCTAssertNotNil(service?.powerStateId)
        XCTAssertNil(service?.brightnessId)
    }

    func testDimmerMapping() {
        let device = makeDevice(id: "2", name: "Dimmer", capabilities: ["Switch", "SwitchLevel"],
                                attributes: ["switch": "on", "level": 80])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.lightbulb)
        XCTAssertNotNil(service?.powerStateId)
        XCTAssertNotNil(service?.brightnessId)
        XCTAssertNil(service?.hueId)
    }

    func testColorLightMapping() {
        let device = makeDevice(
            id: "3", name: "Color Bulb",
            capabilities: ["Switch", "SwitchLevel", "ColorControl", "ColorTemperature"],
            attributes: ["switch": "on", "level": 100, "hue": 50, "saturation": 100, "colorTemperature": 3000]
        )
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.lightbulb)
        XCTAssertNotNil(service?.powerStateId)
        XCTAssertNotNil(service?.brightnessId)
        XCTAssertNotNil(service?.hueId)
        XCTAssertNotNil(service?.saturationId)
        XCTAssertNotNil(service?.colorTemperatureId)
        XCTAssertEqual(service?.colorTemperatureMin, 153)
        XCTAssertEqual(service?.colorTemperatureMax, 500)
    }

    func testLockMapping() {
        let device = makeDevice(id: "4", name: "Front Door", capabilities: ["Lock"],
                                attributes: ["lock": "locked"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.lock)
        XCTAssertNotNil(service?.lockCurrentStateId)
        XCTAssertNotNil(service?.lockTargetStateId)
    }

    func testThermostatMapping() {
        let device = makeDevice(
            id: "5", name: "Thermostat",
            capabilities: ["Thermostat", "TemperatureMeasurement"],
            attributes: ["thermostatMode": "heat", "temperature": 68, "heatingSetpoint": 70]
        )
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.thermostat)
        XCTAssertNotNil(service?.currentTemperatureId)
        XCTAssertNotNil(service?.targetTemperatureId)
        XCTAssertNotNil(service?.heatingCoolingStateId)
        XCTAssertNotNil(service?.targetHeatingCoolingStateId)
    }

    func testWindowShadeMapping() {
        let device = makeDevice(id: "6", name: "Bedroom Shade", capabilities: ["WindowShade"],
                                attributes: ["position": 50])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.windowCovering)
        XCTAssertNotNil(service?.currentPositionId)
        XCTAssertNotNil(service?.targetPositionId)
    }

    func testFanMapping() {
        let device = makeDevice(id: "7", name: "Ceiling Fan",
                                capabilities: ["Switch", "FanControl"],
                                attributes: ["switch": "on", "speed": "medium"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.fanV2)
        XCTAssertNotNil(service?.powerStateId)
        XCTAssertNotNil(service?.rotationSpeedId)
        XCTAssertEqual(service?.rotationSpeedMin, 0)
        XCTAssertEqual(service?.rotationSpeedMax, 100)
    }

    func testValveMapping() {
        let device = makeDevice(id: "8", name: "Irrigation Valve", capabilities: ["Valve"],
                                attributes: ["valve": "closed"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.valve)
        XCTAssertNotNil(service?.activeId)
        XCTAssertNotNil(service?.valveStateId)
    }

    func testTemperatureSensorMapping() {
        let device = makeDevice(id: "9", name: "Outdoor Sensor",
                                capabilities: ["TemperatureMeasurement"],
                                attributes: ["temperature": 65])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.temperatureSensor)
        XCTAssertNotNil(service?.currentTemperatureId)
        XCTAssertNil(service?.targetTemperatureId)
    }

    func testHumiditySensorMapping() {
        let device = makeDevice(id: "10", name: "Humidity Sensor",
                                capabilities: ["RelativeHumidityMeasurement"],
                                attributes: ["humidity": 45])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.humiditySensor)
        XCTAssertNotNil(service?.humidityId)
    }

    func testOutletMapping() {
        let device = makeDevice(id: "11", name: "Smart Plug",
                                type: "Generic Z-Wave Smart Energy Switch (Outlet)",
                                capabilities: ["Switch"],
                                attributes: ["switch": "off"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let service = menuData.accessories.first?.services.first

        XCTAssertEqual(service?.serviceType, ServiceTypes.outlet)
        XCTAssertNotNil(service?.powerStateId)
    }

    // MARK: - Value conversions

    func testHueConversion() {
        // Hubitat reports hue as 0-100; Itsyhome expects 0-360
        let device = makeDevice(id: "20", name: "Color Bulb",
                                capabilities: ["Switch", "SwitchLevel", "ColorControl"],
                                attributes: ["switch": "on", "hue": 50.0, "saturation": 100, "level": 100])
        loadSingle(device)

        let values = mapper.getCharacteristicValues(for: "20")
        let hueUUID = mapper.characteristicUUID("20", "hue")
        let hueValue = values[hueUUID] as? Double

        XCTAssertNotNil(hueValue)
        // 50 (Hubitat) * 360 / 100 = 180.0
        XCTAssertEqual(hueValue!, 180.0, accuracy: 0.01)
    }

    func testColorTempConversion() {
        // Hubitat reports color temp in Kelvin; Itsyhome expects mireds (1,000,000/K)
        let device = makeDevice(id: "21", name: "Tunable White",
                                capabilities: ["Switch", "SwitchLevel", "ColorTemperature"],
                                attributes: ["switch": "on", "level": 100, "colorTemperature": 4000.0])
        loadSingle(device)

        let values = mapper.getCharacteristicValues(for: "21")
        let colorTempUUID = mapper.characteristicUUID("21", "color_temp")
        let miredValue = values[colorTempUUID] as? Int

        XCTAssertNotNil(miredValue)
        // 1,000,000 / 4000 = 250 mireds
        XCTAssertEqual(miredValue, 250)
    }

    func testTemperatureNormalizationFahrenheit() {
        // Default unit is °F; 72°F should convert to ~22.2°C
        let celsius = mapper.normalizeTemperature(72.0)
        XCTAssertEqual(celsius, (72.0 - 32.0) * 5.0 / 9.0, accuracy: 0.01)
    }

    func testTemperatureDenormalization() {
        // ~22.2°C should convert back to ~72°F
        let fahrenheit = mapper.denormalizeTemperature(22.222)
        XCTAssertEqual(fahrenheit, 72.0, accuracy: 0.1)
    }

    // MARK: - UUID consistency

    func testCharacteristicUUIDConsistency() {
        let uuid1 = mapper.characteristicUUID("42", "power")
        let uuid2 = mapper.characteristicUUID("42", "power")
        XCTAssertEqual(uuid1, uuid2)
    }

    func testDifferentCharacteristicsDifferentUUIDs() {
        let powerUUID = mapper.characteristicUUID("42", "power")
        let brightnessUUID = mapper.characteristicUUID("42", "brightness")
        let otherDevicePowerUUID = mapper.characteristicUUID("99", "power")

        XCTAssertNotEqual(powerUUID, brightnessUUID)
        XCTAssertNotEqual(powerUUID, otherDevicePowerUUID)
    }

    // MARK: - Reverse lookups

    func testGetDeviceIdFromCharacteristic() {
        let device = makeDevice(id: "30", name: "Switch", capabilities: ["Switch"],
                                attributes: ["switch": "on"])
        loadSingle(device)

        let powerUUID = mapper.characteristicUUID("30", "power")
        let resolvedId = mapper.getDeviceIdFromCharacteristic(powerUUID)

        XCTAssertEqual(resolvedId, "30")
    }

    func testGetDeviceIdFromCharacteristicUnknownUUIDReturnsNil() {
        let device = makeDevice(id: "31", name: "Switch", capabilities: ["Switch"],
                                attributes: [:])
        loadSingle(device)

        let unknownUUID = UUID()
        XCTAssertNil(mapper.getDeviceIdFromCharacteristic(unknownUUID))
    }

    // MARK: - State updates

    func testUpdateDeviceAttribute() {
        let device = makeDevice(id: "40", name: "Switch", capabilities: ["Switch"],
                                attributes: ["switch": "off"])
        loadSingle(device)

        // Verify initial state
        let beforeValues = mapper.getCharacteristicValues(for: "40")
        let powerUUID = mapper.characteristicUUID("40", "power")
        XCTAssertEqual(beforeValues[powerUUID] as? Bool, false)

        // Simulate event update
        mapper.updateDeviceAttribute(deviceId: "40", attributeName: "switch", value: "on")

        let afterValues = mapper.getCharacteristicValues(for: "40")
        XCTAssertEqual(afterValues[powerUUID] as? Bool, true)
    }

    // MARK: - Fan speed read

    func testFanSpeedReadsSpeedAttribute() {
        let device = makeDevice(id: "50", name: "Fan", capabilities: ["Switch", "FanControl"],
                                attributes: ["switch": "on", "speed": "medium"])
        loadSingle(device)

        let values = mapper.getCharacteristicValues(for: "50")
        let speedUUID = mapper.characteristicUUID("50", "speed")
        let speedValue = values[speedUUID] as? Int

        // "medium" -> 60
        XCTAssertEqual(speedValue, 60)
    }

    func testFanSpeedLowMapsTo20() {
        let device = makeDevice(id: "51", name: "Fan", capabilities: ["Switch", "FanControl"],
                                attributes: ["switch": "on", "speed": "low"])
        loadSingle(device)

        let values = mapper.getCharacteristicValues(for: "51")
        let speedUUID = mapper.characteristicUUID("51", "speed")
        XCTAssertEqual(values[speedUUID] as? Int, 20)
    }

    func testFanSpeedHighMapsTo100() {
        let device = makeDevice(id: "52", name: "Fan", capabilities: ["Switch", "FanControl"],
                                attributes: ["switch": "on", "speed": "high"])
        loadSingle(device)

        let values = mapper.getCharacteristicValues(for: "52")
        let speedUUID = mapper.characteristicUUID("52", "speed")
        XCTAssertEqual(values[speedUUID] as? Int, 100)
    }

    // MARK: - Menu data generation

    func testGenerateMenuDataEmpty() {
        // No devices loaded
        let menuData = mapper.generateMenuData()
        XCTAssertTrue(menuData.accessories.isEmpty)
    }

    func testGenerateMenuDataNoRooms() {
        // Hubitat does not expose rooms — rooms array is always empty
        let device = makeDevice(id: "60", name: "Light", capabilities: ["Switch"],
                                attributes: ["switch": "on"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        XCTAssertTrue(menuData.rooms.isEmpty)
        XCTAssertNil(menuData.selectedHomeId)
        XCTAssertFalse(menuData.hasCameras)
    }

    func testGenerateMenuDataAccessoryHasNilRoom() {
        let device = makeDevice(id: "61", name: "Outlet", capabilities: ["Switch"],
                                attributes: ["switch": "off"])
        loadSingle(device)

        let menuData = mapper.generateMenuData()
        let accessory = menuData.accessories.first
        XCTAssertNotNil(accessory)
        XCTAssertNil(accessory?.roomIdentifier)
    }
}
