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
}
