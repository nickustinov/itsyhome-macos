import XCTest
@testable import macOSBridge

final class AutomationEngineRuntimeTests: XCTestCase {
    func test_duration_fires_activation_afterDelay_andClearsOnRelease() {
        let cid = UUID()
        var activated: [Bool] = []
        let engine = AutomationEngine(applyActive: { _, on in activated.append(on) }, deviceExists: { _ in true })
        let automation = Automation(id: UUID(), name: "x", enabled: true,
            trigger: .accessoryState(AccessoryStateTrigger(characteristicId: cid,
                accessoryName: "D", characteristicLabel: "C", comparator: .equal, value: 1)),
            conditions: [.duration(seconds: 0)],   // 0s -> activates almost immediately
            actions: [.setVirtualSensor(SetVirtualSensorAction(deviceId: UUID(),
                rePulse: .init(enabled: false, intervalSeconds: 60)))])
        engine.load([automation])

        engine.handleCharacteristicChange(id: cid, value: 1)
        let activeExp = expectation(description: "activated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(activated, [true]); activeExp.fulfill()
        }
        wait(for: [activeExp], timeout: 1)

        engine.handleCharacteristicChange(id: cid, value: 0)  // door closes
        let clearExp = expectation(description: "cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(activated, [true, false]); clearExp.fulfill()
        }
        wait(for: [clearExp], timeout: 1)
    }
}
