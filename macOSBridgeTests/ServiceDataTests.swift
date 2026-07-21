//
//  ServiceDataTests.swift
//  macOSBridgeTests
//
//  Tests for ServiceData helpers
//

import XCTest
@testable import macOSBridge

final class ServiceDataTests: XCTestCase {

    private func makeService(name: String) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: name,
            serviceType: ServiceTypes.lightbulb,
            accessoryName: name,
            roomIdentifier: nil
        )
    }

    // MARK: - strippingRoomName

    func testStripsRoomNameSeparatedBySpace() {
        let service = makeService(name: "Living Room AC")
        let result = service.strippingRoomName("Living Room")
        XCTAssertEqual(result.name, "AC")
    }

    func testDoesNotStripRoomNameWithoutSpaceSeparator() {
        let service = makeService(name: "Garagenlicht")
        let result = service.strippingRoomName("Garage")
        XCTAssertEqual(result.name, "Garagenlicht")
    }

    func testDoesNotStripRoomNameEmbeddedInWord() {
        let service = makeService(name: "Garagentor")
        let result = service.strippingRoomName("Garage")
        XCTAssertEqual(result.name, "Garagentor")
    }

    func testStripsRoomNameCaseInsensitive() {
        let service = makeService(name: "garage Door")
        let result = service.strippingRoomName("Garage")
        XCTAssertEqual(result.name, "Door")
    }

    func testKeepsNameWhenOnlyRoomName() {
        let service = makeService(name: "Garage")
        let result = service.strippingRoomName("Garage")
        XCTAssertEqual(result.name, "Garage")
    }

    func testKeepsNameWhenNoMatch() {
        let service = makeService(name: "Kitchen Light")
        let result = service.strippingRoomName("Bedroom")
        XCTAssertEqual(result.name, "Kitchen Light")
    }

    // MARK: - Binary sensor characteristic ids (Codable round-trip)

    // ServiceData crosses the iOS <-> macOSBridge process boundary as JSON, so
    // the detected-state characteristic ids must survive encode + decode.
    func testBinarySensorCharacteristicIdsRoundTripThroughCodable() throws {
        let motion = UUID(), contact = UUID(), occupancy = UUID()
        let leak = UUID(), smoke = UUID(), co = UUID(), co2 = UUID()

        let original = ServiceData(
            uniqueIdentifier: UUID(),
            name: "Sensors",
            serviceType: ServiceTypes.leakSensor,
            accessoryName: "Sensors",
            roomIdentifier: nil,
            motionDetectedId: motion,
            contactSensorStateId: contact,
            occupancyDetectedId: occupancy,
            leakDetectedId: leak,
            smokeDetectedId: smoke,
            carbonMonoxideDetectedId: co,
            carbonDioxideDetectedId: co2
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServiceData.self, from: encoded)

        XCTAssertEqual(decoded.motionDetectedId, motion.uuidString)
        XCTAssertEqual(decoded.contactSensorStateId, contact.uuidString)
        XCTAssertEqual(decoded.occupancyDetectedId, occupancy.uuidString)
        XCTAssertEqual(decoded.leakDetectedId, leak.uuidString)
        XCTAssertEqual(decoded.smokeDetectedId, smoke.uuidString)
        XCTAssertEqual(decoded.carbonMonoxideDetectedId, co.uuidString)
        XCTAssertEqual(decoded.carbonDioxideDetectedId, co2.uuidString)
    }

    func testBinarySensorCharacteristicIdsDefaultToNil() {
        let service = makeService(name: "Plain Light")
        XCTAssertNil(service.occupancyDetectedId)
        XCTAssertNil(service.leakDetectedId)
        XCTAssertNil(service.smokeDetectedId)
        XCTAssertNil(service.carbonMonoxideDetectedId)
        XCTAssertNil(service.carbonDioxideDetectedId)
    }

    // MARK: - Temperature setpoint metadata (Codable round-trip)

    // Setpoint step/min/max metadata crosses the iOS <-> macOSBridge process
    // boundary as JSON next to the characteristic ids, so all nine fields must
    // survive encode + decode with their values intact.
    func testSetpointMetadataRoundTripsThroughCodable() throws {
        let original = ServiceData(
            uniqueIdentifier: UUID(),
            name: "Thermostat",
            serviceType: ServiceTypes.thermostat,
            accessoryName: "Thermostat",
            roomIdentifier: nil,
            targetTemperatureId: UUID(),
            targetTemperatureStep: 0.5,
            targetTemperatureMin: 10.0,
            targetTemperatureMax: 30.0,
            coolingThresholdTemperatureId: UUID(),
            coolingThresholdStep: 1.0,
            coolingThresholdMin: 18.3,
            coolingThresholdMax: 33.3,
            heatingThresholdTemperatureId: UUID(),
            heatingThresholdStep: 0.1,
            heatingThresholdMin: 7.2,
            heatingThresholdMax: 26.1
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServiceData.self, from: encoded)

        XCTAssertEqual(decoded.targetTemperatureStep, 0.5)
        XCTAssertEqual(decoded.targetTemperatureMin, 10.0)
        XCTAssertEqual(decoded.targetTemperatureMax, 30.0)
        XCTAssertEqual(decoded.coolingThresholdStep, 1.0)
        XCTAssertEqual(decoded.coolingThresholdMin, 18.3)
        XCTAssertEqual(decoded.coolingThresholdMax, 33.3)
        XCTAssertEqual(decoded.heatingThresholdStep, 0.1)
        XCTAssertEqual(decoded.heatingThresholdMin, 7.2)
        XCTAssertEqual(decoded.heatingThresholdMax, 26.1)
    }

    // Older builds encoded ServiceData without the setpoint metadata fields, so
    // decoding a legacy payload must yield nil for each rather than throwing.
    func testSetpointMetadataDecodesAsNilFromLegacyJSON() throws {
        let legacyJSON = """
        {
            "uniqueIdentifier": "\(UUID().uuidString)",
            "name": "Legacy Thermostat",
            "serviceType": "\(ServiceTypes.thermostat)",
            "accessoryName": "Legacy Thermostat",
            "isReachable": true
        }
        """

        let decoded = try JSONDecoder().decode(ServiceData.self, from: Data(legacyJSON.utf8))

        XCTAssertNil(decoded.targetTemperatureStep)
        XCTAssertNil(decoded.targetTemperatureMin)
        XCTAssertNil(decoded.targetTemperatureMax)
        XCTAssertNil(decoded.heatingThresholdStep)
        XCTAssertNil(decoded.heatingThresholdMin)
        XCTAssertNil(decoded.heatingThresholdMax)
        XCTAssertNil(decoded.coolingThresholdStep)
        XCTAssertNil(decoded.coolingThresholdMin)
        XCTAssertNil(decoded.coolingThresholdMax)
    }
}
