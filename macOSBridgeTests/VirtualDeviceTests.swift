import XCTest
@testable import macOSBridge

final class VirtualDeviceTests: XCTestCase {
    func test_slug_fromName() {
        XCTAssertEqual(VirtualDevice.slug(from: "Front Door"), "front-door")
        XCTAssertEqual(VirtualDevice.slug(from: "Garage  Motion!"), "garage-motion")
        XCTAssertEqual(VirtualDevice.slug(from: "  CO2 Alarm  "), "co2-alarm")
    }

    func test_codable_roundTrip() throws {
        let d = VirtualDevice(id: UUID(), key: "front-door", name: "Front Door",
                              type: .contact, role: .door, room: "Hallway",
                              aid: 2, state: true)
        let data = try JSONEncoder().encode(d)
        let back = try JSONDecoder().decode(VirtualDevice.self, from: data)
        XCTAssertEqual(back, d)
    }

    func test_allTypes_haveStableRawValues() {
        // Persisted, so raw values must never change.
        XCTAssertEqual(VirtualSensorType.allCases.map(\.rawValue).sorted(),
                       ["carbonDioxide", "carbonMonoxide", "contact", "leak", "motion", "occupancy", "smoke"])
    }
}
