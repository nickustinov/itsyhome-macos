//
//  HAAuthManager.swift
//  Itsyhome
//
//  Home Assistant authentication and credential management
//

import Foundation
import Security
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HAAuthManager")

final class HAAuthManager {

    // MARK: - Singleton

    static let shared = HAAuthManager()

    // MARK: - Constants

    private let serverURLKey = "HomeAssistantServerURL"
    private let keychainService = "com.nickustinov.itsyhome.homeassistant"
    private let keychainAccount = "access_token"

    // MARK: - Properties

    /// The Home Assistant server URL
    var serverURL: URL? {
        get {
            guard let urlString = UserDefaults.standard.string(forKey: serverURLKey) else {
                return nil
            }
            return URL(string: urlString)
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.absoluteString, forKey: serverURLKey)
            } else {
                UserDefaults.standard.removeObject(forKey: serverURLKey)
            }
        }
    }

    /// The access token (stored securely in Keychain)
    var accessToken: String? {
        get {
            return readTokenFromKeychain()
        }
        set {
            if let token = newValue {
                saveTokenToKeychain(token)
            } else {
                deleteTokenFromKeychain()
            }
        }
    }

    /// Whether credentials are configured
    var isConfigured: Bool {
        serverURL != nil && accessToken != nil
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public methods

    /// Save credentials
    func saveCredentials(serverURL: URL, accessToken: String) {
        self.serverURL = serverURL
        self.accessToken = accessToken
        logger.info("Credentials saved for \(serverURL.host ?? "unknown", privacy: .public)")
    }

    /// Clear all credentials
    func clearCredentials() {
        serverURL = nil
        accessToken = nil
        logger.info("Credentials cleared")
    }

    /// Validate credentials by testing connection
    func validateCredentials() async throws -> Bool {
        guard let url = serverURL, let token = accessToken else {
            throw HAAuthError.notConfigured
        }

        // Try to connect and get config
        let client = HomeAssistantClient(serverURL: url, accessToken: token)

        do {
            try await client.connect()
            client.disconnect()
            return true
        } catch {
            logger.error("Credential validation failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Keychain operations

    private func saveTokenToKeychain(_ token: String) {
        guard let tokenData = token.data(using: .utf8) else {
            logger.error("Failed to encode token")
            return
        }

        // Delete existing item first
        deleteTokenFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.info("Token saved to Keychain")
        } else {
            logger.error("Failed to save token to Keychain: \(status)")
        }
    }

    private func readTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }

        return nil
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            logger.info("Token deleted from Keychain")
        } else {
            logger.error("Failed to delete token from Keychain: \(status)")
        }
    }
}

// MARK: - Errors

enum HAAuthError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Home Assistant is not configured"
        case .invalidURL:
            return "Invalid server URL"
        case .invalidToken:
            return "Invalid access token"
        }
    }
}
