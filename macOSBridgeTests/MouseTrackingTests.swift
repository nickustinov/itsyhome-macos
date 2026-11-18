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

    @objc func sliderChanged(_ sender: ModernSlider) {
        values.append(sender.doubleValue)
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
}
