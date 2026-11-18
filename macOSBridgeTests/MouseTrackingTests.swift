//
//  MouseTrackingTests.swift
//  macOSBridgeTests
//
//  Tests for drags that end outside the control they started on
//

import XCTest
import AppKit
@testable import macOSBridge

private final class ScriptedWindow: NSWindow {
    var queuedEvents: [NSEvent] = []

    override func nextEvent(matching mask: NSEvent.EventTypeMask) -> NSEvent? {
        guard let index = queuedEvents.firstIndex(where: { mask.contains(NSEvent.EventTypeMask(rawValue: 1 << $0.type.rawValue)) }) else {
            return nil
        }
        return queuedEvents.remove(at: index)
    }
}

private final class ActionRecorder: NSObject {
    var values: [Double] = []
    var switchActions = 0

    @objc func sliderChanged(_ sender: ModernSlider) {
        values.append(sender.doubleValue)
    }

    @objc func switchChanged(_ sender: ToggleSwitch) {
        switchActions += 1
    }
}

final class MouseTrackingTests: XCTestCase {

    private let outsideX: CGFloat = 5000
    private let outsideY: CGFloat = 900

    private func makeWindow(containing view: NSView) -> ScriptedWindow {
        let window = ScriptedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(view)
        return window
    }

    private func mouseEvent(_ type: NSEvent.EventType, x: CGFloat, y: CGFloat = 20, in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: NSPoint(x: x, y: y),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    private func dragEndingOutside(in window: NSWindow) -> [NSEvent] {
        [
            mouseEvent(.leftMouseDragged, x: 100, in: window),
            mouseEvent(.leftMouseUp, x: outsideX, y: outsideY, in: window)
        ]
    }

    private func center(of view: NSView) -> NSPoint {
        NSPoint(x: view.frame.midX, y: view.frame.midY)
    }

    private func press(_ view: NSView, releasingAt release: NSPoint, in window: ScriptedWindow) {
        let start = center(of: view)
        window.queuedEvents = [
            mouseEvent(.leftMouseDragged, x: release.x, y: release.y, in: window),
            mouseEvent(.leftMouseUp, x: release.x, y: release.y, in: window)
        ]
        view.mouseDown(with: mouseEvent(.leftMouseDown, x: start.x, y: start.y, in: window))
    }

    private func makeSwitch(recorder: ActionRecorder) -> ToggleSwitch {
        let toggle = ToggleSwitch()
        toggle.frame.origin = NSPoint(x: 100, y: 10)
        toggle.target = recorder
        toggle.action = #selector(ActionRecorder.switchChanged(_:))
        return toggle
    }

    private func makeCircle() -> ClickableColorCircleView {
        ClickableColorCircleView(frame: NSRect(x: 100, y: 10, width: 14, height: 14))
    }

    private func makeRow(containing control: NSView, onAction: @escaping () -> Void) -> HighlightingMenuItemView {
        let row = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        row.closesMenuOnAction = false
        row.onAction = onAction
        row.addSubview(control)
        return row
    }

    // MARK: - Color temperature picker

    func testTempPickerCommitsOnceWhenReleasedOutside() {
        var commits: [Double] = []
        let picker = ColorTempPickerView(currentMired: 300, minMired: 150, maxMired: 500) { commits.append($0) }
        let window = makeWindow(containing: picker)
        window.queuedEvents = dragEndingOutside(in: window)

        picker.mouseDown(with: mouseEvent(.leftMouseDown, x: 50, in: window))

        XCTAssertEqual(commits, [150])
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testTempPickerStopsTrackingAtFirstMouseUp() {
        var commits = 0
        let picker = ColorTempPickerView(currentMired: 300, minMired: 150, maxMired: 500) { _ in commits += 1 }
        let window = makeWindow(containing: picker)
        window.queuedEvents = [
            mouseEvent(.leftMouseUp, x: 60, in: window),
            mouseEvent(.leftMouseDragged, x: 20, in: window)
        ]

        picker.mouseDown(with: mouseEvent(.leftMouseDown, x: 50, in: window))

        XCTAssertEqual(commits, 1)
        XCTAssertEqual(window.queuedEvents.count, 1)
    }

    // MARK: - Color wheel picker

    func testColorWheelMarksOnlyTheReleaseAsFinal() {
        var finalFlags: [Bool] = []
        var lastHue: Double?
        var lastSaturation: Double?
        let picker = ColorWheelPickerView(hue: 0, saturation: 0) { hue, saturation, isFinal in
            finalFlags.append(isFinal)
            lastHue = hue
            lastSaturation = saturation
        }
        let window = makeWindow(containing: picker)
        window.queuedEvents = dragEndingOutside(in: window)

        picker.mouseDown(with: mouseEvent(.leftMouseDown, x: 50, in: window))

        XCTAssertEqual(finalFlags, [false, false, true])
        XCTAssertEqual(lastHue, 360)
        XCTAssertEqual(lastSaturation, 100)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    // MARK: - Slider

    func testSliderSendsFinalValueOnceWhenReleasedOutside() {
        let recorder = ActionRecorder()
        let slider = ModernSlider(minValue: 0, maxValue: 100)
        slider.isContinuous = false
        slider.target = recorder
        slider.action = #selector(ActionRecorder.sliderChanged(_:))
        let window = makeWindow(containing: slider)
        window.queuedEvents = dragEndingOutside(in: window)

        slider.mouseDown(with: mouseEvent(.leftMouseDown, x: 50, in: window))

        XCTAssertEqual(recorder.values, [100])
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testContinuousSliderSendsEachChangeAndTheRelease() {
        let recorder = ActionRecorder()
        let slider = ModernSlider(minValue: 0, maxValue: 100)
        slider.isContinuous = true
        slider.target = recorder
        slider.action = #selector(ActionRecorder.sliderChanged(_:))
        let window = makeWindow(containing: slider)
        window.queuedEvents = [
            mouseEvent(.leftMouseDragged, x: outsideX, in: window),
            mouseEvent(.leftMouseUp, x: outsideX, y: outsideY, in: window)
        ]

        slider.mouseDown(with: mouseEvent(.leftMouseDown, x: 50, in: window))

        XCTAssertEqual(recorder.values.count, 3)
        XCTAssertEqual(recorder.values.last, 100)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    // MARK: - Toggle switch

    func testSwitchTogglesWhenReleasedInside() {
        let recorder = ActionRecorder()
        let toggle = makeSwitch(recorder: recorder)
        let window = makeWindow(containing: toggle)

        press(toggle, releasingAt: center(of: toggle), in: window)

        XCTAssertTrue(toggle.isOn)
        XCTAssertEqual(recorder.switchActions, 1)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testSwitchStaysPutWhenReleasedOutside() {
        let recorder = ActionRecorder()
        let toggle = makeSwitch(recorder: recorder)
        let window = makeWindow(containing: toggle)

        press(toggle, releasingAt: NSPoint(x: outsideX, y: outsideY), in: window)

        XCTAssertFalse(toggle.isOn)
        XCTAssertEqual(recorder.switchActions, 0)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testDisabledSwitchKeepsTheReleaseWithoutToggling() {
        let recorder = ActionRecorder()
        let toggle = makeSwitch(recorder: recorder)
        toggle.isEnabled = false
        let window = makeWindow(containing: toggle)

        press(toggle, releasingAt: NSPoint(x: outsideX, y: outsideY), in: window)

        XCTAssertFalse(toggle.isOn)
        XCTAssertEqual(recorder.switchActions, 0)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testPressOnSwitchReleasedOnRowDoesNotTriggerRow() {
        var rowActions = 0
        let toggle = makeSwitch(recorder: ActionRecorder())
        let row = makeRow(containing: toggle) { rowActions += 1 }
        let window = makeWindow(containing: row)

        press(toggle, releasingAt: NSPoint(x: 20, y: 20), in: window)

        XCTAssertEqual(rowActions, 0)
        XCTAssertFalse(toggle.isOn)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testMouseUpLandingOnSwitchDoesNotTriggerRow() {
        var rowActions = 0
        let toggle = makeSwitch(recorder: ActionRecorder())
        let row = makeRow(containing: toggle) { rowActions += 1 }
        let window = makeWindow(containing: row)
        let point = center(of: toggle)

        toggle.mouseUp(with: mouseEvent(.leftMouseUp, x: point.x, y: point.y, in: window))

        XCTAssertEqual(rowActions, 0)
        XCTAssertFalse(toggle.isOn)
    }

    // MARK: - Color circle buttons

    func testCircleClicksWhenReleasedInside() {
        var clicks = 0
        let circle = makeCircle()
        circle.onClick = { clicks += 1 }
        let window = makeWindow(containing: circle)

        press(circle, releasingAt: center(of: circle), in: window)

        XCTAssertEqual(clicks, 1)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testCircleDoesNotClickWhenReleasedOutside() {
        var clicks = 0
        let circle = makeCircle()
        circle.onClick = { clicks += 1 }
        let window = makeWindow(containing: circle)

        press(circle, releasingAt: NSPoint(x: outsideX, y: outsideY), in: window)

        XCTAssertEqual(clicks, 0)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testPressOnCircleReleasedOnRowDoesNotTriggerRow() {
        var rowActions = 0
        let circle = makeCircle()
        let row = makeRow(containing: circle) { rowActions += 1 }
        let window = makeWindow(containing: row)

        press(circle, releasingAt: NSPoint(x: 20, y: 20), in: window)

        XCTAssertEqual(rowActions, 0)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testMouseUpLandingOnCircleDoesNotTriggerRow() {
        var rowActions = 0
        let circle = makeCircle()
        let row = makeRow(containing: circle) { rowActions += 1 }
        let window = makeWindow(containing: row)
        let point = center(of: circle)

        circle.mouseUp(with: mouseEvent(.leftMouseUp, x: point.x, y: point.y, in: window))

        XCTAssertEqual(rowActions, 0)
    }

    // MARK: - Cover control

    private func makeCoverControl(onAction: @escaping (Int) -> Void) -> CoverControl {
        let control = CoverControl()
        control.frame.origin = NSPoint(x: 100, y: 10)
        control.onAction = onAction
        return control
    }

    func testCoverControlActsOnceWhenReleasedOutside() {
        var actions: [Int] = []
        let control = makeCoverControl { actions.append($0) }
        let window = makeWindow(containing: control)

        press(control, releasingAt: NSPoint(x: outsideX, y: outsideY), in: window)

        XCTAssertEqual(actions, [1])
        XCTAssertEqual(control.coverState, .stopped)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testDisabledCoverControlKeepsTheReleaseWithoutActing() {
        var actions: [Int] = []
        let control = makeCoverControl { actions.append($0) }
        control.isEnabled = false
        let window = makeWindow(containing: control)

        press(control, releasingAt: NSPoint(x: outsideX, y: outsideY), in: window)

        XCTAssertTrue(actions.isEmpty)
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }

    func testPressOnCoverControlReleasedOnRowDoesNotTriggerRow() {
        var rowActions = 0
        var actions: [Int] = []
        let control = makeCoverControl { actions.append($0) }
        let row = makeRow(containing: control) { rowActions += 1 }
        let window = makeWindow(containing: row)

        press(control, releasingAt: NSPoint(x: 20, y: 20), in: window)

        XCTAssertEqual(rowActions, 0)
        XCTAssertEqual(actions, [1])
        XCTAssertTrue(window.queuedEvents.isEmpty)
    }
}
