import XCTest
@testable import macOSBridge

final class VirtualControlRoutingTests: XCTestCase {
    func test_verb_mapsToBooleanState() {
        XCTAssertEqual(VirtualControl.boolean(for: .turnOn), true)
        XCTAssertEqual(VirtualControl.boolean(for: .turnOff), false)
        XCTAssertEqual(VirtualControl.boolean(for: .setPosition(100)), true)   // "open"
        XCTAssertEqual(VirtualControl.boolean(for: .setPosition(0)), false)    // "close"
        XCTAssertNil(VirtualControl.boolean(for: .setBrightness(50)))          // not a binary verb
    }

    func test_toggle_flipsCurrentState() {
        XCTAssertEqual(VirtualControl.nextState(forToggleFrom: true), false)
        XCTAssertEqual(VirtualControl.nextState(forToggleFrom: false), true)
    }
}
