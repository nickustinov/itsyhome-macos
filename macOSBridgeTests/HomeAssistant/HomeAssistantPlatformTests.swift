//
//  HomeAssistantPlatformTests.swift
//  macOSBridgeTests
//
//  Tests for HomeAssistantPlatform SmartHomePlatform implementation
//

import XCTest
@testable import macOSBridge

final class HomeAssistantPlatformTests: XCTestCase {

    // MARK: - Platform type tests

    func testPlatformTypeIsHomeAssistant() {
        let platform = HomeAssistantPlatform()
        XCTAssertEqual(platform.platformType, .homeAssistant)
    }

    // MARK: - Capabilities tests

    func testCapabilitiesDoNotSupportMultipleHomes() {
        let platform = HomeAssistantPlatform()
        XCTAssertFalse(platform.capabilities.supportsMultipleHomes)
    }

    func testCapabilitiesDoNotSupportSceneStateTracking() {
        let platform = HomeAssistantPlatform()
        XCTAssertFalse(platform.capabilities.supportsSceneStateTracking)
    }

    func testCapabilitiesDoNotSupportOutletInUse() {
        let platform = HomeAssistantPlatform()
        XCTAssertFalse(platform.capabilities.supportsOutletInUse)
    }

    // MARK: - Available homes tests

    func testAvailableHomesIsEmpty() {
        let platform = HomeAssistantPlatform()
        XCTAssertTrue(platform.availableHomes.isEmpty)
    }

    // MARK: - Selected home tests

    func testSelectedHomeIdentifierAlwaysNil() {
        let platform = HomeAssistantPlatform()
        XCTAssertNil(platform.selectedHomeIdentifier)
    }

    func testSettingSelectedHomeIdentifierHasNoEffect() {
        let platform = HomeAssistantPlatform()
        platform.selectedHomeIdentifier = UUID()
        XCTAssertNil(platform.selectedHomeIdentifier)
    }

    // MARK: - Connection state tests

    func testIsConnectedFalseWhenNotConnected() {
        let platform = HomeAssistantPlatform()
        XCTAssertFalse(platform.isConnected)
    }

    // MARK: - PlatformCapabilities static tests

    func testHomeAssistantCapabilitiesStatic() {
        let caps = PlatformCapabilities.homeAssistant

        XCTAssertFalse(caps.supportsMultipleHomes)
        XCTAssertFalse(caps.supportsSceneStateTracking)
        XCTAssertFalse(caps.supportsOutletInUse)
    }

    func testHomeKitCapabilitiesStatic() {
        let caps = PlatformCapabilities.homeKit

        XCTAssertTrue(caps.supportsMultipleHomes)
        XCTAssertTrue(caps.supportsSceneStateTracking)
        XCTAssertTrue(caps.supportsOutletInUse)
    }

    // MARK: - SmartHomePlatformType tests

    func testSmartHomePlatformTypeRawValues() {
        XCTAssertEqual(SmartHomePlatformType.homeKit.rawValue, "homekit")
        XCTAssertEqual(SmartHomePlatformType.homeAssistant.rawValue, "homeassistant")
    }

    func testSmartHomePlatformTypeFromRawValue() {
        XCTAssertEqual(SmartHomePlatformType(rawValue: "homekit"), .homeKit)
        XCTAssertEqual(SmartHomePlatformType(rawValue: "homeassistant"), .homeAssistant)
        XCTAssertNil(SmartHomePlatformType(rawValue: "invalid"))
    }

    func testSmartHomePlatformTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let homeKit = SmartHomePlatformType.homeKit
        let data = try encoder.encode(homeKit)
        let decoded = try decoder.decode(SmartHomePlatformType.self, from: data)

        XCTAssertEqual(decoded, homeKit)
    }

    // MARK: - Delegate tests

    func testDelegateCanBeSet() {
        let platform = HomeAssistantPlatform()
        let delegate = MockPlatformDelegate()

        platform.delegate = delegate

        XCTAssertNotNil(platform.delegate)
    }

    func testDelegateIsWeak() {
        let platform = HomeAssistantPlatform()

        autoreleasepool {
            let delegate = MockPlatformDelegate()
            platform.delegate = delegate
            XCTAssertNotNil(platform.delegate)
        }

        // Delegate should be nil after going out of scope
        XCTAssertNil(platform.delegate)
    }

    // MARK: - Menu data tests

    func testGetMenuDataJSONReturnsNilBeforeConnect() {
        let platform = HomeAssistantPlatform()
        XCTAssertNil(platform.getMenuDataJSON())
    }

    // MARK: - Has cameras tests

    func testHasCamerasFalseBeforeConnect() {
        let platform = HomeAssistantPlatform()
        XCTAssertFalse(platform.hasCameras)
    }
}

// MARK: - Mock Delegate

private class MockPlatformDelegate: SmartHomePlatformDelegate {

    var didUpdateMenuDataCalled = false
    var didUpdateCharacteristicCalled = false
    var didUpdateReachabilityCalled = false
    var didEncounterErrorCalled = false
    var didDisconnectCalled = false
    var didReceiveDoorbellEventCalled = false

    var lastMenuDataJSON: String?
    var lastCharacteristicId: UUID?
    var lastCharacteristicValue: Any?
    var lastErrorMessage: String?

    func platformDidUpdateMenuData(_ platform: SmartHomePlatform, jsonString: String) {
        didUpdateMenuDataCalled = true
        lastMenuDataJSON = jsonString
    }

    func platformDidUpdateCharacteristic(_ platform: SmartHomePlatform, identifier: UUID, value: Any) {
        didUpdateCharacteristicCalled = true
        lastCharacteristicId = identifier
        lastCharacteristicValue = value
    }

    func platformDidUpdateReachability(_ platform: SmartHomePlatform, accessoryIdentifier: UUID, isReachable: Bool) {
        didUpdateReachabilityCalled = true
    }

    func platformDidEncounterError(_ platform: SmartHomePlatform, message: String) {
        didEncounterErrorCalled = true
        lastErrorMessage = message
    }

    func platformDidDisconnect(_ platform: SmartHomePlatform) {
        didDisconnectCalled = true
    }

    func platformDidReceiveDoorbellEvent(_ platform: SmartHomePlatform, cameraIdentifier: UUID) {
        didReceiveDoorbellEventCalled = true
    }
}

// MARK: - CameraStreamInfo tests

final class CameraStreamInfoTests: XCTestCase {

    func testHLSStreamType() {
        let url = URL(string: "http://example.com/stream.m3u8")!
        let streamType = CameraStreamInfo.StreamType.hls(url: url)

        if case .hls(let hlsURL) = streamType {
            XCTAssertEqual(hlsURL, url)
        } else {
            XCTFail("Expected HLS stream type")
        }
    }

    func testMJPEGStreamType() {
        let url = URL(string: "http://example.com/stream.mjpeg")!
        let streamType = CameraStreamInfo.StreamType.mjpeg(url: url)

        if case .mjpeg(let mjpegURL) = streamType {
            XCTAssertEqual(mjpegURL, url)
        } else {
            XCTFail("Expected MJPEG stream type")
        }
    }

    func testWebRTCStreamType() {
        let signaling = CameraStreamInfo.WebRTCSignaling(
            sendOffer: { _ in return "answer" },
            sendCandidate: { _ in }
        )
        let streamType = CameraStreamInfo.StreamType.webrtc(signaling: signaling)

        if case .webrtc = streamType {
            // Success - WebRTC type created
        } else {
            XCTFail("Expected WebRTC stream type")
        }
    }

    func testCameraStreamInfoCreation() {
        let cameraId = UUID()
        let url = URL(string: "http://example.com/stream.m3u8")!
        let streamType = CameraStreamInfo.StreamType.hls(url: url)

        let info = CameraStreamInfo(cameraId: cameraId, streamType: streamType)

        XCTAssertEqual(info.cameraId, cameraId)
        if case .hls = info.streamType {
            // Success
        } else {
            XCTFail("Expected HLS stream type in info")
        }
    }
}
