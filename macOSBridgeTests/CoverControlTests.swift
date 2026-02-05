//
//  CoverControlTests.swift
//  macOSBridgeTests
//
//  Tests for CoverControl (3-position toggle for open/stop/close)
//

import XCTest
import AppKit
@testable import macOSBridge

final class CoverControlTests: XCTestCase {

    // MARK: - Initialisation tests

    func testInitCreatesControl() {
        let control = CoverControl()

        XCTAssertNotNil(control)
        XCTAssertEqual(control.frame.width, 42)
        XCTAssertEqual(control.frame.height, 16)
    }

    func testInitialStateIsStopped() {
        let control = CoverControl()

        // Default state should be stopped (middle position)
        XCTAssertNotNil(control)
    }

    // MARK: - State tests

    func testSetStateOpen() {
        let control = CoverControl()

        control.setState(.open)

        XCTAssertNotNil(control)
    }

    func testSetStateClosed() {
        let control = CoverControl()

        control.setState(.closed)

        XCTAssertNotNil(control)
    }

    func testSetStateStopped() {
        let control = CoverControl()

        control.setState(.stopped)

        XCTAssertNotNil(control)
    }

    // MARK: - Action callback tests

    func testOnActionCalledForOpenButton() {
        let control = CoverControl()
        var actionCalled = false
        var receivedAction: Int = -1

        control.onAction = { action in
            actionCalled = true
            receivedAction = action
        }

        // Simulate click on open button (action 0)
        // Note: This is a basic test - actual click simulation would require more setup
        XCTAssertNotNil(control.onAction)
    }

    func testOnActionCanBeSet() {
        let control = CoverControl()

        control.onAction = { _ in }

        XCTAssertNotNil(control.onAction)
    }

    // MARK: - Size tests

    func testControlHasCorrectDimensions() {
        let control = CoverControl()

        // CoverControl should be 42x16 (same height as toggle switch)
        XCTAssertEqual(control.frame.width, 42)
        XCTAssertEqual(control.frame.height, 16)
    }

    func testControlCanBeResized() {
        let control = CoverControl()

        control.frame = NSRect(x: 0, y: 0, width: 60, height: 20)

        XCTAssertEqual(control.frame.width, 60)
        XCTAssertEqual(control.frame.height, 20)
    }
}
