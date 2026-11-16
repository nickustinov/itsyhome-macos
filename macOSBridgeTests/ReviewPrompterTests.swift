//
//  ReviewPrompterTests.swift
//  macOSBridgeTests
//
//  The rating prompt asks only when the menu closes after the user changed something in it
//

import XCTest
@testable import macOSBridge

final class ReviewPrompterTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "itsyhome.tests.reviewPrompter"
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var asked = 0

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        asked = 0
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func days(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    private func prompter() -> ReviewPrompter {
        ReviewPrompter(rule: ReviewPromptRule(defaults: defaults), version: "3.4.0") { [unowned self] in asked += 1 }
    }

    /// Opens and closes the menu on three different days, without changing anything.
    private func useOnThreeDays(_ prompter: ReviewPrompter) {
        for day in [0.0, 1, 3] {
            prompter.menuWillOpen(now: days(day))
            prompter.menuDidClose(now: days(day))
        }
    }

    func testOpeningTheMenuCountsAsADayOfUse() {
        let prompter = prompter()
        useOnThreeDays(prompter)
        XCTAssertTrue(ReviewPromptRule(defaults: defaults).shouldPrompt(now: days(3)))
        XCTAssertEqual(asked, 0, "just opening the menu never asks")
    }

    func testAsksWhenTheMenuClosesAfterAChange() {
        let prompter = prompter()
        useOnThreeDays(prompter)
        prompter.menuWillOpen(now: days(3))
        prompter.userChangedSomething()
        XCTAssertEqual(asked, 0, "never while the menu is open")
        prompter.menuDidClose(now: days(3))
        XCTAssertEqual(asked, 1)
    }

    func testNotBeforeTheRuleAllows() {
        let prompter = prompter()
        prompter.menuWillOpen(now: days(0))
        prompter.userChangedSomething()
        prompter.menuDidClose(now: days(0))
        XCTAssertEqual(asked, 0)
    }

    func testAsksOnceThenWaitsForTheCooldown() {
        let prompter = prompter()
        useOnThreeDays(prompter)
        for day in [3.0, 4] {
            prompter.menuWillOpen(now: days(day))
            prompter.userChangedSomething()
            prompter.menuDidClose(now: days(day))
        }
        XCTAssertEqual(asked, 1)
    }

    func testAChangeOutsideTheMenuDoesNotCount() {
        let prompter = prompter()
        useOnThreeDays(prompter)
        prompter.userChangedSomething() // a pinned item, with the menu closed
        prompter.menuWillOpen(now: days(3))
        prompter.menuDidClose(now: days(3))
        XCTAssertEqual(asked, 0)
    }
}
