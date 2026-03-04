//
//  NetworkAutoSwitchTests.swift
//  macOSBridgeTests
//
//  Tests for network auto-switch rule models and matching
//

import XCTest
@testable import macOSBridge

final class NetworkAutoSwitchTests: XCTestCase {

    private let prefs = PreferencesManager.shared

    override func setUp() {
        super.setUp()
        // Clear any existing rules
        UserDefaults.standard.removeObject(forKey: "NetworkAutoSwitchEnabled")
        UserDefaults.standard.removeObject(forKey: "NetworkRules_HomeKit")
        UserDefaults.standard.removeObject(forKey: "NetworkRules_HomeAssistant")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "NetworkAutoSwitchEnabled")
        UserDefaults.standard.removeObject(forKey: "NetworkRules_HomeKit")
        UserDefaults.standard.removeObject(forKey: "NetworkRules_HomeAssistant")
        super.tearDown()
    }

    // MARK: - Toggle

    func testNetworkAutoSwitchDefaultsToDisabled() {
        XCTAssertFalse(prefs.networkAutoSwitchEnabled)
    }

    func testNetworkAutoSwitchPersists() {
        prefs.networkAutoSwitchEnabled = true
        XCTAssertTrue(prefs.networkAutoSwitchEnabled)
        prefs.networkAutoSwitchEnabled = false
        XCTAssertFalse(prefs.networkAutoSwitchEnabled)
    }

    // MARK: - HomeKit rule serialisation

    func testHomeKitRuleSerialisationRoundTrip() {
        let rule = HomeKitNetworkRule(id: UUID(), ssid: "MyWiFi", homeId: "home-123", homeName: "Main house")
        prefs.addHomeKitRule(rule)

        let loaded = prefs.homeKitNetworkRules
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first, rule)
    }

    func testHomeKitRuleReplacesExistingSSID() {
        let rule1 = HomeKitNetworkRule(id: UUID(), ssid: "MyWiFi", homeId: "home-123", homeName: "Main house")
        let rule2 = HomeKitNetworkRule(id: UUID(), ssid: "MyWiFi", homeId: "home-456", homeName: "Beach house")

        prefs.addHomeKitRule(rule1)
        prefs.addHomeKitRule(rule2)

        let loaded = prefs.homeKitNetworkRules
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.homeId, "home-456")
    }

    func testHomeKitRuleRemoval() {
        let rule = HomeKitNetworkRule(id: UUID(), ssid: "MyWiFi", homeId: "home-123", homeName: "Main house")
        prefs.addHomeKitRule(rule)
        prefs.removeHomeKitRule(id: rule.id)

        XCTAssertTrue(prefs.homeKitNetworkRules.isEmpty)
    }

    func testHomeKitRuleLookupBySSID() {
        let rule = HomeKitNetworkRule(id: UUID(), ssid: "Office", homeId: "home-789", homeName: "Office")
        prefs.addHomeKitRule(rule)

        XCTAssertEqual(prefs.homeKitRule(for: "Office"), rule)
        XCTAssertNil(prefs.homeKitRule(for: "Unknown"))
    }

    func testHomeKitMultipleRulesForDifferentSSIDs() {
        let rule1 = HomeKitNetworkRule(id: UUID(), ssid: "Home", homeId: "home-1", homeName: "Home")
        let rule2 = HomeKitNetworkRule(id: UUID(), ssid: "Office", homeId: "home-2", homeName: "Office")
        prefs.addHomeKitRule(rule1)
        prefs.addHomeKitRule(rule2)

        XCTAssertEqual(prefs.homeKitNetworkRules.count, 2)
        XCTAssertEqual(prefs.homeKitRule(for: "Home")?.homeId, "home-1")
        XCTAssertEqual(prefs.homeKitRule(for: "Office")?.homeId, "home-2")
    }

    // MARK: - HA rule serialisation

    func testHARuleSerialisationRoundTrip() {
        let rule = HANetworkRule(id: UUID(), ssid: "MyWiFi", serverURL: "http://192.168.1.50:8123", accessToken: nil)
        prefs.addHARule(rule)

        let loaded = prefs.haNetworkRules
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first, rule)
    }

    func testHARuleReplacesExistingSSID() {
        let rule1 = HANetworkRule(id: UUID(), ssid: "MyWiFi", serverURL: "http://192.168.1.50:8123", accessToken: nil)
        let rule2 = HANetworkRule(id: UUID(), ssid: "MyWiFi", serverURL: "https://ha.example.com", accessToken: nil)

        prefs.addHARule(rule1)
        prefs.addHARule(rule2)

        let loaded = prefs.haNetworkRules
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.serverURL, "https://ha.example.com")
    }

    func testHARuleRemoval() {
        let rule = HANetworkRule(id: UUID(), ssid: "MyWiFi", serverURL: "http://192.168.1.50:8123", accessToken: nil)
        prefs.addHARule(rule)
        prefs.removeHARule(id: rule.id)

        XCTAssertTrue(prefs.haNetworkRules.isEmpty)
    }

    func testHARuleLookupBySSID() {
        let rule = HANetworkRule(id: UUID(), ssid: "HomeNet", serverURL: "http://10.0.0.5:8123", accessToken: nil)
        prefs.addHARule(rule)

        XCTAssertEqual(prefs.haRule(for: "HomeNet"), rule)
        XCTAssertNil(prefs.haRule(for: "Unknown"))
    }

    func testHAMultipleRulesForDifferentSSIDs() {
        let rule1 = HANetworkRule(id: UUID(), ssid: "Home", serverURL: "http://192.168.1.50:8123", accessToken: nil)
        let rule2 = HANetworkRule(id: UUID(), ssid: "Office", serverURL: "https://remote.example.com", accessToken: nil)
        prefs.addHARule(rule1)
        prefs.addHARule(rule2)

        XCTAssertEqual(prefs.haNetworkRules.count, 2)
        XCTAssertEqual(prefs.haRule(for: "Home")?.serverURL, "http://192.168.1.50:8123")
        XCTAssertEqual(prefs.haRule(for: "Office")?.serverURL, "https://remote.example.com")
    }

    // MARK: - HA rule with access token

    func testHARuleWithTokenRoundTrip() {
        let rule = HANetworkRule(id: UUID(), ssid: "Home", serverURL: "http://192.168.1.50:8123", accessToken: "secret-token-123")
        prefs.addHARule(rule)

        let loaded = prefs.haNetworkRules.first
        XCTAssertEqual(loaded?.accessToken, "secret-token-123")
    }

    func testHARuleWithNilTokenRoundTrip() {
        let rule = HANetworkRule(id: UUID(), ssid: "Home", serverURL: "http://192.168.1.50:8123", accessToken: nil)
        prefs.addHARule(rule)

        let loaded = prefs.haNetworkRules.first
        XCTAssertNil(loaded?.accessToken)
    }

    // MARK: - Empty state

    func testEmptyRulesReturnEmptyArrays() {
        XCTAssertTrue(prefs.homeKitNetworkRules.isEmpty)
        XCTAssertTrue(prefs.haNetworkRules.isEmpty)
    }

    func testLookupOnEmptyReturnsNil() {
        XCTAssertNil(prefs.homeKitRule(for: "anything"))
        XCTAssertNil(prefs.haRule(for: "anything"))
    }
}
