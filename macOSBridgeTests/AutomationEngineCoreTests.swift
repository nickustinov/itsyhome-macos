import XCTest
@testable import macOSBridge

final class AutomationEngineCoreTests: XCTestCase {
    private func automation(char cid: UUID, duration: Int?) -> Automation {
        Automation(id: UUID(), name: "x", enabled: true,
            trigger: .accessoryState(AccessoryStateTrigger(characteristicId: cid,
                accessoryName: "D", characteristicLabel: "C", comparator: .equal, value: 1)),
            conditions: duration.map { [.duration(seconds: $0)] } ?? [],
            actions: [])
    }

    func test_trigger_satisfied_withDuration_wantsArming() {
        let cid = UUID()
        let r = automation(char: cid, duration: 900)
        XCTAssertEqual(AutomationEvaluation.desiredPhase(for: r, characteristic: cid, value: 1), .arming(seconds: 900))
        XCTAssertEqual(AutomationEvaluation.desiredPhase(for: r, characteristic: cid, value: 0), .idle)
        XCTAssertNil(AutomationEvaluation.desiredPhase(for: r, characteristic: UUID(), value: 1)) // unrelated char
    }

    func test_trigger_satisfied_noDuration_wantsActiveNow() {
        let cid = UUID()
        let r = automation(char: cid, duration: nil)
        XCTAssertEqual(AutomationEvaluation.desiredPhase(for: r, characteristic: cid, value: 1), .activeNow)
    }

    func test_disabledAutomation_isIdle() {
        let cid = UUID()
        var r = automation(char: cid, duration: 900); r.enabled = false
        XCTAssertEqual(AutomationEvaluation.desiredPhase(for: r, characteristic: cid, value: 1), .idle)
    }
}
