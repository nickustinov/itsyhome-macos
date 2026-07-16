//
//  AutoGroupsTests.swift
//  macOSBridgeTests
//
//  Tests for synthesized auto groups
//

import XCTest
@testable import macOSBridge

final class AutoGroupsTests: XCTestCase {

    private func service(type: String, room: UUID? = nil) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: "Device",
            serviceType: type,
            accessoryName: "Accessory",
            roomIdentifier: room
        )
    }

    private func accessory(services: [ServiceData]) -> AccessoryData {
        AccessoryData(
            uniqueIdentifier: UUID(),
            name: "Accessory",
            roomIdentifier: nil,
            services: services,
            isReachable: true
        )
    }

    // MARK: - Threshold

    func testGroupRequiresTwoMembers() {
        let one = [service(type: ServiceTypes.lightbulb)]
        let two = one + [service(type: ServiceTypes.lightbulb)]

        XCTAssertNil(AutoGroups.homeGroup(forToken: "autogroup:lights", accessories: [accessory(services: one)]))
        XCTAssertNotNil(AutoGroups.homeGroup(forToken: "autogroup:lights", accessories: [accessory(services: two)]))
    }

    // MARK: - Type folding

    func testSwitchesGroupFoldsSwitchesAndOutlets() {
        let services = [service(type: ServiceTypes.switch), service(type: ServiceTypes.outlet)]
        let group = AutoGroups.homeGroup(forToken: "autogroup:switches", accessories: [accessory(services: services)])

        XCTAssertEqual(group?.deviceIds.count, 2)
    }

    func testUnrelatedTypesDoNotCount() {
        let services = [service(type: ServiceTypes.lightbulb), service(type: ServiceTypes.lock)]

        XCTAssertNil(AutoGroups.homeGroup(forToken: "autogroup:lights", accessories: [accessory(services: services)]))
        XCTAssertNil(AutoGroups.homeGroup(forToken: "autogroup:locks", accessories: [accessory(services: services)]))
    }

    // MARK: - Identity

    func testDeterministicIds() {
        let services = [service(type: ServiceTypes.lightbulb), service(type: ServiceTypes.lightbulb)]
        let group = AutoGroups.homeGroup(forToken: "autogroup:lights", accessories: [accessory(services: services)])
        XCTAssertEqual(group?.id, "autogroup:home:lights")

        let roomId = "ROOM-1"
        let roomGroup = AutoGroups.roomGroup(forToken: "autogroup:lights", roomId: roomId, services: services)
        XCTAssertEqual(roomGroup?.id, "autogroup:room:ROOM-1:lights")
        XCTAssertEqual(roomGroup?.roomId, roomId)
    }

    func testUnknownTokenYieldsNoDefinition() {
        XCTAssertNil(AutoGroups.definition(forToken: "autogroup:nonsense"))
        XCTAssertNil(AutoGroups.definition(forToken: "section:batteries"))
        XCTAssertNotNil(AutoGroups.definition(forToken: "autogroup:blinds"))
    }

    // MARK: - Room synthesis

    func testRoomGroupsMaterializeInDefinitionOrder() {
        let services = [
            service(type: ServiceTypes.lock), service(type: ServiceTypes.lock),
            service(type: ServiceTypes.lightbulb), service(type: ServiceTypes.lightbulb),
            service(type: ServiceTypes.fan) // single fan – no group
        ]
        let groups = AutoGroups.roomGroups(roomId: "R", services: services)

        XCTAssertEqual(groups.map { $0.token }, ["autogroup:lights", "autogroup:locks"])
        XCTAssertEqual(groups.map { $0.group.deviceIds.count }, [2, 2])
    }

    // MARK: - Group shape

    func testSynthesizedGroupRendersAsSubmenuWithSwitch() {
        let services = [service(type: ServiceTypes.windowCovering), service(type: ServiceTypes.windowCovering)]
        let group = AutoGroups.homeGroup(forToken: "autogroup:blinds", accessories: [accessory(services: services)])

        XCTAssertEqual(group?.showAsSubmenu, true)
        XCTAssertEqual(group?.showGroupSwitch, true)
        XCTAssertEqual(group?.icon, "arrows-out-line-vertical")
        XCTAssertTrue(AutoGroups.isAutoGroupId(group?.id ?? ""))
    }
}
