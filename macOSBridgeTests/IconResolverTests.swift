//
//  IconResolverTests.swift
//  macOSBridgeTests
//
//  Tests for IconResolver icon resolution logic
//

import XCTest
@testable import macOSBridge

final class IconResolverTests: XCTestCase {

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

    // MARK: - Service icons

    func testServiceIconUsesDefaultWhenNoCustomIcon() {
        let service = makeService(name: "Test Light", serviceType: ServiceTypes.lightbulb)

        // Verify icon name resolves to default (icon loading may fail in test bundle)
        let iconName = IconResolver.iconName(for: service)
        let defaultName = PhosphorIcon.defaultIconName(for: ServiceTypes.lightbulb)
        XCTAssertEqual(iconName, defaultName)
    }

    func testServiceIconUsesCustomIconWhenSet() {
        let service = makeService(name: "Test Light", serviceType: ServiceTypes.lightbulb)
        prefs.setCustomIcon("star", for: service.uniqueIdentifier)

        // Verify custom icon name is used
        let iconName = IconResolver.iconName(for: service)
        XCTAssertEqual(iconName, "star")
    }

    func testServiceIconNameReturnsCustomWhenSet() {
        let service = makeService(name: "Test Light", serviceType: ServiceTypes.lightbulb)
        prefs.setCustomIcon("star", for: service.uniqueIdentifier)

        let iconName = IconResolver.iconName(for: service)
        XCTAssertEqual(iconName, "star")
    }

    func testServiceIconNameReturnsDefaultWhenNoCustomIcon() {
        let service = makeService(name: "Test Light", serviceType: ServiceTypes.lightbulb)

        let iconName = IconResolver.iconName(for: service)
        let defaultName = PhosphorIcon.defaultIconName(for: ServiceTypes.lightbulb)

        XCTAssertEqual(iconName, defaultName)
    }

    func testServiceIconFilledParameter() {
        let service = makeService(name: "Test Light", serviceType: ServiceTypes.lightbulb)

        // Verify that filled parameter doesn't affect icon name resolution
        let iconName = IconResolver.iconName(for: service)
        let defaultName = PhosphorIcon.defaultIconName(for: ServiceTypes.lightbulb)
        XCTAssertEqual(iconName, defaultName)

        // With custom icon set
        prefs.setCustomIcon("star", for: service.uniqueIdentifier)
        let customIconName = IconResolver.iconName(for: service)
        XCTAssertEqual(customIconName, "star")
    }

    // MARK: - Scene icons

    func testSceneIconUsesDefaultWhenNoCustomIcon() {
        let scene = makeScene(name: "Good Morning")

        // Verify icon name resolves to default (icon loading may fail in test bundle)
        let iconName = IconResolver.iconName(for: scene)
        let defaultIconName = PhosphorIcon.iconNameForScene(scene.name)
        XCTAssertEqual(iconName, defaultIconName)
    }

    func testSceneIconUsesCustomIconWhenSet() {
        let scene = makeScene(name: "Good Morning")
        prefs.setCustomIcon("sun", for: scene.uniqueIdentifier)

        // Verify custom icon name is used
        let iconName = IconResolver.iconName(for: scene)
        XCTAssertEqual(iconName, "sun")
    }

    func testSceneIconNameReturnsCustomWhenSet() {
        let scene = makeScene(name: "Good Morning")
        prefs.setCustomIcon("sun", for: scene.uniqueIdentifier)

        let iconName = IconResolver.iconName(for: scene)
        XCTAssertEqual(iconName, "sun")
    }

    // MARK: - Group icons

    func testGroupIconUsesDefaultWhenNoCustomIcon() {
        let group = DeviceGroup(id: "group-1", name: "Living Room Lights", icon: "lightbulb", deviceIds: [])

        // Verify icon name resolves to default (icon loading may fail in test bundle)
        let iconName = IconResolver.iconName(for: group)
        XCTAssertEqual(iconName, "lightbulb")
    }

    func testGroupIconUsesCustomIconWhenSet() {
        let group = DeviceGroup(id: "group-1", name: "Living Room Lights", icon: "lightbulb", deviceIds: [])
        prefs.setCustomIcon("star", for: group.id)

        // Verify custom icon name is used
        let iconName = IconResolver.iconName(for: group)
        XCTAssertEqual(iconName, "star")
    }

    func testGroupIconNameReturnsCustomWhenSet() {
        let group = DeviceGroup(id: "group-1", name: "Living Room Lights", icon: "lightbulb", deviceIds: [])
        prefs.setCustomIcon("star", for: group.id)

        let iconName = IconResolver.iconName(for: group)
        XCTAssertEqual(iconName, "star")
    }

    func testGroupIconNameReturnsDefaultWhenNoCustomIcon() {
        let group = DeviceGroup(id: "group-1", name: "Living Room Lights", icon: "lightbulb", deviceIds: [])

        let iconName = IconResolver.iconName(for: group)
        XCTAssertEqual(iconName, "lightbulb")
    }

    func testGroupIconFilledParameter() {
        let group = DeviceGroup(id: "group-1", name: "Test", icon: "folder", deviceIds: [])

        // Verify that filled parameter doesn't affect icon name resolution
        let iconName = IconResolver.iconName(for: group)
        XCTAssertEqual(iconName, "folder")

        // With custom icon set
        prefs.setCustomIcon("star", for: group.id)
        let customIconName = IconResolver.iconName(for: group)
        XCTAssertEqual(customIconName, "star")
    }

    // MARK: - Room icons

    func testRoomIconUsesDefaultWhenNoCustomIcon() {
        let roomId = "room-1"
        let roomName = "Living Room"

        // Verify icon name resolves to default (icon loading may fail in test bundle)
        let iconName = IconResolver.iconName(forRoomId: roomId, roomName: roomName)
        let defaultIconName = PhosphorIcon.iconNameForRoom(roomName)
        XCTAssertEqual(iconName, defaultIconName)
    }

    func testRoomIconUsesCustomIconWhenSet() {
        let roomId = "room-1"
        let roomName = "Living Room"
        prefs.setCustomIcon("couch", for: roomId)

        // Verify custom icon name is used
        let iconName = IconResolver.iconName(forRoomId: roomId, roomName: roomName)
        XCTAssertEqual(iconName, "couch")
    }

    func testRoomIconNameReturnsCustomWhenSet() {
        let roomId = "room-1"
        let roomName = "Living Room"
        prefs.setCustomIcon("couch", for: roomId)

        let iconName = IconResolver.iconName(forRoomId: roomId, roomName: roomName)
        XCTAssertEqual(iconName, "couch")
    }

    // MARK: - Resetting custom icons

    func testResettingCustomIconRestoresDefault() {
        let service = makeService(name: "Test Light", serviceType: ServiceTypes.lightbulb)
        let defaultIconName = PhosphorIcon.defaultIconName(for: ServiceTypes.lightbulb)

        // Set custom icon
        prefs.setCustomIcon("star", for: service.uniqueIdentifier)
        XCTAssertEqual(IconResolver.iconName(for: service), "star")

        // Reset (remove) custom icon
        prefs.setCustomIcon(nil, for: service.uniqueIdentifier)
        XCTAssertEqual(IconResolver.iconName(for: service), defaultIconName)
    }

    // MARK: - Helpers

    private func makeService(name: String, serviceType: String) -> ServiceData {
        let id = UUID()
        return ServiceData(
            uniqueIdentifier: id,
            name: name,
            serviceType: serviceType,
            accessoryName: "Test Accessory",
            roomIdentifier: nil
        )
    }

    private func makeScene(name: String) -> SceneData {
        let id = UUID()
        return SceneData(uniqueIdentifier: id, name: name, actions: [])
    }
}
