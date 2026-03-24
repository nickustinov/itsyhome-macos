//
//  HubitatModelsTests.swift
//  macOSBridgeTests
//
//  Tests for Hubitat data model parsing
//

import XCTest
@testable import macOSBridge

final class HubitatModelsTests: XCTestCase {

    // MARK: - HubitatDeviceSummary

    func testParseDeviceSummary() {
        let json: [String: Any] = [
            "id": "42",
            "name": "Kitchen Light",
            "label": "Kitchen"
        ]
        let summary = HubitatDeviceSummary(json: json)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.id, "42")
        XCTAssertEqual(summary?.name, "Kitchen Light")
        XCTAssertEqual(summary?.label, "Kitchen")
    }

    func testParseDeviceSummaryWithIntId() {
        let json: [String: Any] = [
            "id": 99,
            "name": "Bedroom Fan"
        ]
        let summary = HubitatDeviceSummary(json: json)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.id, "99")
    }

    func testParseDeviceSummaryMissingIdReturnsNil() {
        let json: [String: Any] = [
            "name": "No ID Device"
        ]
        let summary = HubitatDeviceSummary(json: json)
        XCTAssertNil(summary)
    }

    func testParseDeviceSummaryEmptyLabelTreatedAsNil() {
        let json: [String: Any] = [
            "id": "10",
            "name": "Switch",
            "label": ""
        ]
        let summary = HubitatDeviceSummary(json: json)
        XCTAssertNil(summary?.label)
    }

    // MARK: - HubitatDevice

    func testParseDeviceDetail() {
        let json: [String: Any] = [
            "id": "7",
            "name": "Main Switch",
            "label": "Living Room Switch",
            "type": "Generic Z-Wave Switch",
            "manufacturer": "GE",
            "model": "12722",
            "capabilities": ["Switch", "Refresh"],
            "attributes": ["switch": "off"],
            "commands": [
                ["command": "on"],
                ["command": "off"],
                ["command": "refresh"]
            ]
        ]
        let device = HubitatDevice(json: json)
        XCTAssertNotNil(device)
        XCTAssertEqual(device?.id, "7")
        XCTAssertEqual(device?.name, "Main Switch")
        XCTAssertEqual(device?.label, "Living Room Switch")
        XCTAssertEqual(device?.type, "Generic Z-Wave Switch")
        XCTAssertEqual(device?.manufacturer, "GE")
        XCTAssertEqual(device?.model, "12722")
        XCTAssertEqual(device?.capabilities, ["Switch", "Refresh"])
        XCTAssertEqual(device?.attributes["switch"] as? String, "off")
        XCTAssertEqual(device?.commands.count, 3)
        XCTAssertEqual(device?.commands.first?.command, "on")
    }

    func testDisplayNamePrefersLabel() {
        let json: [String: Any] = [
            "id": "1",
            "name": "Device Name",
            "label": "My Fancy Label",
            "capabilities": [],
            "attributes": [:] as [String: Any],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)
        XCTAssertEqual(device?.displayName, "My Fancy Label")
    }

    func testDisplayNameFallsBackToName() {
        let json: [String: Any] = [
            "id": "1",
            "name": "Device Name",
            "label": "",
            "capabilities": [],
            "attributes": [:] as [String: Any],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)
        XCTAssertEqual(device?.displayName, "Device Name")
    }

    func testHasCapability() {
        let json: [String: Any] = [
            "id": "2",
            "name": "Dimmer",
            "capabilities": ["Switch", "SwitchLevel"],
            "attributes": [:] as [String: Any],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)!
        XCTAssertTrue(device.hasCapability("Switch"))
        XCTAssertTrue(device.hasCapability("SwitchLevel"))
        XCTAssertFalse(device.hasCapability("Lock"))
    }

    func testAttributeStringFromInt() {
        let json: [String: Any] = [
            "id": "3",
            "name": "Dimmer",
            "capabilities": [],
            "attributes": ["level": 75],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)!
        XCTAssertEqual(device.attributeString("level"), "75")
    }

    func testAttributeDoubleFromString() {
        let json: [String: Any] = [
            "id": "4",
            "name": "Sensor",
            "capabilities": [],
            "attributes": ["temperature": "72.5"],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)!
        XCTAssertEqual(device.attributeDouble("temperature"), 72.5)
    }

    func testAttributeIntFromDouble() {
        let json: [String: Any] = [
            "id": "5",
            "name": "Sensor",
            "capabilities": [],
            "attributes": ["level": 80.0],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)!
        XCTAssertEqual(device.attributeInt("level"), 80)
    }

    func testCapabilitiesHandleObjectFormat() {
        let json: [String: Any] = [
            "id": "6",
            "name": "Smart Bulb",
            "capabilities": [
                ["name": "Switch"],
                ["name": "SwitchLevel"],
                ["name": "ColorControl"]
            ],
            "attributes": [:] as [String: Any],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)!
        XCTAssertEqual(device.capabilities, ["Switch", "SwitchLevel", "ColorControl"])
    }

    func testCapabilitiesMixedFormat() {
        let json: [String: Any] = [
            "id": "6",
            "name": "Mixed",
            "capabilities": [
                "Switch",
                ["name": "SwitchLevel"]
            ] as [Any],
            "attributes": [:] as [String: Any],
            "commands": [] as [[String: Any]]
        ]
        let device = HubitatDevice(json: json)!
        XCTAssertEqual(device.capabilities.count, 2)
        XCTAssertTrue(device.hasCapability("Switch"))
        XCTAssertTrue(device.hasCapability("SwitchLevel"))
    }

    // MARK: - HubitatCommand

    func testParseCommand() {
        let json: [String: Any] = [
            "command": "setLevel",
            "type": ["NUMBER"]
        ]
        let command = HubitatCommand(json: json)
        XCTAssertNotNil(command)
        XCTAssertEqual(command?.command, "setLevel")
        XCTAssertEqual(command?.parameterTypes, ["NUMBER"])
    }

    func testParseCommandWithoutParams() {
        let json: [String: Any] = [
            "command": "on"
        ]
        let command = HubitatCommand(json: json)
        XCTAssertNotNil(command)
        XCTAssertEqual(command?.command, "on")
        XCTAssertNil(command?.parameterTypes)
    }

    func testParseCommandMissingCommandKeyReturnsNil() {
        let json: [String: Any] = [
            "type": ["NUMBER"]
        ]
        let command = HubitatCommand(json: json)
        XCTAssertNil(command)
    }

    // MARK: - HubitatEvent

    func testParseDeviceEvent() {
        let json: [String: Any] = [
            "source": "DEVICE",
            "name": "switch",
            "displayName": "Kitchen Light",
            "value": "on",
            "deviceId": "42",
            "descriptionText": "Kitchen Light switch is on",
            "unit": nil as String? as Any,
            "type": nil as String? as Any,
            "data": nil as String? as Any
        ]
        let event = HubitatEvent(json: json)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.source, "DEVICE")
        XCTAssertEqual(event?.name, "switch")
        XCTAssertEqual(event?.displayName, "Kitchen Light")
        XCTAssertEqual(event?.value, "on")
        XCTAssertEqual(event?.deviceId, "42")
        XCTAssertEqual(event?.descriptionText, "Kitchen Light switch is on")
    }

    func testIsDeviceEvent() {
        let deviceJson: [String: Any] = [
            "source": "DEVICE",
            "name": "switch",
            "value": "on",
            "deviceId": "5"
        ]
        let deviceEvent = HubitatEvent(json: deviceJson)!
        XCTAssertTrue(deviceEvent.isDeviceEvent)

        let locationJson: [String: Any] = [
            "source": "LOCATION",
            "name": "hsmStatus",
            "value": "armedAway"
        ]
        let locationEvent = HubitatEvent(json: locationJson)!
        XCTAssertFalse(locationEvent.isDeviceEvent)
    }

    func testParseEventWithNumericValue() {
        let json: [String: Any] = [
            "source": "DEVICE",
            "name": "level",
            "value": 75,
            "deviceId": "10"
        ]
        let event = HubitatEvent(json: json)
        XCTAssertEqual(event?.value, "75")
    }

    func testParseEventWithIntDeviceId() {
        let json: [String: Any] = [
            "source": "DEVICE",
            "name": "switch",
            "value": "off",
            "deviceId": 123
        ]
        let event = HubitatEvent(json: json)
        XCTAssertEqual(event?.deviceId, "123")
    }

    func testParseEventMissingSourceReturnsNil() {
        let json: [String: Any] = [
            "name": "switch",
            "value": "on"
        ]
        XCTAssertNil(HubitatEvent(json: json))
    }

    // MARK: - HubitatHSMStatus

    func testParseHSMStatus() {
        let json: [String: Any] = [
            "hsm": "armedAway"
        ]
        let status = HubitatHSMStatus(json: json)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.status, "armedAway")
    }

    func testParseHSMStatusMissingKeyReturnsNil() {
        let json: [String: Any] = [
            "status": "armedAway"
        ]
        XCTAssertNil(HubitatHSMStatus(json: json))
    }

    // MARK: - HubitatMode

    func testParseMode() {
        let json: [String: Any] = [
            "id": 3,
            "name": "Night",
            "active": true
        ]
        let mode = HubitatMode(json: json)
        XCTAssertNotNil(mode)
        XCTAssertEqual(mode?.id, "3")
        XCTAssertEqual(mode?.name, "Night")
        XCTAssertTrue(mode?.active ?? false)
    }

    func testParseModeWithStringId() {
        let json: [String: Any] = [
            "id": "5",
            "name": "Away",
            "active": false
        ]
        let mode = HubitatMode(json: json)
        XCTAssertNotNil(mode)
        XCTAssertEqual(mode?.id, "5")
        XCTAssertFalse(mode?.active ?? true)
    }

    func testParseModeDefaultsActiveToFalse() {
        let json: [String: Any] = [
            "id": 1,
            "name": "Home"
        ]
        let mode = HubitatMode(json: json)
        XCTAssertNotNil(mode)
        XCTAssertFalse(mode?.active ?? true)
    }

    func testParseModesMissingIdReturnsNil() {
        let json: [String: Any] = [
            "name": "Evening"
        ]
        XCTAssertNil(HubitatMode(json: json))
    }
}
