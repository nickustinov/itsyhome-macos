//
//  HAPIdentityKeychain.swift
//  macOSBridge
//
//  Stores the HAP bridge's long-term Ed25519 private key in the Keychain rather
//  than as a plaintext file in Application Support. The key proves the bridge's
//  identity to already-paired Apple Home controllers, so it is the most
//  sensitive part of the pairing triad. This matches how the app already keeps
//  Home Assistant credentials in the Keychain (see HAAuthManager).
//

import Foundation
import Security

enum HAPIdentityKeychain {

    private static let service = "com.nickustinov.itsyhome.hap"
    private static let account = "bridge-identity"

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return data
    }

    static func save(_ data: Data) {
        // Delete-then-add so a re-save never hits errSecDuplicateItem.
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
