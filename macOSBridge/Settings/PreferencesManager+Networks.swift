//
//  PreferencesManager+Networks.swift
//  macOSBridge
//
//  Network auto-switch rule models and preference storage
//

import Foundation

// MARK: - Rule models

struct HomeKitNetworkRule: Codable, Equatable {
    let id: UUID
    let ssid: String
    let homeId: String      // HomeData.uniqueIdentifier
    let homeName: String    // cached display name
}

struct HANetworkRule: Codable, Equatable {
    let id: UUID
    let ssid: String
    let serverURL: String   // e.g. "http://192.168.1.50:8123"
    let accessToken: String? // nil = use default token
}

// MARK: - PreferencesManager extension

extension PreferencesManager {

    private static let networkAutoSwitchEnabledKey = "NetworkAutoSwitchEnabled"
    private static let homeKitNetworkRulesKey = "NetworkRules_HomeKit"
    private static let haNetworkRulesKey = "NetworkRules_HomeAssistant"

    // MARK: - Enabled toggle

    var networkAutoSwitchEnabled: Bool {
        get { defaults.bool(forKey: Self.networkAutoSwitchEnabledKey) }
        set {
            defaults.set(newValue, forKey: Self.networkAutoSwitchEnabledKey)
            postNotification()
        }
    }

    // MARK: - HomeKit rules

    var homeKitNetworkRules: [HomeKitNetworkRule] {
        get {
            guard let data = defaults.data(forKey: Self.homeKitNetworkRulesKey),
                  let rules = try? JSONDecoder().decode([HomeKitNetworkRule].self, from: data) else {
                return []
            }
            return rules
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.homeKitNetworkRulesKey)
                postNotification()
            }
        }
    }

    func homeKitRule(for ssid: String) -> HomeKitNetworkRule? {
        homeKitNetworkRules.first { $0.ssid == ssid }
    }

    func addHomeKitRule(_ rule: HomeKitNetworkRule) {
        var rules = homeKitNetworkRules
        // Replace existing rule for same SSID
        rules.removeAll { $0.ssid == rule.ssid }
        rules.append(rule)
        homeKitNetworkRules = rules
    }

    func removeHomeKitRule(id: UUID) {
        var rules = homeKitNetworkRules
        rules.removeAll { $0.id == id }
        homeKitNetworkRules = rules
    }

    // MARK: - Home Assistant rules

    var haNetworkRules: [HANetworkRule] {
        get {
            guard let data = defaults.data(forKey: Self.haNetworkRulesKey),
                  let rules = try? JSONDecoder().decode([HANetworkRule].self, from: data) else {
                return []
            }
            return rules
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.haNetworkRulesKey)
                postNotification()
            }
        }
    }

    func haRule(for ssid: String) -> HANetworkRule? {
        haNetworkRules.first { $0.ssid == ssid }
    }

    func addHARule(_ rule: HANetworkRule) {
        var rules = haNetworkRules
        // Replace existing rule for same SSID
        rules.removeAll { $0.ssid == rule.ssid }
        rules.append(rule)
        haNetworkRules = rules
    }

    func removeHARule(id: UUID) {
        var rules = haNetworkRules
        rules.removeAll { $0.id == id }
        haNetworkRules = rules
    }
}
