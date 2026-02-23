//
//  PreferencesManagerTests.swift
//  macOSBridgeTests
//
//  Tests for PreferencesManager preference storage
//

import XCTest
@testable import macOSBridge

final class PreferencesManagerTests: XCTestCase {

    private let prefs = PreferencesManager.shared
    private let testHomeId = "test-home-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        prefs.currentHomeId = testHomeId
    }

    override func tearDown() {
        // Clean up all test keys
        let defaults = UserDefaults.standard
        let keySuffixes = [
            "orderedFavouriteIds", "favouriteSceneIds", "favouriteServiceIds",
            "hiddenSceneIds", "hiddenServiceIds", "hideScenesSection",
            "hiddenRoomIds", "hiddenCameraIds", "cameraOrder",
            "cameraOverlayAccessories", "deviceGroups", "shortcuts",
            "roomOrder", "sceneOrder", "globalGroupOrder", "groupOrderByRoom",
            "favouriteGroupIds"
        ]
        for suffix in keySuffixes {
            defaults.removeObject(forKey: "\(suffix)_\(testHomeId)")
        }
        defaults.removeObject(forKey: "camerasEnabled")
        defaults.removeObject(forKey: "doorbellAutoClose")
        defaults.removeObject(forKey: "doorbellAutoCloseDelay")
        prefs.currentHomeId = nil
        super.tearDown()
    }

    // MARK: - Cameras enabled (global)

    func testCamerasEnabledDefaultsFalse() {
        XCTAssertFalse(prefs.camerasEnabled)
    }

    func testCamerasEnabledPersists() {
        prefs.camerasEnabled = true
        XCTAssertTrue(prefs.camerasEnabled)
        prefs.camerasEnabled = false
        XCTAssertFalse(prefs.camerasEnabled)
    }

    // MARK: - Doorbell auto-close (global)

    func testDoorbellAutoCloseDefaultsFalse() {
        XCTAssertFalse(prefs.doorbellAutoClose)
    }

    func testDoorbellAutoClosePersists() {
        prefs.doorbellAutoClose = true
        XCTAssertTrue(prefs.doorbellAutoClose)
        prefs.doorbellAutoClose = false
        XCTAssertFalse(prefs.doorbellAutoClose)
    }

    func testDoorbellAutoCloseDelayDefaultsTo60() {
        XCTAssertEqual(prefs.doorbellAutoCloseDelay, 60)
    }

    func testDoorbellAutoCloseDelayPersists() {
        prefs.doorbellAutoCloseDelay = 30
        XCTAssertEqual(prefs.doorbellAutoCloseDelay, 30)
        prefs.doorbellAutoCloseDelay = 300
        XCTAssertEqual(prefs.doorbellAutoCloseDelay, 300)
    }

    // MARK: - Hidden cameras (per-home)

    func testHiddenCameraIdsDefaultsEmpty() {
        XCTAssertTrue(prefs.hiddenCameraIds.isEmpty)
    }

    func testToggleHiddenCamera() {
        let cameraId = "cam-1"
        XCTAssertFalse(prefs.isHidden(cameraId: cameraId))

        prefs.toggleHidden(cameraId: cameraId)
        XCTAssertTrue(prefs.isHidden(cameraId: cameraId))

        prefs.toggleHidden(cameraId: cameraId)
        XCTAssertFalse(prefs.isHidden(cameraId: cameraId))
    }

    func testMultipleHiddenCameras() {
        prefs.toggleHidden(cameraId: "cam-1")
        prefs.toggleHidden(cameraId: "cam-2")
        XCTAssertEqual(prefs.hiddenCameraIds.count, 2)
        XCTAssertTrue(prefs.isHidden(cameraId: "cam-1"))
        XCTAssertTrue(prefs.isHidden(cameraId: "cam-2"))
        XCTAssertFalse(prefs.isHidden(cameraId: "cam-3"))
    }

    // MARK: - Camera order (per-home)

    func testCameraOrderDefaultsEmpty() {
        XCTAssertTrue(prefs.cameraOrder.isEmpty)
    }

    func testCameraOrderPersists() {
        prefs.cameraOrder = ["cam-a", "cam-b", "cam-c"]
        XCTAssertEqual(prefs.cameraOrder, ["cam-a", "cam-b", "cam-c"])
    }

    func testMoveCameraOrder() {
        prefs.cameraOrder = ["cam-a", "cam-b", "cam-c"]
        prefs.moveCameraOrder(from: 0, to: 2)
        XCTAssertEqual(prefs.cameraOrder, ["cam-b", "cam-c", "cam-a"])
    }

    func testMoveCameraOrderOutOfBoundsNoOp() {
        prefs.cameraOrder = ["cam-a", "cam-b"]
        prefs.moveCameraOrder(from: 5, to: 0)
        XCTAssertEqual(prefs.cameraOrder, ["cam-a", "cam-b"])
    }

    // MARK: - Room order (per-home)

    func testRoomOrderDefaultsEmpty() {
        XCTAssertTrue(prefs.roomOrder.isEmpty)
    }

    func testRoomOrderPersists() {
        prefs.roomOrder = ["room-a", "room-b", "room-c"]
        XCTAssertEqual(prefs.roomOrder, ["room-a", "room-b", "room-c"])
    }

    func testMoveRoom() {
        prefs.roomOrder = ["room-a", "room-b", "room-c"]
        prefs.moveRoom(from: 0, to: 2)
        XCTAssertEqual(prefs.roomOrder, ["room-b", "room-c", "room-a"])
    }

    func testMoveRoomToBeginning() {
        prefs.roomOrder = ["room-a", "room-b", "room-c"]
        prefs.moveRoom(from: 2, to: 0)
        XCTAssertEqual(prefs.roomOrder, ["room-c", "room-a", "room-b"])
    }

    func testMoveRoomOutOfBoundsNoOp() {
        prefs.roomOrder = ["room-a", "room-b"]
        prefs.moveRoom(from: 5, to: 0)
        XCTAssertEqual(prefs.roomOrder, ["room-a", "room-b"])
    }

    func testMoveRoomNegativeIndexNoOp() {
        prefs.roomOrder = ["room-a", "room-b"]
        prefs.moveRoom(from: -1, to: 0)
        XCTAssertEqual(prefs.roomOrder, ["room-a", "room-b"])
    }

    // MARK: - Scene order (per-home)

    func testSceneOrderDefaultsEmpty() {
        XCTAssertTrue(prefs.sceneOrder.isEmpty)
    }

    func testSceneOrderPersists() {
        prefs.sceneOrder = ["scene-a", "scene-b", "scene-c"]
        XCTAssertEqual(prefs.sceneOrder, ["scene-a", "scene-b", "scene-c"])
    }

    func testMoveScene() {
        prefs.sceneOrder = ["scene-a", "scene-b", "scene-c"]
        prefs.moveScene(from: 0, to: 2)
        XCTAssertEqual(prefs.sceneOrder, ["scene-b", "scene-c", "scene-a"])
    }

    func testMoveSceneToBeginning() {
        prefs.sceneOrder = ["scene-a", "scene-b", "scene-c"]
        prefs.moveScene(from: 2, to: 0)
        XCTAssertEqual(prefs.sceneOrder, ["scene-c", "scene-a", "scene-b"])
    }

    func testMoveSceneOutOfBoundsNoOp() {
        prefs.sceneOrder = ["scene-a", "scene-b"]
        prefs.moveScene(from: 5, to: 0)
        XCTAssertEqual(prefs.sceneOrder, ["scene-a", "scene-b"])
    }

    func testMoveSceneNegativeIndexNoOp() {
        prefs.sceneOrder = ["scene-a", "scene-b"]
        prefs.moveScene(from: -1, to: 0)
        XCTAssertEqual(prefs.sceneOrder, ["scene-a", "scene-b"])
    }

    // MARK: - Camera overlay accessories (per-home)

    func testOverlayAccessoriesDefaultsEmpty() {
        XCTAssertTrue(prefs.overlayAccessories(for: "cam-1").isEmpty)
    }

    func testAddOverlayAccessory() {
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        XCTAssertEqual(prefs.overlayAccessories(for: "cam-1"), ["svc-1"])
    }

    func testAddMultipleOverlayAccessories() {
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        prefs.addOverlayAccessory(serviceId: "svc-2", to: "cam-1")
        XCTAssertEqual(prefs.overlayAccessories(for: "cam-1"), ["svc-1", "svc-2"])
    }

    func testAddDuplicateOverlayAccessoryNoOp() {
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        XCTAssertEqual(prefs.overlayAccessories(for: "cam-1"), ["svc-1"])
    }

    func testRemoveOverlayAccessory() {
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        prefs.addOverlayAccessory(serviceId: "svc-2", to: "cam-1")
        prefs.removeOverlayAccessory(serviceId: "svc-1", from: "cam-1")
        XCTAssertEqual(prefs.overlayAccessories(for: "cam-1"), ["svc-2"])
    }

    func testRemoveLastOverlayAccessoryCleansUpKey() {
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        prefs.removeOverlayAccessory(serviceId: "svc-1", from: "cam-1")
        XCTAssertTrue(prefs.overlayAccessories(for: "cam-1").isEmpty)
        // Verify the camera key is removed from the mapping
        XCTAssertNil(prefs.cameraOverlayAccessories["cam-1"])
    }

    func testOverlayAccessoriesPerCamera() {
        prefs.addOverlayAccessory(serviceId: "svc-1", to: "cam-1")
        prefs.addOverlayAccessory(serviceId: "svc-2", to: "cam-2")
        XCTAssertEqual(prefs.overlayAccessories(for: "cam-1"), ["svc-1"])
        XCTAssertEqual(prefs.overlayAccessories(for: "cam-2"), ["svc-2"])
    }

    // MARK: - Favourites (per-home)

    func testOrderedFavouriteIdsDefaultsEmpty() {
        XCTAssertTrue(prefs.orderedFavouriteIds.isEmpty)
    }

    func testAddFavourite() {
        prefs.addFavourite(id: "fav-1")
        XCTAssertEqual(prefs.orderedFavouriteIds, ["fav-1"])
    }

    func testAddDuplicateFavouriteNoOp() {
        prefs.addFavourite(id: "fav-1")
        prefs.addFavourite(id: "fav-1")
        XCTAssertEqual(prefs.orderedFavouriteIds, ["fav-1"])
    }

    func testRemoveFavourite() {
        prefs.addFavourite(id: "fav-1")
        prefs.addFavourite(id: "fav-2")
        prefs.removeFavourite(id: "fav-1")
        XCTAssertEqual(prefs.orderedFavouriteIds, ["fav-2"])
    }

    func testMoveFavourite() {
        prefs.orderedFavouriteIds = ["a", "b", "c"]
        prefs.moveFavourite(from: 2, to: 0)
        XCTAssertEqual(prefs.orderedFavouriteIds, ["c", "a", "b"])
    }

    // MARK: - Favourite scenes (per-home)

    func testToggleFavouriteScene() {
        let id = "scene-1"
        XCTAssertFalse(prefs.isFavourite(sceneId: id))

        prefs.toggleFavourite(sceneId: id)
        XCTAssertTrue(prefs.isFavourite(sceneId: id))

        prefs.toggleFavourite(sceneId: id)
        XCTAssertFalse(prefs.isFavourite(sceneId: id))
    }

    func testMoveFavouriteScene() {
        prefs.orderedFavouriteSceneIds = ["s1", "s2", "s3"]
        prefs.moveFavouriteScene(from: 0, to: 2)
        XCTAssertEqual(prefs.orderedFavouriteSceneIds, ["s2", "s3", "s1"])
    }

    // MARK: - Favourite services (per-home)

    func testToggleFavouriteService() {
        let id = "svc-1"
        XCTAssertFalse(prefs.isFavourite(serviceId: id))

        prefs.toggleFavourite(serviceId: id)
        XCTAssertTrue(prefs.isFavourite(serviceId: id))

        prefs.toggleFavourite(serviceId: id)
        XCTAssertFalse(prefs.isFavourite(serviceId: id))
    }

    func testMoveFavouriteService() {
        prefs.orderedFavouriteServiceIds = ["a", "b", "c"]
        prefs.moveFavouriteService(from: 1, to: 0)
        XCTAssertEqual(prefs.orderedFavouriteServiceIds, ["b", "a", "c"])
    }

    // MARK: - Hidden scenes (per-home)

    func testToggleHiddenScene() {
        let id = "scene-1"
        XCTAssertFalse(prefs.isHidden(sceneId: id))

        prefs.toggleHidden(sceneId: id)
        XCTAssertTrue(prefs.isHidden(sceneId: id))

        prefs.toggleHidden(sceneId: id)
        XCTAssertFalse(prefs.isHidden(sceneId: id))
    }

    // MARK: - Hidden services (per-home)

    func testToggleHiddenService() {
        let id = "svc-1"
        XCTAssertFalse(prefs.isHidden(serviceId: id))

        prefs.toggleHidden(serviceId: id)
        XCTAssertTrue(prefs.isHidden(serviceId: id))

        prefs.toggleHidden(serviceId: id)
        XCTAssertFalse(prefs.isHidden(serviceId: id))
    }

    // MARK: - Hidden rooms (per-home)

    func testToggleHiddenRoom() {
        let id = "room-1"
        XCTAssertFalse(prefs.isHidden(roomId: id))

        prefs.toggleHidden(roomId: id)
        XCTAssertTrue(prefs.isHidden(roomId: id))

        prefs.toggleHidden(roomId: id)
        XCTAssertFalse(prefs.isHidden(roomId: id))
    }

    // MARK: - Hide scenes section (per-home)

    func testHideScenesSectionDefaultsFalse() {
        XCTAssertFalse(prefs.hideScenesSection)
    }

    func testHideScenesSectionPersists() {
        prefs.hideScenesSection = true
        XCTAssertTrue(prefs.hideScenesSection)
    }

    // MARK: - Shortcuts (per-home)

    func testShortcutDefaultsNil() {
        XCTAssertNil(prefs.shortcut(for: "fav-1"))
    }

    func testSetShortcut() {
        let shortcut = PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command)
        prefs.setShortcut(shortcut, for: "fav-1")
        let retrieved = prefs.shortcut(for: "fav-1")
        XCTAssertEqual(retrieved, shortcut)
    }

    func testRemoveShortcut() {
        let shortcut = PreferencesManager.ShortcutData(keyCode: 0, modifiers: .command)
        prefs.setShortcut(shortcut, for: "fav-1")
        prefs.removeShortcut(for: "fav-1")
        XCTAssertNil(prefs.shortcut(for: "fav-1"))
    }

    func testFavouriteIdForShortcut() {
        let shortcut = PreferencesManager.ShortcutData(keyCode: 5, modifiers: .option)
        prefs.setShortcut(shortcut, for: "fav-1")
        XCTAssertEqual(prefs.favouriteId(for: shortcut), "fav-1")
    }

    func testFavouriteIdForUnknownShortcutReturnsNil() {
        let shortcut = PreferencesManager.ShortcutData(keyCode: 99, modifiers: .control)
        XCTAssertNil(prefs.favouriteId(for: shortcut))
    }

    // MARK: - Device groups (per-home)

    func testDeviceGroupsDefaultsEmpty() {
        XCTAssertTrue(prefs.deviceGroups.isEmpty)
    }

    func testAddDeviceGroup() {
        let group = DeviceGroup(id: "g1", name: "Test", icon: "folder", deviceIds: ["d1"])
        prefs.addDeviceGroup(group)
        XCTAssertEqual(prefs.deviceGroups.count, 1)
        XCTAssertEqual(prefs.deviceGroups.first?.name, "Test")
    }

    func testUpdateDeviceGroup() {
        let group = DeviceGroup(id: "g1", name: "Old", icon: "folder", deviceIds: [])
        prefs.addDeviceGroup(group)

        let updated = DeviceGroup(id: "g1", name: "New", icon: "lightbulb", deviceIds: ["d1"])
        prefs.updateDeviceGroup(updated)

        XCTAssertEqual(prefs.deviceGroups.count, 1)
        XCTAssertEqual(prefs.deviceGroups.first?.name, "New")
        XCTAssertEqual(prefs.deviceGroups.first?.icon, "lightbulb")
    }

    func testDeleteDeviceGroup() {
        let group = DeviceGroup(id: "g1", name: "Test", icon: "folder", deviceIds: [])
        prefs.addDeviceGroup(group)
        prefs.deleteDeviceGroup(id: "g1")
        XCTAssertTrue(prefs.deviceGroups.isEmpty)
    }

    func testDeleteDeviceGroupRemovesShortcut() {
        let group = DeviceGroup(id: "g1", name: "Test", icon: "folder", deviceIds: [])
        prefs.addDeviceGroup(group)
        let shortcut = PreferencesManager.ShortcutData(keyCode: 1, modifiers: .command)
        prefs.setShortcut(shortcut, for: "g1")

        prefs.deleteDeviceGroup(id: "g1")
        XCTAssertNil(prefs.shortcut(for: "g1"))
    }

    func testMoveDeviceGroup() {
        let g1 = DeviceGroup(id: "g1", name: "First", icon: "folder", deviceIds: [])
        let g2 = DeviceGroup(id: "g2", name: "Second", icon: "folder", deviceIds: [])
        let g3 = DeviceGroup(id: "g3", name: "Third", icon: "folder", deviceIds: [])
        prefs.addDeviceGroup(g1)
        prefs.addDeviceGroup(g2)
        prefs.addDeviceGroup(g3)

        prefs.moveDeviceGroup(from: 0, to: 2)
        XCTAssertEqual(prefs.deviceGroups.map { $0.id }, ["g2", "g3", "g1"])
    }

    func testDeviceGroupById() {
        let group = DeviceGroup(id: "g1", name: "Test", icon: "folder", deviceIds: [])
        prefs.addDeviceGroup(group)
        XCTAssertEqual(prefs.deviceGroup(id: "g1")?.name, "Test")
        XCTAssertNil(prefs.deviceGroup(id: "nonexistent"))
    }

    // MARK: - Per-home isolation

    func testPreferencesArePerHome() {
        let homeA = "home-a-\(UUID().uuidString)"
        let homeB = "home-b-\(UUID().uuidString)"

        prefs.currentHomeId = homeA
        prefs.toggleHidden(cameraId: "cam-1")

        prefs.currentHomeId = homeB
        XCTAssertFalse(prefs.isHidden(cameraId: "cam-1"))

        // Clean up
        prefs.currentHomeId = homeA
        prefs.toggleHidden(cameraId: "cam-1")
        prefs.currentHomeId = homeB
    }

    // MARK: - Notification

    func testSettingPreferencePostsNotification() {
        let expectation = expectation(forNotification: PreferencesManager.preferencesChangedNotification, object: nil)
        prefs.camerasEnabled = true
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Global group order (per-home)

    func testGlobalGroupOrderDefaultsEmpty() {
        XCTAssertTrue(prefs.globalGroupOrder.isEmpty)
    }

    func testGlobalGroupOrderPersists() {
        prefs.globalGroupOrder = ["group-a", "group-b", "group-c"]
        XCTAssertEqual(prefs.globalGroupOrder, ["group-a", "group-b", "group-c"])
    }

    func testMoveGlobalGroup() {
        prefs.globalGroupOrder = ["group-a", "group-b", "group-c"]
        prefs.moveGlobalGroup(from: 0, to: 2)
        XCTAssertEqual(prefs.globalGroupOrder, ["group-b", "group-c", "group-a"])
    }

    func testMoveGlobalGroupToBeginning() {
        prefs.globalGroupOrder = ["group-a", "group-b", "group-c"]
        prefs.moveGlobalGroup(from: 2, to: 0)
        XCTAssertEqual(prefs.globalGroupOrder, ["group-c", "group-a", "group-b"])
    }

    func testMoveGlobalGroupOutOfBoundsNoOp() {
        prefs.globalGroupOrder = ["group-a", "group-b"]
        prefs.moveGlobalGroup(from: 5, to: 0)
        XCTAssertEqual(prefs.globalGroupOrder, ["group-a", "group-b"])
    }

    // MARK: - Group order by room (per-home)

    func testGroupOrderByRoomDefaultsEmpty() {
        XCTAssertTrue(prefs.groupOrderByRoom.isEmpty)
    }

    func testGroupOrderByRoomPersists() {
        prefs.setGroupOrder(["g1", "g2"], forRoom: "room-1")
        XCTAssertEqual(prefs.groupOrder(forRoom: "room-1"), ["g1", "g2"])
    }

    func testMoveGroupInRoom() {
        prefs.setGroupOrder(["g1", "g2", "g3"], forRoom: "room-1")
        prefs.moveGroupInRoom("room-1", from: 0, to: 2)
        XCTAssertEqual(prefs.groupOrder(forRoom: "room-1"), ["g2", "g3", "g1"])
    }

    func testMoveGroupInRoomToBeginning() {
        prefs.setGroupOrder(["g1", "g2", "g3"], forRoom: "room-1")
        prefs.moveGroupInRoom("room-1", from: 2, to: 0)
        XCTAssertEqual(prefs.groupOrder(forRoom: "room-1"), ["g3", "g1", "g2"])
    }

    func testSetEmptyGroupOrderRemovesRoom() {
        prefs.setGroupOrder(["g1"], forRoom: "room-1")
        prefs.setGroupOrder([], forRoom: "room-1")
        XCTAssertNil(prefs.groupOrderByRoom["room-1"])
    }

    // MARK: - Favourite groups (per-home)

    func testFavouriteGroupIdsDefaultsEmpty() {
        XCTAssertTrue(prefs.favouriteGroupIds.isEmpty)
    }

    func testToggleFavouriteGroup() {
        let groupId = "group-1"
        XCTAssertFalse(prefs.isFavouriteGroup(groupId: groupId))

        prefs.toggleFavouriteGroup(groupId: groupId)
        XCTAssertTrue(prefs.isFavouriteGroup(groupId: groupId))

        prefs.toggleFavouriteGroup(groupId: groupId)
        XCTAssertFalse(prefs.isFavouriteGroup(groupId: groupId))
    }

    func testToggleFavouriteGroupAddsToOrderedFavourites() {
        let groupId = "group-1"
        prefs.toggleFavouriteGroup(groupId: groupId)

        XCTAssertTrue(prefs.orderedFavouriteIds.contains("groupFav:\(groupId)"))
    }

    func testToggleFavouriteGroupRemovesFromOrderedFavourites() {
        let groupId = "group-1"
        prefs.toggleFavouriteGroup(groupId: groupId)
        prefs.toggleFavouriteGroup(groupId: groupId)

        XCTAssertFalse(prefs.orderedFavouriteIds.contains("groupFav:\(groupId)"))
    }
}
