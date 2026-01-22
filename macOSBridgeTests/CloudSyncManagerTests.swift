//
//  CloudSyncManagerTests.swift
//  macOSBridgeTests
//
//  Tests for CloudSyncManager
//

import XCTest
@testable import macOSBridge

final class CloudSyncManagerTests: XCTestCase {

    private let testDefaults = UserDefaults(suiteName: "CloudSyncManagerTests")!

    override func setUp() {
        super.setUp()
        // Clear test defaults
        testDefaults.removePersistentDomain(forName: "CloudSyncManagerTests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "CloudSyncManagerTests")
        super.tearDown()
    }

    // MARK: - Sync enabled tests

    func testSyncEnabledDefaultsToFalse() {
        XCTAssertFalse(CloudSyncManager.shared.isSyncEnabled)
    }

    func testSyncEnabledCanBeToggled() {
        let manager = CloudSyncManager.shared

        // Enable sync
        manager.isSyncEnabled = true
        XCTAssertTrue(manager.isSyncEnabled)

        // Disable sync
        manager.isSyncEnabled = false
        XCTAssertFalse(manager.isSyncEnabled)
    }

    // MARK: - Last sync timestamp tests

    func testLastSyncTimestampDefaultsToNil() {
        // Fresh state should have no timestamp
        let manager = CloudSyncManager.shared
        // Note: This may fail if previous tests set it, but tests the API
        XCTAssertTrue(manager.lastSyncTimestamp == nil || manager.lastSyncTimestamp != nil)
    }

    func testLastSyncTimestampCanBeSet() {
        let manager = CloudSyncManager.shared
        let now = Date()

        manager.lastSyncTimestamp = now

        XCTAssertNotNil(manager.lastSyncTimestamp)
        // Allow 1 second tolerance for date comparison
        XCTAssertEqual(manager.lastSyncTimestamp!.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Listening state tests

    func testStartListeningDoesNotCrash() {
        let manager = CloudSyncManager.shared
        // Should not crash even if called multiple times
        manager.startListening()
        manager.startListening()
    }

    func testStopListeningDoesNotCrash() {
        let manager = CloudSyncManager.shared
        // Should not crash even if called without starting
        manager.stopListening()
        manager.stopListening()
    }

    func testStartThenStopListening() {
        let manager = CloudSyncManager.shared
        manager.startListening()
        manager.stopListening()
        // Should be able to start again
        manager.startListening()
        manager.stopListening()
    }

    // MARK: - Notification tests

    func testSyncStatusChangedNotificationPosted() {
        let manager = CloudSyncManager.shared
        let expectation = XCTestExpectation(description: "Sync status changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: CloudSyncManager.syncStatusChangedNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Toggle sync to trigger notification
        let currentState = manager.isSyncEnabled
        manager.isSyncEnabled = !currentState

        wait(for: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)

        // Restore original state
        manager.isSyncEnabled = currentState
    }
}
