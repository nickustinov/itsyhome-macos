//
//  MenuSectionOrderTests.swift
//  macOSBridgeTests
//
//  Tests for the top-level menu layout (all sections interleaved with user
//  divider tokens, #144) and its roomOrder mirror.
//

import XCTest
@testable import macOSBridge

final class MenuSectionOrderTests: XCTestCase {

    private let prefs = PreferencesManager.shared
    private let testHomeId = "test-home-\(UUID().uuidString)"

    private let favourites = PreferencesManager.favouritesSectionToken
    private let groups = PreferencesManager.groupsSectionToken
    private let scenes = PreferencesManager.scenesSectionToken
    private let batteries = PreferencesManager.batteriesSectionToken
    private let other = PreferencesManager.otherSectionToken

    override func setUp() {
        super.setUp()
        prefs.currentHomeId = testHomeId
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for suffix in ["menuLayout", "roomOrder"] {
            defaults.removeObject(forKey: "\(suffix)_\(testHomeId)")
        }
        prefs.currentHomeId = nil
        super.tearDown()
    }

    private func isDivider(_ token: String?) -> Bool {
        token?.hasPrefix(PreferencesManager.dividerPrefix) == true
    }

    // MARK: - Seeding

    // First run: no saved layout. The classic menu order – favourites,
    // groups, scenes (dividers between), rooms, other, then batteries after
    // a final divider.
    func testSeedsClassicLayoutWithDividers() {
        let order = prefs.reconciledMenuLayout(roomIds: ["r1", "r2"])
        XCTAssertEqual(order.count, 11)
        XCTAssertEqual(order[0], favourites)
        XCTAssertTrue(isDivider(order[1]))
        XCTAssertEqual(order[2], groups)
        XCTAssertTrue(isDivider(order[3]))
        XCTAssertEqual(order[4], scenes)
        XCTAssertTrue(isDivider(order[5]))
        XCTAssertEqual(Array(order[6...7]), ["r1", "r2"])
        XCTAssertEqual(order[8], other)
        XCTAssertTrue(isDivider(order[9]))
        XCTAssertEqual(order[10], batteries)
    }

    // Users with a customised legacy roomOrder keep their room sequence.
    func testSeedingRespectsLegacyRoomOrder() {
        prefs.roomOrder = ["r2", "r1"]
        let order = prefs.reconciledMenuLayout(roomIds: ["r1", "r2"])
        XCTAssertEqual(Array(order[6...7]), ["r2", "r1"])
    }

    // MARK: - Reconciliation

    func testDropsStaleRoomsAndAppendsNewOnesAfterLastRoom() {
        prefs.menuLayout = [favourites, groups, scenes, "gone", "r1", other, batteries]
        let order = prefs.reconciledMenuLayout(roomIds: ["r1", "r2"])
        XCTAssertEqual(order, [favourites, groups, scenes, "r1", "r2", other, batteries])
    }

    func testCustomSectionPositionsSurviveReconciliation() {
        prefs.menuLayout = ["r1", batteries, favourites, "r2", scenes, groups, other]
        let order = prefs.reconciledMenuLayout(roomIds: ["r1", "r2"])
        XCTAssertEqual(order, ["r1", batteries, favourites, "r2", scenes, groups, other])
    }

    // Dividers stay where the user put them; deleting all of them is a valid
    // state that must not be re-seeded.
    func testUserDividersSurviveAndAreNotReseeded() {
        let divider = PreferencesManager.newDividerToken()
        prefs.menuLayout = [favourites, groups, scenes, "r1", divider, "r2", other, batteries]
        XCTAssertEqual(prefs.reconciledMenuLayout(roomIds: ["r1", "r2"]),
                       [favourites, groups, scenes, "r1", divider, "r2", other, batteries])

        prefs.menuLayout = [favourites, groups, scenes, "r1", "r2", other, batteries]
        XCTAssertEqual(prefs.reconciledMenuLayout(roomIds: ["r1", "r2"]),
                       [favourites, groups, scenes, "r1", "r2", other, batteries])
    }

    // A layout saved by an older version misses section tokens added later;
    // they are seeded without touching the rest.
    func testMissingSectionTokensAreSeeded() {
        prefs.menuLayout = ["r1", "r2"]
        let order = prefs.reconciledMenuLayout(roomIds: ["r1", "r2"])
        XCTAssertEqual(order, [favourites, groups, scenes, "r1", "r2", other, batteries])
    }

    // Pure read: building the menu must not write preferences (a write posts
    // a change notification, which would rebuild the menu in a loop).
    func testReconcileDoesNotPersist() {
        _ = prefs.reconciledMenuLayout(roomIds: ["r1"])
        XCTAssertTrue(prefs.menuLayout.isEmpty)
    }

    func testNormalizePersistsOrderAndMirrorsRoomOrder() {
        let order = prefs.normalizeMenuLayout(roomIds: ["r1", "r2"])
        XCTAssertEqual(prefs.menuLayout, order)
        XCTAssertEqual(prefs.roomOrder, ["r1", "r2"])
    }

    // MARK: - Divider management

    func testAddMenuSectionDividerInsertsAboveToken() {
        prefs.menuLayout = [favourites, "r1", "r2", batteries]
        prefs.addMenuSectionDivider(beforeToken: "r2")
        let order = prefs.menuLayout
        XCTAssertEqual(order.count, 5)
        XCTAssertTrue(isDivider(order[2]))
        XCTAssertEqual(order[3], "r2")
    }

    func testRemoveMenuSectionDivider() {
        let divider = PreferencesManager.newDividerToken()
        prefs.menuLayout = [favourites, divider, "r1", batteries]
        prefs.removeMenuSectionDivider(token: divider)
        XCTAssertEqual(prefs.menuLayout, [favourites, "r1", batteries])
    }

    // MARK: - Mirror

    // Consumers that only understand rooms (webhook API, cloud sync) read
    // roomOrder, so it must track the room subsequence of every new layout –
    // section tokens and dividers must never leak into it.
    func testSettingMenuLayoutMirrorsRoomOrder() {
        let divider = PreferencesManager.newDividerToken()
        prefs.menuLayout = ["r2", scenes, divider, "r1", batteries]
        XCTAssertEqual(prefs.roomOrder, ["r2", "r1"])
    }
}
