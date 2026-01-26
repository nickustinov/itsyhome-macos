//
//  IconOverrideTests.swift
//  macOSBridgeTests
//
//  Tests for custom icon storage in PreferencesManager
//

import XCTest
@testable import macOSBridge

final class IconOverrideTests: XCTestCase {

    private let prefs = PreferencesManager.shared
    private let testHomeId = "test-home-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        prefs.currentHomeId = testHomeId
    }

    override func tearDown() {
        // Clean up test keys
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "customIcons_\(testHomeId)")
        prefs.currentHomeId = nil
        super.tearDown()
    }

    // MARK: - Custom icons storage (per-home)

    func testCustomIconsDefaultsEmpty() {
        XCTAssertTrue(prefs.customIcons.isEmpty)
    }

    func testCustomIconReturnsNilForUnknownItem() {
        XCTAssertNil(prefs.customIcon(for: "unknown-id"))
    }

    func testSetCustomIcon() {
        let itemId = "service-1"
        let iconName = "star"

        prefs.setCustomIcon(iconName, for: itemId)

        XCTAssertEqual(prefs.customIcon(for: itemId), iconName)
    }

    func testSetMultipleCustomIcons() {
        prefs.setCustomIcon("star", for: "item-1")
        prefs.setCustomIcon("heart", for: "item-2")
        prefs.setCustomIcon("lightbulb", for: "item-3")

        XCTAssertEqual(prefs.customIcons.count, 3)
        XCTAssertEqual(prefs.customIcon(for: "item-1"), "star")
        XCTAssertEqual(prefs.customIcon(for: "item-2"), "heart")
        XCTAssertEqual(prefs.customIcon(for: "item-3"), "lightbulb")
    }

    func testUpdateCustomIcon() {
        let itemId = "service-1"

        prefs.setCustomIcon("star", for: itemId)
        XCTAssertEqual(prefs.customIcon(for: itemId), "star")

        prefs.setCustomIcon("heart", for: itemId)
        XCTAssertEqual(prefs.customIcon(for: itemId), "heart")
        XCTAssertEqual(prefs.customIcons.count, 1)
    }

    func testRemoveCustomIcon() {
        let itemId = "service-1"

        prefs.setCustomIcon("star", for: itemId)
        XCTAssertNotNil(prefs.customIcon(for: itemId))

        prefs.setCustomIcon(nil, for: itemId)
        XCTAssertNil(prefs.customIcon(for: itemId))
    }

    func testRemoveCustomIconCleansUpDictionary() {
        prefs.setCustomIcon("star", for: "item-1")
        prefs.setCustomIcon("heart", for: "item-2")

        prefs.setCustomIcon(nil, for: "item-1")

        XCTAssertEqual(prefs.customIcons.count, 1)
        XCTAssertNil(prefs.customIcon(for: "item-1"))
        XCTAssertEqual(prefs.customIcon(for: "item-2"), "heart")
    }

    // MARK: - Per-home isolation

    func testCustomIconsArePerHome() {
        let homeA = "home-a-\(UUID().uuidString)"
        let homeB = "home-b-\(UUID().uuidString)"
        let itemId = "service-1"

        prefs.currentHomeId = homeA
        prefs.setCustomIcon("star", for: itemId)

        prefs.currentHomeId = homeB
        XCTAssertNil(prefs.customIcon(for: itemId))

        prefs.setCustomIcon("heart", for: itemId)
        XCTAssertEqual(prefs.customIcon(for: itemId), "heart")

        prefs.currentHomeId = homeA
        XCTAssertEqual(prefs.customIcon(for: itemId), "star")

        // Clean up
        prefs.setCustomIcon(nil, for: itemId)
        prefs.currentHomeId = homeB
        prefs.setCustomIcon(nil, for: itemId)
    }

    // MARK: - Notification

    func testSettingCustomIconPostsNotification() {
        let expectation = expectation(forNotification: PreferencesManager.preferencesChangedNotification, object: nil)
        prefs.setCustomIcon("star", for: "item-1")
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Persistence

    func testCustomIconsPersist() {
        prefs.setCustomIcon("star", for: "item-1")
        prefs.setCustomIcon("heart", for: "item-2")

        // Simulate app restart by reading from defaults again
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "customIcons_\(testHomeId)"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            XCTAssertEqual(decoded["item-1"], "star")
            XCTAssertEqual(decoded["item-2"], "heart")
        } else {
            XCTFail("Custom icons should persist to UserDefaults")
        }
    }
}
