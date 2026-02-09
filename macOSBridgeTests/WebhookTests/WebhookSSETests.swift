//
//  WebhookSSETests.swift
//  macOSBridgeTests
//
//  Tests for WebhookServer SSE event streaming
//

import XCTest
import Network
@testable import macOSBridge

final class WebhookSSETests: XCTestCase {

    private static let testPort: UInt16 = 18424
    private var server: WebhookServer!
    private var mockBridge: MockSSEBridge!
    private var engine: ActionEngine!

    private let powerStateId = UUID()
    private let brightnessId = UUID()
    private let officeRoomId = UUID()

    override func setUp() {
        super.setUp()
        ProStatusCache.shared.isPro = true
        mockBridge = MockSSEBridge()
        engine = ActionEngine(bridge: mockBridge)
        let menuData = createTestMenuData()
        engine.updateMenuData(menuData)
        server = WebhookServer(port: Self.testPort)
        server.configure(actionEngine: engine)
        server.rebuildCharacteristicIndex(from: menuData)
        server.start()

        // Seed the value cache so first-seen values are recorded (events only fire on change)
        server.publishCharacteristicChange(characteristicId: powerStateId, value: false)
        server.publishCharacteristicChange(characteristicId: brightnessId, value: 0)

        // Wait for server to be ready and seeds to process
        let ready = expectation(description: "Server ready")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ready.fulfill() }
        wait(for: [ready], timeout: 2)
    }

    override func tearDown() {
        server.stop()
        Thread.sleep(forTimeInterval: 0.1)
        server = nil
        ProStatusCache.shared.isPro = false
        super.tearDown()
    }

    // MARK: - Index tests

    func testCharacteristicIndexRebuild() {
        let index = server.characteristicIndex
        let powerContext = index[powerStateId.uuidString]
        XCTAssertNotNil(powerContext)
        XCTAssertEqual(powerContext?.deviceName, "Desk Lamp")
        XCTAssertEqual(powerContext?.roomName, "Office")
        XCTAssertEqual(powerContext?.deviceType, "light")
        XCTAssertEqual(powerContext?.characteristicName, "power")

        let brightnessContext = index[brightnessId.uuidString]
        XCTAssertNotNil(brightnessContext)
        XCTAssertEqual(brightnessContext?.characteristicName, "brightness")
        XCTAssertEqual(brightnessContext?.serviceId, index[powerStateId.uuidString]?.serviceId)
    }

    func testCharacteristicIndexUnknownReturnsNil() {
        let index = server.characteristicIndex
        XCTAssertNil(index[UUID().uuidString])
    }

    // MARK: - SSE connection tests

    func testSSEConnectionReceivesHeaders() {
        let headerExpectation = expectation(description: "Received SSE headers")
        var receivedData = Data()

        let connection = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: Self.testPort)!, using: .tcp)
        connection.start(queue: .main)

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                let request = "GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n"
                connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
            }
        }

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let data {
                    receivedData.append(data)
                    let text = String(data: receivedData, encoding: .utf8) ?? ""
                    if text.contains("text/event-stream") {
                        headerExpectation.fulfill()
                        return
                    }
                }
                if error == nil {
                    receiveMore()
                }
            }
        }
        receiveMore()

        wait(for: [headerExpectation], timeout: 5)
        connection.cancel()
    }

    func testSSEReceivesEvent() {
        let eventExpectation = expectation(description: "Received SSE event")
        var receivedData = Data()
        var headersSeen = false

        let connection = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: Self.testPort)!, using: .tcp)
        connection.start(queue: .main)

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                let request = "GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n"
                connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
            }
        }

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [self] data, _, _, error in
                if let data {
                    receivedData.append(data)
                    let text = String(data: receivedData, encoding: .utf8) ?? ""

                    if !headersSeen && text.contains("text/event-stream") {
                        headersSeen = true
                        // Publish an event after headers are received
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.server.publishCharacteristicChange(characteristicId: self.powerStateId, value: true)
                        }
                    }

                    if headersSeen && text.contains("data: {") && text.contains("\"characteristic\":\"power\"") {
                        // Verify the event JSON
                        XCTAssertTrue(text.contains("\"device\":\"Desk Lamp\""))
                        XCTAssertTrue(text.contains("\"room\":\"Office\""))
                        XCTAssertTrue(text.contains("\"type\":\"light\""))
                        XCTAssertTrue(text.contains("\"value\":true"))
                        eventExpectation.fulfill()
                        return
                    }
                }
                if error == nil {
                    receiveMore()
                }
            }
        }
        receiveMore()

        wait(for: [eventExpectation], timeout: 5)
        connection.cancel()
    }

    func testSSEMultipleClients() {
        let expectation1 = expectation(description: "Client 1 received event")
        let expectation2 = expectation(description: "Client 2 received event")

        func connectSSEClient(onEvent: @escaping () -> Void) -> NWConnection {
            let conn = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: Self.testPort)!, using: .tcp)
            var receivedData = Data()
            var headersSeen = false

            conn.start(queue: .main)
            conn.stateUpdateHandler = { state in
                if case .ready = state {
                    let request = "GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n"
                    conn.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
                }
            }

            func receiveMore() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                    if let data {
                        receivedData.append(data)
                        let text = String(data: receivedData, encoding: .utf8) ?? ""
                        if !headersSeen && text.contains("text/event-stream") {
                            headersSeen = true
                        }
                        if headersSeen && text.contains("data: {") && text.contains("\"characteristic\":\"brightness\"") {
                            onEvent()
                            return
                        }
                    }
                    if error == nil {
                        receiveMore()
                    }
                }
            }
            receiveMore()
            return conn
        }

        let conn1 = connectSSEClient { expectation1.fulfill() }
        let conn2 = connectSSEClient { expectation2.fulfill() }

        // Wait for both clients to connect, then publish
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.server.publishCharacteristicChange(characteristicId: self.brightnessId, value: 75)
        }

        wait(for: [expectation1, expectation2], timeout: 5)
        conn1.cancel()
        conn2.cancel()
    }

    func testUnknownCharacteristicNotPublished() {
        let noEventExpectation = expectation(description: "No event received for unknown characteristic")
        noEventExpectation.isInverted = true
        var receivedData = Data()
        var headersSeen = false

        let connection = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: Self.testPort)!, using: .tcp)
        connection.start(queue: .main)

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                let request = "GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n"
                connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
            }
        }

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [self] data, _, _, error in
                if let data {
                    receivedData.append(data)
                    let text = String(data: receivedData, encoding: .utf8) ?? ""
                    if !headersSeen && text.contains("text/event-stream") {
                        headersSeen = true
                        // Publish with unknown characteristic ID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.server.publishCharacteristicChange(characteristicId: UUID(), value: 42)
                        }
                    }
                    if text.contains("data: {") {
                        noEventExpectation.fulfill()
                        return
                    }
                }
                if error == nil {
                    receiveMore()
                }
            }
        }
        receiveMore()

        // Wait 2 seconds — inverted expectation should not be fulfilled
        wait(for: [noEventExpectation], timeout: 2)
        connection.cancel()
    }

    // MARK: - Test data

    private func createTestMenuData() -> MenuData {
        let serviceId = UUID()

        let deskLamp = ServiceData(
            uniqueIdentifier: serviceId,
            name: "Desk Lamp",
            serviceType: ServiceTypes.lightbulb,
            accessoryName: "Desk Lamp",
            roomIdentifier: officeRoomId,
            haEntityId: "light.desk_lamp",
            powerStateId: powerStateId,
            brightnessId: brightnessId
        )

        let accessories = [
            AccessoryData(
                uniqueIdentifier: UUID(),
                name: "Desk Lamp",
                roomIdentifier: officeRoomId,
                services: [deskLamp],
                isReachable: true
            )
        ]

        return MenuData(
            homes: [HomeData(uniqueIdentifier: UUID(), name: "Home", isPrimary: true)],
            rooms: [RoomData(uniqueIdentifier: officeRoomId, name: "Office")],
            accessories: accessories,
            scenes: [],
            selectedHomeId: nil
        )
    }
}

// MARK: - Mock

private class MockSSEBridge: NSObject, Mac2iOS {
    var homes: [HomeInfo] = []
    var selectedHomeIdentifier: UUID?
    var rooms: [RoomInfo] = []
    var accessories: [AccessoryInfo] = []
    var scenes: [SceneInfo] = []
    var characteristicValues: [UUID: Any] = [:]

    func reloadHomeKit() {}
    func executeScene(identifier: UUID) {}
    func readCharacteristic(identifier: UUID) {}
    func writeCharacteristic(identifier: UUID, value: Any) {}

    func getCharacteristicValue(identifier: UUID) -> Any? {
        return characteristicValues[identifier]
    }

    func openCameraWindow() {}
    func closeCameraWindow() {}
    func setCameraWindowHidden(_ hidden: Bool) {}
    func getRawHomeKitDump() -> String? { nil }
}
