//
//  HubitatClientTests.swift
//  macOSBridgeTests
//
//  Tests for HubitatClient URL construction (no actual network calls)
//

import XCTest
@testable import macOSBridge

final class HubitatClientTests: XCTestCase {

    private var client: HubitatClient!

    override func setUp() {
        super.setUp()
        let hubURL = URL(string: "http://192.168.1.100")!
        client = try? HubitatClient(hubURL: hubURL, appId: "5", accessToken: "abc123")
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testClientInitialization() {
        XCTAssertNotNil(client)
    }

    func testClientInitializationWithPort() throws {
        let hubURL = URL(string: "http://192.168.1.50:8080")!
        let portedClient = try HubitatClient(hubURL: hubURL, appId: "3", accessToken: "token")
        XCTAssertNotNil(portedClient)

        // Verify EventSocket URL uses the port
        XCTAssertEqual(portedClient.eventSocketURL.port, 8080)
    }

    // MARK: - Maker API URL construction

    func testMakerAPIURLConstruction() throws {
        let url = client.makeURL(endpoint: "devices/all")
        XCTAssertNotNil(url)

        let urlString = url!.absoluteString
        // Path should include /apps/api/{appId}/devices/all
        XCTAssertTrue(urlString.contains("/apps/api/5/devices/all"),
                      "Expected path component /apps/api/5/devices/all, got: \(urlString)")
        // Must include access_token query param
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let tokenItem = components?.queryItems?.first(where: { $0.name == "access_token" })
        XCTAssertNotNil(tokenItem)
        XCTAssertEqual(tokenItem?.value, "abc123")
    }

    func testMakerAPIBaseHostPreserved() {
        let url = client.makeURL(endpoint: "devices/all")
        XCTAssertEqual(url?.host, "192.168.1.100")
    }

    // MARK: - Command URL construction

    func testCommandURLConstruction() {
        let url = client.makeURL(endpoint: "devices/42/on")
        XCTAssertNotNil(url)
        let path = url!.path
        XCTAssertTrue(path.contains("devices/42/on"),
                      "Expected devices/42/on in path, got: \(path)")
    }

    func testCommandWithValueURLConstruction() {
        let url = client.makeURL(endpoint: "devices/7/setLevel/75")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.contains("devices/7/setLevel/75"))
    }

    // MARK: - EventSocket URL construction

    func testEventSocketURLConstruction() {
        let wsURL = client.eventSocketURL
        XCTAssertEqual(wsURL.scheme, "ws")
        XCTAssertEqual(wsURL.host, "192.168.1.100")
        XCTAssertEqual(wsURL.path, "/eventsocket")
    }

    func testEventSocketURLUsesWSSForHTTPS() throws {
        let hubURL = URL(string: "https://192.168.1.100")!
        let secureClient = try HubitatClient(hubURL: hubURL, appId: "1", accessToken: "tok")
        XCTAssertEqual(secureClient.eventSocketURL.scheme, "wss")
    }

    func testEventSocketURLWithPort() throws {
        let hubURL = URL(string: "http://192.168.1.100:8080")!
        let portedClient = try HubitatClient(hubURL: hubURL, appId: "1", accessToken: "tok")
        let wsURL = portedClient.eventSocketURL
        XCTAssertEqual(wsURL.scheme, "ws")
        XCTAssertEqual(wsURL.port, 8080)
        XCTAssertEqual(wsURL.path, "/eventsocket")
    }

    // MARK: - Invalid URL handling

    func testInitWithInvalidSchemeThrows() {
        let url = URL(string: "ftp://192.168.1.100")!
        XCTAssertThrowsError(try HubitatClient(hubURL: url, appId: "1", accessToken: "tok")) { error in
            guard case HubitatClientError.invalidURL = error else {
                XCTFail("Expected invalidURL error, got \(error)")
                return
            }
        }
    }

    func testInitWithMissingHostThrows() {
        // Construct a URL that has an empty host — use a malformed URL as raw
        // URLComponents allows empty host, so we can build it directly
        var components = URLComponents()
        components.scheme = "http"
        components.host = ""
        components.path = "/apps/api/1"
        guard let url = components.url else {
            // If URL can't be constructed, the test is vacuously passing: no valid URL -> no client
            return
        }
        XCTAssertThrowsError(try HubitatClient(hubURL: url, appId: "1", accessToken: "tok")) { error in
            guard case HubitatClientError.invalidURL = error else {
                XCTFail("Expected invalidURL error, got \(error)")
                return
            }
        }
    }

    // MARK: - Connected state

    func testIsNotConnectedInitially() {
        XCTAssertFalse(client.isConnected)
    }
}
