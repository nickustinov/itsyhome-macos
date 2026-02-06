//
//  HomeAssistantBridgeTests.swift
//  macOSBridgeTests
//
//  Tests for HomeAssistantBridge Mac2iOS adapter
//

import XCTest
@testable import macOSBridge

final class HomeAssistantBridgeTests: XCTestCase {

    private var platform: HomeAssistantPlatform!
    private var bridge: HomeAssistantBridge!

    override func setUp() {
        super.setUp()
        platform = HomeAssistantPlatform()
        bridge = HomeAssistantBridge(platform: platform)
    }

    override func tearDown() {
        bridge = nil
        platform = nil
        super.tearDown()
    }

    // MARK: - Homes property tests

    func testHomesReturnsSingleVirtualHome() {
        let homes = bridge.homes

        XCTAssertEqual(homes.count, 1)
        XCTAssertEqual(homes.first?.name, "Home Assistant")
        XCTAssertEqual(homes.first?.isPrimary, true)
    }

    func testHomesHasConsistentUUID() {
        let homes1 = bridge.homes
        let homes2 = bridge.homes

        XCTAssertEqual(homes1.first?.uniqueIdentifier, homes2.first?.uniqueIdentifier)
        XCTAssertEqual(homes1.first?.uniqueIdentifier.uuidString, "00000000-0000-0000-0000-000000000001")
    }

    func testHomesUUIDIsValid() {
        let homes = bridge.homes
        XCTAssertNotNil(homes.first?.uniqueIdentifier)
    }

    // MARK: - Selected home tests

    func testSelectedHomeIdentifierAlwaysNil() {
        XCTAssertNil(bridge.selectedHomeIdentifier)
    }

    func testSettingSelectedHomeIdentifierHasNoEffect() {
        bridge.selectedHomeIdentifier = UUID()
        XCTAssertNil(bridge.selectedHomeIdentifier)
    }

    // MARK: - Empty collections tests

    func testRoomsReturnsEmpty() {
        XCTAssertTrue(bridge.rooms.isEmpty)
    }

    func testAccessoriesReturnsEmpty() {
        XCTAssertTrue(bridge.accessories.isEmpty)
    }

    func testScenesReturnsEmpty() {
        XCTAssertTrue(bridge.scenes.isEmpty)
    }

    // MARK: - Camera window notification tests

    func testOpenCameraWindowPostsNotification() {
        let expectation = expectation(forNotification: .requestOpenCameraWindow, object: nil)

        bridge.openCameraWindow()

        wait(for: [expectation], timeout: 1.0)
    }

    func testCloseCameraWindowPostsNotification() {
        let expectation = expectation(forNotification: .requestCloseCameraWindow, object: nil)

        bridge.closeCameraWindow()

        wait(for: [expectation], timeout: 1.0)
    }

    func testSetCameraWindowHiddenTruePostsNotificationWithHiddenTrue() {
        let expectation = expectation(forNotification: .requestSetCameraWindowHidden, object: nil) { notification in
            let hidden = notification.userInfo?["hidden"] as? Bool
            return hidden == true
        }

        bridge.setCameraWindowHidden(true)

        wait(for: [expectation], timeout: 1.0)
    }

    func testSetCameraWindowHiddenFalsePostsNotificationWithHiddenFalse() {
        let expectation = expectation(forNotification: .requestSetCameraWindowHidden, object: nil) { notification in
            let hidden = notification.userInfo?["hidden"] as? Bool
            return hidden == false
        }

        bridge.setCameraWindowHidden(false)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Mac2iOS protocol conformance tests

    func testBridgeConformsToMac2iOS() {
        XCTAssertTrue(bridge is Mac2iOS)
    }

    func testReloadHomeKitDoesNotThrow() {
        // Just verify it doesn't crash when platform is not connected
        bridge.reloadHomeKit()
    }

    func testExecuteSceneDoesNotThrow() {
        // Just verify it doesn't crash when platform is not connected
        bridge.executeScene(identifier: UUID())
    }

    func testReadCharacteristicDoesNotThrow() {
        // Just verify it doesn't crash when platform is not connected
        bridge.readCharacteristic(identifier: UUID())
    }

    func testWriteCharacteristicDoesNotThrow() {
        // Just verify it doesn't crash when platform is not connected
        bridge.writeCharacteristic(identifier: UUID(), value: 100)
    }

    func testGetCharacteristicValueReturnsNilWhenNotConnected() {
        let value = bridge.getCharacteristicValue(identifier: UUID())
        XCTAssertNil(value)
    }

    func testGetRawHomeKitDumpReturnsNilWhenNotConnected() {
        let dump = bridge.getRawHomeKitDump()
        XCTAssertNil(dump)
    }

    // MARK: - HomeInfo structure tests

    func testHomeInfoHasCorrectProperties() {
        let home = bridge.homes.first!

        XCTAssertEqual(home.name, "Home Assistant")
        XCTAssertTrue(home.isPrimary)
        XCTAssertNotNil(home.uniqueIdentifier)
    }
}

// MARK: - Camera notification names tests

final class CameraNotificationNamesTests: XCTestCase {

    func testRequestOpenCameraWindowNotificationExists() {
        let name = Notification.Name.requestOpenCameraWindow
        XCTAssertFalse(name.rawValue.isEmpty)
    }

    func testRequestCloseCameraWindowNotificationExists() {
        let name = Notification.Name.requestCloseCameraWindow
        XCTAssertFalse(name.rawValue.isEmpty)
    }

    func testRequestSetCameraWindowHiddenNotificationExists() {
        let name = Notification.Name.requestSetCameraWindowHidden
        XCTAssertFalse(name.rawValue.isEmpty)
    }
}
