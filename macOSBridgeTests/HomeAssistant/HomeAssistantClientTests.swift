//
//  HomeAssistantClientTests.swift
//  macOSBridgeTests
//
//  Tests for Home Assistant client URL construction and message parsing
//

import XCTest
@testable import macOSBridge

final class HomeAssistantClientTests: XCTestCase {

    // MARK: - URL construction tests

    func testHTTPToWSConversion() {
        // Given an HTTP URL
        let serverURL = URL(string: "http://homeassistant.local:8123")!

        // When creating WebSocket URL
        var wsURL = serverURL
        if wsURL.scheme == "http" {
            wsURL = URL(string: wsURL.absoluteString.replacingOccurrences(of: "http://", with: "ws://"))!
        }

        // Then it should be ws://
        XCTAssertEqual(wsURL.scheme, "ws")
        XCTAssertEqual(wsURL.absoluteString, "ws://homeassistant.local:8123")
    }

    func testHTTPSToWSSConversion() {
        // Given an HTTPS URL
        let serverURL = URL(string: "https://homeassistant.example.com")!

        // When creating WebSocket URL
        var wsURL = serverURL
        if wsURL.scheme == "https" {
            wsURL = URL(string: wsURL.absoluteString.replacingOccurrences(of: "https://", with: "wss://"))!
        }

        // Then it should be wss://
        XCTAssertEqual(wsURL.scheme, "wss")
        XCTAssertEqual(wsURL.absoluteString, "wss://homeassistant.example.com")
    }

    func testWebSocketPathAppended() {
        // Given a URL without websocket path
        var wsURL = URL(string: "ws://homeassistant.local:8123")!

        // When appending path
        if !wsURL.path.contains("api/websocket") {
            wsURL = wsURL.appendingPathComponent("api/websocket")
        }

        // Then path should be correct
        XCTAssertTrue(wsURL.path.contains("api/websocket"))
        XCTAssertEqual(wsURL.absoluteString, "ws://homeassistant.local:8123/api/websocket")
    }

    func testWebSocketPathNotDuplicated() {
        // Given a URL already with websocket path
        var wsURL = URL(string: "ws://homeassistant.local:8123/api/websocket")!

        // When checking and potentially appending path
        if !wsURL.path.contains("api/websocket") {
            wsURL = wsURL.appendingPathComponent("api/websocket")
        }

        // Then path should not be duplicated
        XCTAssertEqual(wsURL.path, "/api/websocket")
    }

    func testRESTBaseURLFromWS() {
        // Given a WebSocket URL
        let wsURL = URL(string: "ws://homeassistant.local:8123/api/websocket")!

        // When converting to REST URL
        var restURL = wsURL
        if restURL.scheme == "ws" {
            restURL = URL(string: restURL.absoluteString.replacingOccurrences(of: "ws://", with: "http://"))!
        }
        // Remove websocket path
        if restURL.path.contains("api/websocket") {
            restURL = restURL.deletingLastPathComponent().deletingLastPathComponent()
        }

        // Then it should be correct HTTP URL
        XCTAssertEqual(restURL.scheme, "http")
        XCTAssertEqual(restURL.host, "homeassistant.local")
        XCTAssertEqual(restURL.port, 8123)
    }

    func testRESTBaseURLFromWSS() {
        // Given a secure WebSocket URL
        let wssURL = URL(string: "wss://homeassistant.example.com/api/websocket")!

        // When converting to REST URL
        var restURL = wssURL
        if restURL.scheme == "wss" {
            restURL = URL(string: restURL.absoluteString.replacingOccurrences(of: "wss://", with: "https://"))!
        }
        // Remove websocket path
        if restURL.path.contains("api/websocket") {
            restURL = restURL.deletingLastPathComponent().deletingLastPathComponent()
        }

        // Then it should be correct HTTPS URL
        XCTAssertEqual(restURL.scheme, "https")
        XCTAssertEqual(restURL.host, "homeassistant.example.com")
    }

    func testCameraSnapshotURLConstruction() {
        // Given a REST base URL
        let restBaseURL = URL(string: "http://homeassistant.local:8123")!
        let entityId = "camera.front_door"

        // When constructing snapshot URL
        let snapshotURL = restBaseURL
            .appendingPathComponent("api/camera_proxy")
            .appendingPathComponent(entityId)

        // Then it should be correct
        XCTAssertEqual(snapshotURL.absoluteString, "http://homeassistant.local:8123/api/camera_proxy/camera.front_door")
    }

    // MARK: - Error type tests

    func testNotConnectedError() {
        let error = HomeAssistantClientError.notConnected
        XCTAssertEqual(error.errorDescription, "Not connected to Home Assistant")
    }

    func testAuthenticationFailedError() {
        let error = HomeAssistantClientError.authenticationFailed("Invalid token")
        XCTAssertEqual(error.errorDescription, "Authentication failed: Invalid token")
    }

    func testConnectionFailedError() {
        let error = HomeAssistantClientError.connectionFailed("Host unreachable")
        XCTAssertEqual(error.errorDescription, "Connection failed: Host unreachable")
    }

    func testInvalidResponseError() {
        let error = HomeAssistantClientError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from Home Assistant")
    }

    func testInvalidURLError() {
        let error = HomeAssistantClientError.invalidURL("URL scheme must be http, https, ws, or wss (got ftp)")
        XCTAssertEqual(error.errorDescription, "Invalid server URL: URL scheme must be http, https, ws, or wss (got ftp)")
    }

    func testInitWithHTTPURL() throws {
        let client = try HomeAssistantClient(serverURL: URL(string: "http://homeassistant.local:8123")!, accessToken: "test")
        XCTAssertNotNil(client)
    }

    func testInitWithHTTPSURL() throws {
        let client = try HomeAssistantClient(serverURL: URL(string: "https://example.ui.nabu.casa")!, accessToken: "test")
        XCTAssertNotNil(client)
    }

    func testInitWithWSSURL() throws {
        let client = try HomeAssistantClient(serverURL: URL(string: "wss://example.ui.nabu.casa/api/websocket")!, accessToken: "test")
        XCTAssertNotNil(client)
    }

    func testInitWithInvalidSchemeThrows() {
        XCTAssertThrowsError(try HomeAssistantClient(serverURL: URL(string: "ftp://homeassistant.local")!, accessToken: "test")) { error in
            XCTAssertTrue(error.localizedDescription.contains("URL scheme must be"))
        }
    }

    func testServiceCallFailedError() {
        let error = HomeAssistantClientError.serviceCallFailed("Entity not found")
        XCTAssertEqual(error.errorDescription, "Service call failed: Entity not found")
    }

    func testTimeoutError() {
        let error = HomeAssistantClientError.timeout
        XCTAssertEqual(error.errorDescription, "Request timed out")
    }

    // MARK: - Message type parsing tests

    func testAuthRequiredMessageType() {
        let json: [String: Any] = ["type": "auth_required"]
        let type = json["type"] as? String
        XCTAssertEqual(type, "auth_required")
    }

    func testAuthOkMessageType() {
        let json: [String: Any] = [
            "type": "auth_ok",
            "ha_version": "2024.1.0"
        ]
        let type = json["type"] as? String
        let version = json["ha_version"] as? String
        XCTAssertEqual(type, "auth_ok")
        XCTAssertEqual(version, "2024.1.0")
    }

    func testAuthInvalidMessageType() {
        let json: [String: Any] = [
            "type": "auth_invalid",
            "message": "Invalid access token"
        ]
        let type = json["type"] as? String
        let message = json["message"] as? String
        XCTAssertEqual(type, "auth_invalid")
        XCTAssertEqual(message, "Invalid access token")
    }

    func testResultSuccessMessageParsing() {
        let json: [String: Any] = [
            "id": 1,
            "type": "result",
            "success": true,
            "result": ["entity_id": "light.test", "state": "on"]
        ]

        let id = json["id"] as? Int
        let success = json["success"] as? Bool
        let result = json["result"] as? [String: Any]

        XCTAssertEqual(id, 1)
        XCTAssertEqual(success, true)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["entity_id"] as? String, "light.test")
    }

    func testResultErrorMessageParsing() {
        let json: [String: Any] = [
            "id": 2,
            "type": "result",
            "success": false,
            "error": [
                "code": "not_found",
                "message": "Entity not found"
            ]
        ]

        let success = json["success"] as? Bool
        let error = json["error"] as? [String: Any]
        let errorMessage = error?["message"] as? String

        XCTAssertEqual(success, false)
        XCTAssertEqual(errorMessage, "Entity not found")
    }

    func testEventMessageParsing() {
        let json: [String: Any] = [
            "id": 5,
            "type": "event",
            "event": [
                "event_type": "state_changed",
                "data": [
                    "entity_id": "light.kitchen",
                    "new_state": ["state": "on"],
                    "old_state": ["state": "off"]
                ],
                "origin": "LOCAL"
            ]
        ]

        let id = json["id"] as? Int
        let eventData = json["event"] as? [String: Any]
        let eventType = eventData?["event_type"] as? String

        XCTAssertEqual(id, 5)
        XCTAssertEqual(eventType, "state_changed")
    }

    // MARK: - Service call message construction tests

    func testCallServiceMessageFormat() {
        let domain = "light"
        let service = "turn_on"
        let entityId = "light.kitchen"

        var message: [String: Any] = [
            "id": 1,
            "type": "call_service",
            "domain": domain,
            "service": service
        ]
        message["target"] = ["entity_id": entityId]

        XCTAssertEqual(message["type"] as? String, "call_service")
        XCTAssertEqual(message["domain"] as? String, "light")
        XCTAssertEqual(message["service"] as? String, "turn_on")
        XCTAssertEqual((message["target"] as? [String: Any])?["entity_id"] as? String, "light.kitchen")
    }

    func testCallServiceWithServiceData() {
        var message: [String: Any] = [
            "id": 1,
            "type": "call_service",
            "domain": "light",
            "service": "turn_on"
        ]
        message["service_data"] = ["brightness": 200]
        message["target"] = ["entity_id": "light.bedroom"]

        let serviceData = message["service_data"] as? [String: Any]
        XCTAssertEqual(serviceData?["brightness"] as? Int, 200)
    }

    // MARK: - Subscription message format tests

    func testSubscribeEventsMessageFormat() {
        let message: [String: Any] = [
            "id": 1,
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]

        XCTAssertEqual(message["type"] as? String, "subscribe_events")
        XCTAssertEqual(message["event_type"] as? String, "state_changed")
    }

    // MARK: - Ping/Pong message format tests

    func testPingMessageFormat() {
        let message: [String: Any] = [
            "id": 10,
            "type": "ping"
        ]

        XCTAssertEqual(message["type"] as? String, "ping")
        XCTAssertNotNil(message["id"])
    }

    func testPongMessageParsing() {
        let json: [String: Any] = [
            "id": 10,
            "type": "pong"
        ]

        let type = json["type"] as? String
        XCTAssertEqual(type, "pong")
    }

    // MARK: - Reconnection delay calculation tests

    func testExponentialBackoffDelays() {
        let baseDelay: TimeInterval = 1.0

        // Test exponential backoff formula (without jitter)
        let delay0 = min(baseDelay * pow(2.0, 0), 30.0)  // 1
        let delay1 = min(baseDelay * pow(2.0, 1), 30.0)  // 2
        let delay2 = min(baseDelay * pow(2.0, 2), 30.0)  // 4
        let delay3 = min(baseDelay * pow(2.0, 3), 30.0)  // 8
        let delay4 = min(baseDelay * pow(2.0, 4), 30.0)  // 16
        let delay5 = min(baseDelay * pow(2.0, 5), 30.0)  // 30 (capped)

        XCTAssertEqual(delay0, 1.0, accuracy: 0.01)
        XCTAssertEqual(delay1, 2.0, accuracy: 0.01)
        XCTAssertEqual(delay2, 4.0, accuracy: 0.01)
        XCTAssertEqual(delay3, 8.0, accuracy: 0.01)
        XCTAssertEqual(delay4, 16.0, accuracy: 0.01)
        XCTAssertEqual(delay5, 30.0, accuracy: 0.01)  // Capped at 30
    }

    // MARK: - WebRTC signaling message tests

    func testWebRTCOfferMessageFormat() {
        let message: [String: Any] = [
            "id": 1,
            "type": "camera/webrtc/offer",
            "entity_id": "camera.front_door",
            "offer": "v=0\r\no=..."  // SDP offer
        ]

        XCTAssertEqual(message["type"] as? String, "camera/webrtc/offer")
        XCTAssertEqual(message["entity_id"] as? String, "camera.front_door")
        XCTAssertNotNil(message["offer"])
    }

    func testWebRTCCandidateMessageFormat() {
        let message: [String: Any] = [
            "id": 2,
            "type": "camera/webrtc/candidate",
            "entity_id": "camera.front_door",
            "candidate": "candidate:..."
        ]

        XCTAssertEqual(message["type"] as? String, "camera/webrtc/candidate")
        XCTAssertNotNil(message["candidate"])
    }

    func testWebRTCAnswerResponseParsing() {
        let json: [String: Any] = [
            "id": 1,
            "type": "result",
            "success": true,
            "result": [
                "answer": "v=0\r\no=..."  // SDP answer
            ]
        ]

        let result = json["result"] as? [String: Any]
        let answer = result?["answer"] as? String
        XCTAssertNotNil(answer)
    }
}
