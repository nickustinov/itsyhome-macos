//
//  HubitatPlatformTests.swift
//  macOSBridgeTests
//
//  Tests for HubitatPlatform protocol conformance and default state
//

import XCTest
@testable import macOSBridge

final class HubitatPlatformTests: XCTestCase {

    private var platform: HubitatPlatform!

    override func setUp() {
        super.setUp()
        platform = HubitatPlatform()
    }

    override func tearDown() {
        platform = nil
        super.tearDown()
    }

    // MARK: - Platform type

    func testPlatformType() {
        XCTAssertEqual(platform.platformType, .hubitat)
    }

    // MARK: - Capabilities

    func testCapabilitiesDoNotSupportMultipleHomes() {
        XCTAssertFalse(platform.capabilities.supportsMultipleHomes)
    }

    func testCapabilitiesDoNotSupportSceneStateTracking() {
        XCTAssertFalse(platform.capabilities.supportsSceneStateTracking)
    }

    func testCapabilitiesDoNotSupportOutletInUse() {
        XCTAssertFalse(platform.capabilities.supportsOutletInUse)
    }

    func testCapabilitiesMatchHubitatPreset() {
        let caps = platform.capabilities
        let expected = PlatformCapabilities.hubitat
        XCTAssertEqual(caps.supportsMultipleHomes, expected.supportsMultipleHomes)
        XCTAssertEqual(caps.supportsSceneStateTracking, expected.supportsSceneStateTracking)
        XCTAssertEqual(caps.supportsOutletInUse, expected.supportsOutletInUse)
    }

    // MARK: - Camera support

    func testHasCamerasIsFalse() {
        XCTAssertFalse(platform.hasCameras)
    }

    func testGetCameraSnapshotURLReturnsNil() {
        let url = platform.getCameraSnapshotURL(cameraIdentifier: UUID())
        XCTAssertNil(url)
    }

    func testGetCameraStreamThrows() async {
        do {
            _ = try await platform.getCameraStream(cameraIdentifier: UUID())
            XCTFail("Expected getCameraStream to throw")
        } catch {
            // Expected — Hubitat does not support camera streaming
            XCTAssertTrue(true)
        }
    }

    // MARK: - Home support

    func testAvailableHomesIsEmpty() {
        XCTAssertTrue(platform.availableHomes.isEmpty)
    }

    func testSelectedHomeIdentifierIsNil() {
        XCTAssertNil(platform.selectedHomeIdentifier)
    }

    func testSetSelectedHomeIdentifierIsIgnored() {
        let uuid = UUID()
        platform.selectedHomeIdentifier = uuid
        // Setting should have no effect
        XCTAssertNil(platform.selectedHomeIdentifier)
    }

    // MARK: - Connection state

    func testIsConnectedWhenNoClient() {
        // Before connect() is called, client is nil
        XCTAssertNil(platform.client)
        XCTAssertFalse(platform.isConnected)
    }

    // MARK: - Menu data

    func testGetMenuDataJSONReturnsNilBeforeLoad() {
        XCTAssertNil(platform.getMenuDataJSON())
    }

    func testGetRawDataDumpReturnsNilBeforeLoad() {
        XCTAssertNil(platform.getRawDataDump())
    }
}
