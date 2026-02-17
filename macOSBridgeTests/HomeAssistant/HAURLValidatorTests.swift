//
//  HAURLValidatorTests.swift
//  macOSBridgeTests
//

import XCTest

final class HAURLValidatorTests: XCTestCase {

    // MARK: - Success cases

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

    func testBareHostnameGetsSchemePrepended() {
        assertSuccess("homeassistant.local:8123",
                       expected: "http://homeassistant.local:8123")
    }

    func testBareIPGetsSchemePrepended() {
        assertSuccess("192.168.1.100:8123",
                       expected: "http://192.168.1.100:8123")
    }

    func testBareHostnameWithoutPort() {
        assertSuccess("homeassistant.local",
                       expected: "http://homeassistant.local")
    }

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
