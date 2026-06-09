//
//  PreferencesManager+VirtualBridge.swift
//  macOSBridge
//
//  Settings for the virtual HomeKit bridge: the master enable flag and the
//  persisted setup code shown to the user for pairing.
//
import Foundation

extension PreferencesManager {
    private static let virtualBridgeEnabledKey = "virtualBridgeEnabled"
    private static let virtualBridgeSetupCodeKey = "virtualBridgeSetupCode"

    var virtualBridgeEnabled: Bool {
        get { defaults.bool(forKey: Self.virtualBridgeEnabledKey) }
        set { defaults.set(newValue, forKey: Self.virtualBridgeEnabledKey); postNotification() }
    }

    /// Stable HomeKit setup code in XXX-XX-XXX form, generated once and persisted.
    var virtualBridgeSetupCode: String {
        if let existing = defaults.string(forKey: Self.virtualBridgeSetupCodeKey), !existing.isEmpty {
            return existing
        }
        let digits = (0..<8).map { _ in String(Int.random(in: 0...9)) }.joined()
        let code = "\(digits.prefix(3))-\(digits.dropFirst(3).prefix(2))-\(digits.suffix(3))"
        defaults.set(code, forKey: Self.virtualBridgeSetupCodeKey)
        return code
    }

    /// Clear the stored setup code so a fresh one is generated on next access
    /// (used by the bridge's full reset).
    func resetVirtualBridgeSetupCode() {
        defaults.removeObject(forKey: Self.virtualBridgeSetupCodeKey)
        postNotification()
    }
}
