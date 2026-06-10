import XCTest
@testable import macOSBridge

final class AutomationModelTests: XCTestCase {
    func test_codable_roundTrip() throws {
        let automation = Automation(
            id: UUID(), name: "Front Door left open", enabled: true,
            trigger: .accessoryState(AccessoryStateTrigger(
                characteristicId: UUID(), accessoryName: "Front Door",
                characteristicLabel: "Contact", comparator: .equal, value: 1)),
            conditions: [.duration(seconds: 900)],
            actions: [.setVirtualSensor(SetVirtualSensorAction(
                deviceId: UUID(), rePulse: .init(enabled: true, intervalSeconds: 300)))])
        let data = try JSONEncoder().encode(automation)
        XCTAssertEqual(try JSONDecoder().decode(Automation.self, from: data), automation)
    }

    func test_comparator_matchesNumericValues() {
        let t = AccessoryStateTrigger(characteristicId: UUID(), accessoryName: "D",
            characteristicLabel: "Contact", comparator: .equal, value: 1)
        XCTAssertTrue(t.isSatisfied(by: 1))
        XCTAssertTrue(t.isSatisfied(by: true))     // Bool coerces
        XCTAssertFalse(t.isSatisfied(by: 0))
        XCTAssertNil(t.currentValueAsDouble(nil))   // missing -> nil
    }

    func test_durationSeconds_helper() {
        let r = Automation(id: UUID(), name: "x", enabled: true,
            trigger: .accessoryState(AccessoryStateTrigger(characteristicId: UUID(),
                accessoryName: "D", characteristicLabel: "C", comparator: .equal, value: 1)),
            conditions: [.duration(seconds: 600)], actions: [])
        XCTAssertEqual(r.durationSeconds, 600)
    }
}
