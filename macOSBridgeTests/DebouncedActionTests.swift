//
//  DebouncedActionTests.swift
//  macOSBridgeTests
//

import XCTest
@testable import macOSBridge

final class DebouncedActionTests: XCTestCase {

    func testRunsOnceAfterDelay() {
        var runs = 0
        let ran = expectation(description: "Action ran")
        let action = DebouncedAction(delay: 0.05) {
            runs += 1
            ran.fulfill()
        }

        action.trigger()
        XCTAssertEqual(runs, 0, "Must not run before the delay")

        wait(for: [ran], timeout: 1)
        XCTAssertEqual(runs, 1)
    }

    func testBurstCoalescesIntoOneRunAfterLastTrigger() {
        var runs = 0
        var firstTriggerTime = Date.distantPast
        var runTime = Date.distantPast
        let ran = expectation(description: "Action ran once")
        let action = DebouncedAction(delay: 0.1) {
            runs += 1
            runTime = Date()
            ran.fulfill()
        }

        firstTriggerTime = Date()
        action.trigger()
        for delay in [0.03, 0.06, 0.09] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action.trigger() }
        }

        wait(for: [ran], timeout: 1)
        // Let any stray extra run land before counting.
        let settled = expectation(description: "Settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 1)

        XCTAssertEqual(runs, 1)
        XCTAssertGreaterThanOrEqual(runTime.timeIntervalSince(firstTriggerTime), 0.18,
                                    "Each trigger restarts the delay")
    }

    func testTriggerAfterRunSchedulesAgain() {
        var runs = 0
        let first = expectation(description: "First run")
        let second = expectation(description: "Second run")
        let action = DebouncedAction(delay: 0.05) {
            runs += 1
            (runs == 1 ? first : second).fulfill()
        }

        action.trigger()
        wait(for: [first], timeout: 1)
        action.trigger()
        wait(for: [second], timeout: 1)

        XCTAssertEqual(runs, 2)
    }

    func testCancelPreventsRun() {
        let ran = expectation(description: "Cancelled action must not run")
        ran.isInverted = true
        let action = DebouncedAction(delay: 0.05) { ran.fulfill() }

        action.trigger()
        action.cancel()

        wait(for: [ran], timeout: 0.2)
    }

    func testReleasingPreventsRun() {
        let ran = expectation(description: "Released action must not run")
        ran.isInverted = true
        var action: DebouncedAction? = DebouncedAction(delay: 0.05) { ran.fulfill() }
        weak var released = action

        action?.trigger()
        action = nil

        XCTAssertNil(released)
        wait(for: [ran], timeout: 0.2)
    }
}
