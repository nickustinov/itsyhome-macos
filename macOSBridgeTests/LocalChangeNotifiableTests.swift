//
//  LocalChangeNotifiableTests.swift
//  macOSBridgeTests
//
//  Tests for the LocalChangeNotifiable protocol
//

import XCTest
import AppKit
@testable import macOSBridge

final class LocalChangeNotifiableTests: XCTestCase {

    // MARK: - Test helpers

    /// A minimal test menu item that conforms to LocalChangeNotifiable
    private class TestMenuItem: NSMenuItem, LocalChangeNotifiable {}

    // MARK: - Tests

    func testNotifyLocalChangePostsNotification() {
        // Given
        let menuItem = TestMenuItem()
        let characteristicId = UUID()
        let testValue = 42

        let expectation = expectation(description: "Notification should be posted")
        var receivedUserInfo: [AnyHashable: Any]?
        var receivedObject: Any?

        let observer = NotificationCenter.default.addObserver(
            forName: .characteristicDidChangeLocally,
            object: nil,
            queue: .main
        ) { notification in
            receivedUserInfo = notification.userInfo
            receivedObject = notification.object
            expectation.fulfill()
        }

        // When
        menuItem.notifyLocalChange(characteristicId: characteristicId, value: testValue)

        // Then
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertIdentical(receivedObject as AnyObject, menuItem)
        XCTAssertEqual(receivedUserInfo?["characteristicId"] as? UUID, characteristicId)
        XCTAssertEqual(receivedUserInfo?["value"] as? Int, testValue)
    }

    func testNotifyLocalChangeWithBoolValue() {
        // Given
        let menuItem = TestMenuItem()
        let characteristicId = UUID()
        let testValue = true

        let expectation = expectation(description: "Notification should be posted")
        var receivedValue: Bool?

        let observer = NotificationCenter.default.addObserver(
            forName: .characteristicDidChangeLocally,
            object: nil,
            queue: .main
        ) { notification in
            receivedValue = notification.userInfo?["value"] as? Bool
            expectation.fulfill()
        }

        // When
        menuItem.notifyLocalChange(characteristicId: characteristicId, value: testValue)

        // Then
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(receivedValue, true)
    }

    func testNotifyLocalChangeWithDoubleValue() {
        // Given
        let menuItem = TestMenuItem()
        let characteristicId = UUID()
        let testValue = 75.5

        let expectation = expectation(description: "Notification should be posted")
        var receivedValue: Double?

        let observer = NotificationCenter.default.addObserver(
            forName: .characteristicDidChangeLocally,
            object: nil,
            queue: .main
        ) { notification in
            receivedValue = notification.userInfo?["value"] as? Double
            expectation.fulfill()
        }

        // When
        menuItem.notifyLocalChange(characteristicId: characteristicId, value: testValue)

        // Then
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(receivedValue, 75.5)
    }

    func testNotifyLocalChangeWithFloatValue() {
        // Given
        let menuItem = TestMenuItem()
        let characteristicId = UUID()
        let testValue: Float = 33.3

        let expectation = expectation(description: "Notification should be posted")
        var receivedValue: Float?

        let observer = NotificationCenter.default.addObserver(
            forName: .characteristicDidChangeLocally,
            object: nil,
            queue: .main
        ) { notification in
            receivedValue = notification.userInfo?["value"] as? Float
            expectation.fulfill()
        }

        // When
        menuItem.notifyLocalChange(characteristicId: characteristicId, value: testValue)

        // Then
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(receivedValue, 33.3)
    }

    func testMultipleMenuItemsReceiveNotifications() {
        // Given
        let menuItem1 = TestMenuItem()
        let menuItem2 = TestMenuItem()
        let characteristicId = UUID()

        var notificationCount = 0
        let expectation = expectation(description: "Should receive notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .characteristicDidChangeLocally,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
            if notificationCount == 2 {
                expectation.fulfill()
            }
        }

        // When
        menuItem1.notifyLocalChange(characteristicId: characteristicId, value: 1)
        menuItem2.notifyLocalChange(characteristicId: characteristicId, value: 2)

        // Then
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(notificationCount, 2)
    }

    func testNotificationObjectIsCorrectMenuItem() {
        // Given
        let menuItem1 = TestMenuItem()
        let menuItem2 = TestMenuItem()
        let characteristicId = UUID()

        let expectation = expectation(description: "Should receive notification from menuItem1 only")
        var receivedFromCorrectItem = false

        let observer = NotificationCenter.default.addObserver(
            forName: .characteristicDidChangeLocally,
            object: menuItem1,  // Only listen for notifications from menuItem1
            queue: .main
        ) { notification in
            receivedFromCorrectItem = (notification.object as AnyObject) === menuItem1
            expectation.fulfill()
        }

        // When - post from menuItem1
        menuItem1.notifyLocalChange(characteristicId: characteristicId, value: 1)

        // Then
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertTrue(receivedFromCorrectItem)
    }
}
