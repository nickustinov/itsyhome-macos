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
}
