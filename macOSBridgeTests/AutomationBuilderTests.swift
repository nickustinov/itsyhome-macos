import XCTest
@testable import macOSBridge

final class AutomationBuilderTests: XCTestCase {
    func test_validation_requiresTriggerActionAndName() {
        XCTAssertNotNil(AutomationDraft(name: "", trigger: nil, durationSeconds: 0, actionDeviceId: nil).validationError())

        let ok = AutomationDraft(name: "Door", trigger: AccessoryStateTrigger(characteristicId: UUID(),
            accessoryName: "D", characteristicLabel: "C", comparator: .equal, value: 1),
            durationSeconds: 900, actionDeviceId: UUID())
        XCTAssertNil(ok.validationError())
        XCTAssertEqual(ok.build().conditions, [.duration(seconds: 900)])
    }

    func test_zeroDuration_buildsNoCondition() {
        let d = AutomationDraft(name: "x", trigger: AccessoryStateTrigger(characteristicId: UUID(),
            accessoryName: "D", characteristicLabel: "C", comparator: .equal, value: 1),
            durationSeconds: 0, actionDeviceId: UUID())
        XCTAssertTrue(d.build().conditions.isEmpty)
    }
}
