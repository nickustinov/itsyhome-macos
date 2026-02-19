//
//  WebhookServerTests.swift
//  macOSBridgeTests
//
//  Tests for WebhookServer
//

import XCTest
import Network
@testable import macOSBridge

final class WebhookServerTests: XCTestCase {

    private static let testPort: UInt16 = 18423
    private var server: WebhookServer!
    private var mockBridge: MockWebhookBridge!
    private var engine: ActionEngine!

    override func setUp() {
        super.setUp()
        ProStatusCache.shared.isPro = true
        mockBridge = MockWebhookBridge()
        engine = ActionEngine(bridge: mockBridge)
        engine.updateMenuData(createTestMenuData())
        server = WebhookServer(port: Self.testPort)
        server.configure(actionEngine: engine)
    }

    override func tearDown() {
        server.stop()
        Thread.sleep(forTimeInterval: 0.1)
        server = nil
        ProStatusCache.shared.isPro = false
        super.tearDown()
    }

    // MARK: - Lifecycle tests

    func testInitialStateIsStopped() {
        XCTAssertEqual(server.state, .stopped)
    }

    func testStartSetsRunningState() {
        server.start()

        let expectation = expectation(description: "Server starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.server.state, .running)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testStopSetsStoppedState() {
        server.start()

        let startExpectation = expectation(description: "Server starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.server.stop()
            XCTAssertEqual(self.server.state, .stopped)
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 2)
    }

    func testStartIfEnabledDoesNothingWhenDisabled() {
        UserDefaults.standard.set(false, forKey: WebhookServer.enabledKey)
        server.startIfEnabled()

        let expectation = expectation(description: "Check state")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.server.state, .stopped)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testStartIfEnabledStartsWhenEnabled() {
        UserDefaults.standard.set(true, forKey: WebhookServer.enabledKey)
        server.startIfEnabled()

        let expectation = expectation(description: "Server starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.server.state, .running)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        UserDefaults.standard.removeObject(forKey: WebhookServer.enabledKey)
    }

    // MARK: - HTTP request tests

    func testToggleRequest() {
        mockBridge.characteristicValues[powerStateId] = false
        server.start()

        let response = sendRequest(path: "/toggle/Office/Light")

        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(response?.body.contains("\"status\":\"success\"") ?? false)
        XCTAssertEqual(mockBridge.writtenCharacteristics[powerStateId] as? Bool, true)
    }

    func testBrightnessRequest() {
        server.start()

        let response = sendRequest(path: "/brightness/75/Office/Light")

        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(response?.body.contains("\"status\":\"success\"") ?? false)
        XCTAssertEqual(mockBridge.writtenCharacteristics[brightnessId] as? Int, 75)
    }

    func testSceneRequest() {
        server.start()

        let response = sendRequest(path: "/scene/Goodnight")

        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(response?.body.contains("\"status\":\"success\"") ?? false)
        XCTAssertEqual(mockBridge.executedScenes.count, 1)
    }

    func testUnknownTargetReturns404() {
        server.start()

        let response = sendRequest(path: "/toggle/Nonexistent/Device")

        XCTAssertEqual(response?.statusCode, 404)
        XCTAssertTrue(response?.body.contains("\"status\":\"error\"") ?? false)
    }

    func testInvalidActionReturns400() {
        server.start()

        let response = sendRequest(path: "/invalid/Office/Light")

        XCTAssertEqual(response?.statusCode, 400)
        XCTAssertTrue(response?.body.contains("\"status\":\"error\"") ?? false)
    }

    func testEmptyPathReturns400() {
        server.start()

        let response = sendRequest(path: "/")

        XCTAssertEqual(response?.statusCode, 400)
        XCTAssertTrue(response?.body.contains("\"status\":\"error\"") ?? false)
    }

    func testPercentEncodedSpaces() {
        server.start()

        let response = sendRequest(path: "/toggle/Living%20Room/Lamp")

        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(response?.body.contains("\"status\":\"success\"") ?? false)
        XCTAssertEqual(mockBridge.writtenCharacteristics[livingRoomPowerStateId] as? Bool, true)
    }

    // MARK: - Read endpoint tests

    func testStatusEndpoint() {
        server.start()

        let response = sendRequest(path: "/status")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("\"rooms\":2"))
        XCTAssertTrue(body.contains("\"devices\":2"))
        XCTAssertTrue(body.contains("\"accessories\":2"))
        XCTAssertTrue(body.contains("\"reachable\":2"))
        XCTAssertTrue(body.contains("\"scenes\":1"))
    }

    func testListRoomsEndpoint() {
        server.start()

        let response = sendRequest(path: "/list/rooms")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("\"name\":\"Office\""))
        XCTAssertTrue(body.contains("\"name\":\"Living Room\""))
    }

    func testListDevicesEndpoint() {
        server.start()

        let response = sendRequest(path: "/list/devices")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("\"name\":\"Light\""))
        XCTAssertTrue(body.contains("\"name\":\"Lamp\""))
        XCTAssertTrue(body.contains("\"reachable\":true"))
    }

    func testListDevicesByRoomEndpoint() {
        server.start()

        let response = sendRequest(path: "/list/devices/Office")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("\"name\":\"Light\""))
        XCTAssertFalse(body.contains("\"name\":\"Lamp\""))
    }

    func testListScenesEndpoint() {
        server.start()

        let response = sendRequest(path: "/list/scenes")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("\"name\":\"Goodnight\""))
    }

    func testListGroupsEndpoint() {
        server.start()

        let response = sendRequest(path: "/list/groups")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.hasPrefix("["))
        XCTAssertTrue(body.hasSuffix("]"))
    }

    func testInfoEndpoint() {
        mockBridge.characteristicValues[powerStateId] = true
        mockBridge.characteristicValues[brightnessId] = 80
        server.start()

        let response = sendRequest(path: "/info/Light")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("\"name\":\"Light\""))
        XCTAssertTrue(body.contains("\"reachable\":true"))
        XCTAssertTrue(body.contains("\"on\":true"))
        XCTAssertTrue(body.contains("\"brightness\":80"))
    }

    func testInfoRoomEndpoint() {
        server.start()

        let response = sendRequest(path: "/info/Office")

        XCTAssertEqual(response?.statusCode, 200)
        let body = response?.body ?? ""
        XCTAssertTrue(body.contains("["))
        XCTAssertTrue(body.contains("\"name\":\"Light\""))
    }

    func testInfoNotFound() {
        server.start()

        let response = sendRequest(path: "/info/NonexistentDevice")

        XCTAssertEqual(response?.statusCode, 404)
    }

    func testListInvalidResource() {
        server.start()

        let response = sendRequest(path: "/list/invalid")

        XCTAssertEqual(response?.statusCode, 400)
    }

    // MARK: - Port configuration test

    func testConfiguredPort() {
        let original = UserDefaults.standard.integer(forKey: WebhookServer.portKey)
        UserDefaults.standard.set(9999, forKey: WebhookServer.portKey)
        XCTAssertEqual(WebhookServer.configuredPort, 9999)
        if original > 0 {
            UserDefaults.standard.set(original, forKey: WebhookServer.portKey)
        } else {
            UserDefaults.standard.removeObject(forKey: WebhookServer.portKey)
        }
    }

    func testConfiguredPortDefault() {
        UserDefaults.standard.removeObject(forKey: WebhookServer.portKey)
        XCTAssertEqual(WebhookServer.configuredPort, 8423)
    }

    // MARK: - IP address test

    func testLocalIPAddressReturnsNonNil() {
        // May be nil in CI environments without network
        let ip = WebhookServer.localIPAddress()
        if let ip {
            XCTAssertFalse(ip.isEmpty)
            XCTAssertTrue(ip.contains("."))
        }
    }

    // MARK: - Test data

    private let powerStateId = UUID()
    private let brightnessId = UUID()
    private let livingRoomPowerStateId = UUID()
    private let sceneId = UUID()

    private func createTestMenuData() -> MenuData {
        let officeRoomId = UUID()
        let livingRoomId = UUID()

        let light = ServiceData(
            uniqueIdentifier: UUID(),
            name: "Light",
            serviceType: ServiceTypes.lightbulb,
            accessoryName: "Light",
            roomIdentifier: officeRoomId,
            powerStateId: powerStateId,
            brightnessId: brightnessId
        )

        let livingRoomLamp = ServiceData(
            uniqueIdentifier: UUID(),
            name: "Lamp",
            serviceType: ServiceTypes.lightbulb,
            accessoryName: "Lamp",
            roomIdentifier: livingRoomId,
            powerStateId: livingRoomPowerStateId
        )

        let accessories = [
            AccessoryData(
                uniqueIdentifier: UUID(),
                name: "Light",
                roomIdentifier: officeRoomId,
                services: [light],
                isReachable: true
            ),
            AccessoryData(
                uniqueIdentifier: UUID(),
                name: "Lamp",
                roomIdentifier: livingRoomId,
                services: [livingRoomLamp],
                isReachable: true
            )
        ]

        let scenes = [
            SceneData(uniqueIdentifier: sceneId, name: "Goodnight")
        ]

        return MenuData(
            homes: [HomeData(uniqueIdentifier: UUID(), name: "Home", isPrimary: true)],
            rooms: [
                RoomData(uniqueIdentifier: officeRoomId, name: "Office"),
                RoomData(uniqueIdentifier: livingRoomId, name: "Living Room")
            ],
            accessories: accessories,
            scenes: scenes,
            selectedHomeId: nil
        )
    }

    // MARK: - HTTP helpers

    private struct HTTPResponse {
        let statusCode: Int
        let body: String
    }

    private func sendRequest(path: String) -> HTTPResponse? {
        // Wait for server to be ready
        let readyExpectation = expectation(description: "Server ready")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            readyExpectation.fulfill()
        }
        wait(for: [readyExpectation], timeout: 3)

        let responseExpectation = expectation(description: "HTTP response")
        var httpResponse: HTTPResponse?

        let url = URL(string: "http://localhost:\(Self.testPort)\(path)")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResp = response as? HTTPURLResponse,
               let data,
               let body = String(data: data, encoding: .utf8) {
                httpResponse = HTTPResponse(statusCode: httpResp.statusCode, body: body)
            }
            responseExpectation.fulfill()
        }
        task.resume()

        wait(for: [responseExpectation], timeout: 10)
        return httpResponse
    }
}

// MARK: - Mock

private class MockWebhookBridge: NSObject, Mac2iOS {
    var homes: [HomeInfo] = []
    var selectedHomeIdentifier: UUID?
    var rooms: [RoomInfo] = []
    var accessories: [AccessoryInfo] = []
    var scenes: [SceneInfo] = []

    var characteristicValues: [UUID: Any] = [:]
    var writtenCharacteristics: [UUID: Any] = [:]
    var executedScenes: [UUID] = []

    func reloadHomeKit() {}

    func executeScene(identifier: UUID) {
        executedScenes.append(identifier)
    }

    func readCharacteristic(identifier: UUID) {}

    func writeCharacteristic(identifier: UUID, value: Any) {
        writtenCharacteristics[identifier] = value
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        return characteristicValues[identifier]
    }

    func openCameraWindow() {}
    func closeCameraWindow() {}
    func setCameraWindowHidden(_ hidden: Bool) {}
    func getRawHomeKitDump() -> String? { nil }
}
