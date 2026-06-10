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

    // MARK: - Binary sensor tests

    func testServiceTypeLabelForBinarySensors() {
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.contactSensor), "contact-sensor")
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.motionSensor), "motion-sensor")
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.occupancySensor), "occupancy-sensor")
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.leakSensor), "leak-sensor")
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.smokeSensor), "smoke-sensor")
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.carbonMonoxideSensor), "carbon-monoxide-sensor")
        XCTAssertEqual(server.serviceTypeLabel(ServiceTypes.carbonDioxideSensor), "carbon-dioxide-sensor")
    }

    func testInfoExposesBinarySensorDetected() {
        // Every kind reads its own field in the binarySensorId coalescing chain,
        // so cover all seven and both polarities. Contact is the inverted one:
        // HAP value 1 = "not detected" = physically open, so an open contact
        // reports detected:true and a closed one detected:false.
        let cases: [(name: String, type: String, label: String, value: Int, detected: String)] = [
            ("Front Door", ServiceTypes.contactSensor, "contact-sensor", 1, "true"),    // open
            ("Back Door", ServiceTypes.contactSensor, "contact-sensor", 0, "false"),    // closed
            ("Hall Motion", ServiceTypes.motionSensor, "motion-sensor", 1, "true"),
            ("Office Presence", ServiceTypes.occupancySensor, "occupancy-sensor", 0, "false"),
            ("Sink Leak", ServiceTypes.leakSensor, "leak-sensor", 0, "false"),          // dry
            ("Kitchen Smoke", ServiceTypes.smokeSensor, "smoke-sensor", 1, "true"),
            ("Garage CO", ServiceTypes.carbonMonoxideSensor, "carbon-monoxide-sensor", 1, "true"),
            ("Bedroom CO2", ServiceTypes.carbonDioxideSensor, "carbon-dioxide-sensor", 0, "false")
        ]
        let ids = Dictionary(uniqueKeysWithValues: cases.map { ($0.name, UUID()) })
        let sensors = cases.map { (name: $0.name, type: $0.type, charId: ids[$0.name]!) }
        engine.updateMenuData(makeSensorMenuData(sensors))
        for c in cases { mockBridge.characteristicValues[ids[c.name]!] = c.value }
        server.start()

        for c in cases {
            let path = "/info/" + c.name.replacingOccurrences(of: " ", with: "%20")
            let body = sendRequest(path: path)?.body ?? ""
            XCTAssertTrue(body.contains("\"type\":\"\(c.label)\""), "type label for \(c.name)")
            XCTAssertTrue(body.contains("\"detected\":\(c.detected)"), "detected for \(c.name)")
        }
    }

    func testInfoLightHasNoDetectedField() {
        mockBridge.characteristicValues[powerStateId] = true
        server.start()

        let body = sendRequest(path: "/info/Light")?.body ?? ""
        XCTAssertFalse(body.contains("\"detected\""), "non-sensor service must not expose detected")
    }

    func testDebugIncludesBinarySensorCharacteristics() {
        let co2Id = UUID()
        engine.updateMenuData(makeSensorMenuData([
            (name: "Bedroom CO2", type: ServiceTypes.carbonDioxideSensor, charId: co2Id)
        ]))
        mockBridge.characteristicValues[co2Id] = 1
        server.start()

        let body = sendRequest(path: "/debug/Bedroom%20CO2")?.body ?? ""
        XCTAssertTrue(body.contains("\"carbonDioxideDetected\""))
        XCTAssertTrue(body.contains("\"serviceTypeLabel\":\"carbon-dioxide-sensor\""))
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

    // MARK: - Bind address configuration tests

    func testDefaultBindAddressIsNil() {
        let original = UserDefaults.standard.object(forKey: WebhookServer.bindAddressKey)
        defer { restoreBindAddress(original) }

        UserDefaults.standard.removeObject(forKey: WebhookServer.bindAddressKey)
        XCTAssertNil(WebhookServer.configuredBindAddress)
    }

    func testValidIPv4BindAddressIsReturned() {
        let original = UserDefaults.standard.object(forKey: WebhookServer.bindAddressKey)
        defer { restoreBindAddress(original) }

        UserDefaults.standard.set("100.64.0.1", forKey: WebhookServer.bindAddressKey)
        XCTAssertEqual(WebhookServer.configuredBindAddress, "100.64.0.1")
    }

    func testInvalidBindAddressFallsBackToNil() {
        let original = UserDefaults.standard.object(forKey: WebhookServer.bindAddressKey)
        defer { restoreBindAddress(original) }

        UserDefaults.standard.set("not-an-ip", forKey: WebhookServer.bindAddressKey)
        XCTAssertNil(WebhookServer.configuredBindAddress)
    }

    func testIPv6BindAddressIsAccepted() {
        let original = UserDefaults.standard.object(forKey: WebhookServer.bindAddressKey)
        defer { restoreBindAddress(original) }

        UserDefaults.standard.set("::1", forKey: WebhookServer.bindAddressKey)
        XCTAssertEqual(WebhookServer.configuredBindAddress, "::1")
    }

    func testIsValidIPAddress() {
        XCTAssertTrue(WebhookServer.isValidIPAddress("127.0.0.1"))
        XCTAssertTrue(WebhookServer.isValidIPAddress("100.64.0.1"))
        XCTAssertTrue(WebhookServer.isValidIPAddress("::1"))
        XCTAssertTrue(WebhookServer.isValidIPAddress("fe80::1"))
        XCTAssertFalse(WebhookServer.isValidIPAddress(""))
        XCTAssertFalse(WebhookServer.isValidIPAddress("999.999.999.999"))
        XCTAssertFalse(WebhookServer.isValidIPAddress("hello"))
        XCTAssertFalse(WebhookServer.isValidIPAddress("256.1.1.1"))
    }

    func testServerWithBindAddressInitializes() {
        let boundServer = WebhookServer(port: 18424, bindAddress: "127.0.0.1")
        boundServer.configure(actionEngine: engine)

        XCTAssertEqual(boundServer.state, .stopped)
    }

    /// Regression: a bound listener used to fail with NWError 22 because the port
    /// was specified both in `requiredLocalEndpoint` and the `on:` argument. It
    /// must actually reach `.running`, not `.error`.
    func testServerBoundToLoopbackReachesRunning() {
        let boundServer = WebhookServer(port: 18425, bindAddress: "127.0.0.1")
        boundServer.configure(actionEngine: engine)
        defer { boundServer.stop() }
        boundServer.start()

        let started = expectation(description: "Bound server reaches running")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(boundServer.state, .running)
            started.fulfill()
        }
        wait(for: [started], timeout: 2)
    }

    /// applyConfiguration re-reads the persisted port + bind address and rebinds
    /// live, so a config change takes effect without recreating the singleton.
    func testApplyConfigurationRebindsToNewPort() {
        let originalPort = UserDefaults.standard.object(forKey: WebhookServer.portKey)
        let originalEnabled = UserDefaults.standard.object(forKey: WebhookServer.enabledKey)
        defer {
            if let originalPort { UserDefaults.standard.set(originalPort, forKey: WebhookServer.portKey) }
            else { UserDefaults.standard.removeObject(forKey: WebhookServer.portKey) }
            if let originalEnabled { UserDefaults.standard.set(originalEnabled, forKey: WebhookServer.enabledKey) }
            else { UserDefaults.standard.removeObject(forKey: WebhookServer.enabledKey) }
        }

        UserDefaults.standard.set(true, forKey: WebhookServer.enabledKey)
        let svc = WebhookServer(port: 18426)
        svc.configure(actionEngine: engine)
        defer { svc.stop() }

        UserDefaults.standard.set(18427, forKey: WebhookServer.portKey)
        svc.applyConfiguration()

        let applied = expectation(description: "Rebound to new port")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(svc.port, 18427)
            XCTAssertEqual(svc.state, .running)
            applied.fulfill()
        }
        wait(for: [applied], timeout: 2)
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

    /// Build menu data from a list of binary sensors, routing each char id to
    /// the ServiceData field that matches its service type. One accessory per
    /// sensor, all in a single "Hall" room.
    private func makeSensorMenuData(_ sensors: [(name: String, type: String, charId: UUID)]) -> MenuData {
        let roomId = UUID()
        let services: [ServiceData] = sensors.map { sensor in
            ServiceData(
                uniqueIdentifier: UUID(),
                name: sensor.name,
                serviceType: sensor.type,
                accessoryName: sensor.name,
                roomIdentifier: roomId,
                motionDetectedId: sensor.type == ServiceTypes.motionSensor ? sensor.charId : nil,
                contactSensorStateId: sensor.type == ServiceTypes.contactSensor ? sensor.charId : nil,
                occupancyDetectedId: sensor.type == ServiceTypes.occupancySensor ? sensor.charId : nil,
                leakDetectedId: sensor.type == ServiceTypes.leakSensor ? sensor.charId : nil,
                smokeDetectedId: sensor.type == ServiceTypes.smokeSensor ? sensor.charId : nil,
                carbonMonoxideDetectedId: sensor.type == ServiceTypes.carbonMonoxideSensor ? sensor.charId : nil,
                carbonDioxideDetectedId: sensor.type == ServiceTypes.carbonDioxideSensor ? sensor.charId : nil
            )
        }
        let accessories = services.map { svc in
            AccessoryData(
                uniqueIdentifier: UUID(),
                name: svc.name,
                roomIdentifier: roomId,
                services: [svc],
                isReachable: true
            )
        }
        return MenuData(
            homes: [HomeData(uniqueIdentifier: UUID(), name: "Home", isPrimary: true)],
            rooms: [RoomData(uniqueIdentifier: roomId, name: "Hall")],
            accessories: accessories,
            scenes: [],
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

    private func restoreBindAddress(_ original: Any?) {
        if let original {
            UserDefaults.standard.set(original, forKey: WebhookServer.bindAddressKey)
        } else {
            UserDefaults.standard.removeObject(forKey: WebhookServer.bindAddressKey)
        }
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
    func getCameraDebugJSON(entityId: String?, completion: @escaping (String?) -> Void) { completion(nil) }
}
