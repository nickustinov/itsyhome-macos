//
//  ReviewPromptRuleTests.swift
//  macOSBridgeTests
//
//  When Itsyhome asks for an App Store rating
//

import XCTest
@testable import macOSBridge

final class ReviewPromptRuleTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "itsyhome.tests.review"
    private var calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_800_000_000) // a Friday, 10:00 UTC

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "UTC")!
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func rule() -> ReviewPromptRule { ReviewPromptRule(defaults: defaults, calendar: calendar) }
    private func days(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    func testNeverOnTheFirstUse() {
        rule().recordUse(on: start, version: "3.4.0")
        XCTAssertFalse(rule().shouldPrompt(now: start))
    }

    func testAfterThreeDaysOfUseOnceTheVersionIsTwoDaysOld() {
        rule().recordUse(on: days(0), version: "3.4.0")
        rule().recordUse(on: days(1), version: "3.4.0")
        rule().recordUse(on: days(3), version: "3.4.0")
        XCTAssertTrue(rule().shouldPrompt(now: days(3)))
    }

    func testUsesOnTheSameDayCountOnce() {
        rule().recordUse(on: days(0), version: "3.4.0")
        rule().recordUse(on: days(0.1), version: "3.4.0")
        rule().recordUse(on: days(0.2), version: "3.4.0")
        rule().recordUse(on: days(3), version: "3.4.0")
        XCTAssertFalse(rule().shouldPrompt(now: days(3)))
    }

    func testNotWithinTwoDaysOfANewVersion() {
        rule().recordUse(on: days(0), version: "3.4.0")
        rule().recordUse(on: days(1), version: "3.4.0")
        rule().recordUse(on: days(3), version: "3.4.1")
        XCTAssertFalse(rule().shouldPrompt(now: days(4)))
        XCTAssertTrue(rule().shouldPrompt(now: days(5.1)))
    }

    func testNotAgainFor120Days() {
        for day in [0.0, 1, 3] { rule().recordUse(on: days(day), version: "3.4.0") }
        rule().recordPrompt(now: days(3))
        XCTAssertFalse(rule().shouldPrompt(now: days(100)))
        XCTAssertTrue(rule().shouldPrompt(now: days(124)))
    }
}
