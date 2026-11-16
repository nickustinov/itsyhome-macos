//
//  ProRecheckTests.swift
//  macOSBridgeTests
//
//  Tests for the follow-up entitlement checks after a check found no Pro (#182)
//

import XCTest
@testable import macOSBridge

final class ProRecheckTests: XCTestCase {

    private let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(3)]

    func testChecksAfterEachDelayUntilItFindsPro() async {
        var slept: [Duration] = []
        var results = [false, true, false]

        await ProRecheck.run(delays: delays, sleep: { slept.append($0) }) {
            results.removeFirst()
        }

        XCTAssertEqual(slept, [.seconds(1), .seconds(2)])
        XCTAssertEqual(results, [false], "no check after Pro was found")
    }

    func testGivesUpAfterTheLastDelay() async {
        var slept: [Duration] = []
        var checks = 0

        await ProRecheck.run(delays: delays, sleep: { slept.append($0) }) {
            checks += 1
            return false
        }

        XCTAssertEqual(slept, delays)
        XCTAssertEqual(checks, 3)
    }

    func testStopsWithoutCheckingWhenCancelled() async {
        var checks = 0

        await ProRecheck.run(delays: delays, sleep: { _ in throw CancellationError() }) {
            checks += 1
            return true
        }

        XCTAssertEqual(checks, 0)
    }

    func testTheScheduleStartsSoonAndKeepsWaitingLonger() {
        XCTAssertFalse(ProRecheck.delays.isEmpty)
        XCTAssertLessThanOrEqual(ProRecheck.delays[0], .seconds(30))
        XCTAssertEqual(ProRecheck.delays, ProRecheck.delays.sorted())
    }
}
