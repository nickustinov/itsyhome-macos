//
//  HAURLValidatorTests.swift
//  macOSBridgeTests
//

import XCTest

final class HAURLValidatorTests: XCTestCase {

    // MARK: - Explicit scheme is preserved

    func testFullHTTPURL() {
        assertSuccess("http://homeassistant.local:8123",
                       expected: "http://homeassistant.local:8123")
    }

    func testFullHTTPSURL() {
        assertSuccess("https://ha.example.com",
                       expected: "https://ha.example.com")
    }

    func testWebSocketURL() {
        assertSuccess("ws://192.168.1.100:8123",
                       expected: "ws://192.168.1.100:8123")
    }

    func testSecureWebSocketURL() {
        assertSuccess("wss://ha.example.com",
                       expected: "wss://ha.example.com")
    }

    // MARK: - Bare local addresses default to http

    func testBareLocalHostname() {
        assertSuccess("homeassistant.local:8123",
                       expected: "http://homeassistant.local:8123")
    }

    func testBareLocalHostnameWithoutPort() {
        assertSuccess("homeassistant.local",
                       expected: "http://homeassistant.local")
    }

    func testBarePrivateIP192() {
        assertSuccess("192.168.1.100:8123",
                       expected: "http://192.168.1.100:8123")
    }

    func testBarePrivateIP10() {
        assertSuccess("10.0.0.5:8123",
                       expected: "http://10.0.0.5:8123")
    }

    func testBarePrivateIP172() {
        assertSuccess("172.16.0.1:8123",
                       expected: "http://172.16.0.1:8123")
    }

    func testBareLocalhost() {
        assertSuccess("localhost:8123",
                       expected: "http://localhost:8123")
    }

    func testBareLoopback() {
        assertSuccess("127.0.0.1:8123",
                       expected: "http://127.0.0.1:8123")
    }

    // MARK: - Bare remote addresses default to https

    func testBareNabuCasaDomain() {
        assertSuccess("abcdef123.ui.nabu.casa",
                       expected: "https://abcdef123.ui.nabu.casa")
    }

    func testBareDuckDNSDomain() {
        assertSuccess("myha.duckdns.org",
                       expected: "https://myha.duckdns.org")
    }

    func testBareCustomDomain() {
        assertSuccess("ha.example.com",
                       expected: "https://ha.example.com")
    }

    func testBareCustomDomainWithPort() {
        assertSuccess("ha.example.com:8443",
                       expected: "https://ha.example.com:8443")
    }

    // MARK: - Normalisation

    func testTrailingSlashStripped() {
        assertSuccess("http://ha.local:8123/",
                       expected: "http://ha.local:8123")
    }

    func testWhitespaceIsTrimmed() {
        assertSuccess("  http://ha.local:8123  ",
                       expected: "http://ha.local:8123")
    }

    func testURLWithPath() {
        assertSuccess("http://ha.local:8123/some/path",
                       expected: "http://ha.local:8123/some/path")
    }

    // MARK: - Failure cases

    func testEmptyString() {
        assertFailure("")
    }

    func testWhitespaceOnly() {
        assertFailure("   ")
    }

    func testSchemeOnly() {
        assertFailure("http://")
    }

    func testInvalidScheme() {
        assertFailure("ftp://ha.local:8123")
    }

    func testGarbageInput() {
        assertFailure("://not-a-url")
    }

    // MARK: - Helpers

    private func assertSuccess(_ input: String, expected: String, file: StaticString = #file, line: UInt = #line) {
        let result = HAURLValidator.validate(input)
        guard case .success(let url) = result else {
            XCTFail("Expected success for \"\(input)\" but got failure", file: file, line: line)
            return
        }
        XCTAssertEqual(url.absoluteString, expected, file: file, line: line)
    }

    private func assertFailure(_ input: String, file: StaticString = #file, line: UInt = #line) {
        let result = HAURLValidator.validate(input)
        guard case .failure = result else {
            XCTFail("Expected failure for \"\(input)\" but got success", file: file, line: line)
            return
        }
    }
}
