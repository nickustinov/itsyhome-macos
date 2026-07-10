//
//  MenuSectionOrderTests.swift
//  macOSBridgeTests
//
//  Tests for the top-level menu section order (rooms interleaved with the
//  scenes/batteries section tokens, #144) and its roomOrder mirror.
//

import XCTest
@testable import macOSBridge

final class MenuSectionOrderTests: XCTestCase {

    private let prefs = PreferencesManager.shared
    private let testHomeId = "test-home-\(UUID().uuidString)"

    private let scenes = PreferencesManager.scenesSectionToken
    private let batteries = PreferencesManager.batteriesSectionToken

    override func setUp() {
        super.setUp()
        prefs.currentHomeId = testHomeId
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for suffix in ["menuSectionOrder", "roomOrder"] {
            defaults.removeObject(forKey: "\(suffix)_\(testHomeId)")
        }
        prefs.currentHomeId = nil
        super.tearDown()
    }

    private func isDivider(_ token: String?) -> Bool {
        token?.hasPrefix(PreferencesManager.dividerPrefix) == true
    }

    // MARK: - Seeding

    // First run: no saved order. Scenes must lead and batteries trail, with
    // rooms in between and a divider on each side of the rooms block – the
    // classic menu layout.
    func testSeedsScenesFirstRoomsThenBatteriesWithDividers() {
        let order = prefs.reconciledMenuSectionOrder(roomIds: ["r1", "r2"])
        XCTAssertEqual(order.count, 6)
        XCTAssertEqual(order.first, scenes)
        XCTAssertTrue(isDivider(order[1]))
        XCTAssertEqual(Array(order[2...3]), ["r1", "r2"])
        XCTAssertTrue(isDivider(order[4]))
        XCTAssertEqual(order.last, batteries)
    }

    // Users with a customised legacy roomOrder keep their room sequence.
    func testSeedingRespectsLegacyRoomOrder() {
        prefs.roomOrder = ["r2", "r1"]
        let order = prefs.reconciledMenuSectionOrder(roomIds: ["r1", "r2"])
        XCTAssertEqual(Array(order[2...3]), ["r2", "r1"])
    }

    // MARK: - Reconciliation

    func testDropsStaleRoomsAndAppendsNewOnesAfterLastRoom() {
        prefs.menuSectionOrder = [scenes, "gone", "r1", batteries]
        let order = prefs.reconciledMenuSectionOrder(roomIds: ["r1", "r2"])
        XCTAssertEqual(order, [scenes, "r1", "r2", batteries])
    }

    func testCustomSectionPositionsSurviveReconciliation() {
        prefs.menuSectionOrder = ["r1", batteries, "r2", scenes]
        let order = prefs.reconciledMenuSectionOrder(roomIds: ["r1", "r2"])
        XCTAssertEqual(order, ["r1", batteries, "r2", scenes])
    }

    // Dividers stay where the user put them; deleting all of them is a valid
    // state that must not be re-seeded.
    func testUserDividersSurviveAndAreNotReseeded() {
        let divider = "\(PreferencesManager.dividerPrefix)\(UUID().uuidString)"
        prefs.menuSectionOrder = [scenes, "r1", divider, "r2", batteries]
        XCTAssertEqual(prefs.reconciledMenuSectionOrder(roomIds: ["r1", "r2"]),
                       [scenes, "r1", divider, "r2", batteries])

        prefs.menuSectionOrder = [scenes, "r1", "r2", batteries]
        XCTAssertEqual(prefs.reconciledMenuSectionOrder(roomIds: ["r1", "r2"]),
                       [scenes, "r1", "r2", batteries])
    }

    // MARK: - Divider management

    func testAddMenuSectionDividerInsertsAboveToken() {
        prefs.menuSectionOrder = [scenes, "r1", "r2", batteries]
        prefs.addMenuSectionDivider(beforeToken: "r2")
        let order = prefs.menuSectionOrder
        XCTAssertEqual(order.count, 5)
        XCTAssertTrue(isDivider(order[2]))
        XCTAssertEqual(order[3], "r2")
    }

    func testRemoveMenuSectionDivider() {
        let divider = "\(PreferencesManager.dividerPrefix)\(UUID().uuidString)"
        prefs.menuSectionOrder = [scenes, divider, "r1", batteries]
        prefs.removeMenuSectionDivider(token: divider)
        XCTAssertEqual(prefs.menuSectionOrder, [scenes, "r1", batteries])
    }

    // Pure read: building the menu must not write preferences (a write posts
    // a change notification, which would rebuild the menu in a loop).
    func testReconcileDoesNotPersist() {
        _ = prefs.reconciledMenuSectionOrder(roomIds: ["r1"])
        XCTAssertTrue(prefs.menuSectionOrder.isEmpty)
    }

    func testNormalizePersistsOrderAndMirrorsRoomOrder() {
        let order = prefs.normalizeMenuSectionOrder(roomIds: ["r1", "r2"])
        XCTAssertEqual(prefs.menuSectionOrder, order)
        XCTAssertEqual(prefs.roomOrder, ["r1", "r2"])
    }

    // MARK: - Mirror

    // Consumers that only understand rooms (webhook API, cloud sync) read
    // roomOrder, so it must track the room subsequence of every new order –
    // section tokens and dividers must never leak into it.
    func testSettingMenuSectionOrderMirrorsRoomOrder() {
        let divider = "\(PreferencesManager.dividerPrefix)\(UUID().uuidString)"
        prefs.menuSectionOrder = ["r2", scenes, divider, "r1", batteries]
        XCTAssertEqual(prefs.roomOrder, ["r2", "r1"])
    }

    func testMoveMenuSectionReordersTokens() {
        prefs.menuSectionOrder = [scenes, "r1", "r2", batteries]
        prefs.moveMenuSection(from: 3, to: 1)
        XCTAssertEqual(prefs.menuSectionOrder, [scenes, batteries, "r1", "r2"])
        XCTAssertEqual(prefs.roomOrder, ["r1", "r2"])
    }
}
