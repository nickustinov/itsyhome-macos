//
//  HubitatAuthManager.swift
//  Itsyhome
//
//  Hubitat Maker API authentication and credential management
//

import Foundation
import Security
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatAuthManager")

final class HubitatAuthManager {

    // MARK: - Singleton

    static let shared = HubitatAuthManager()

    // MARK: - Constants

    private let hubURLKey = "HubitatHubURL"
    private let appIdKey = "HubitatAppId"
    private let keychainService = "com.nickustinov.itsyhome.hubitat"
    private let keychainAccount = "access_token"

    // MARK: - Properties

    /// The Hubitat hub URL
    var hubURL: URL? {
        get {
            guard let urlString = UserDefaults.standard.string(forKey: hubURLKey) else {
                return nil
            }
            return URL(string: urlString)
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.absoluteString, forKey: hubURLKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hubURLKey)
            }
        }
    }

    /// The Maker API app ID
    var appId: String? {
        get {
            return UserDefaults.standard.string(forKey: appIdKey)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: appIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: appIdKey)
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
        hubURL != nil && appId != nil && accessToken != nil
    }

    /// Base URL for Maker API calls: http://hub_ip/apps/api/{appId}
    var makerAPIBaseURL: URL? {
        guard let base = hubURL, let id = appId else { return nil }
        return base.appendingPathComponent("apps/api/\(id)")
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public methods

    /// Save credentials
    func saveCredentials(hubURL: URL, appId: String, accessToken: String) {
        self.hubURL = hubURL
        self.appId = appId
        self.accessToken = accessToken
        logger.info("Credentials saved for \(hubURL.host ?? "unknown", privacy: .public)")
    }

    /// Clear all credentials
    func clearCredentials() {
        hubURL = nil
        appId = nil
        accessToken = nil
        logger.info("Credentials cleared")
    }

    /// Validate credentials by testing connection to the Maker API
    func validateCredentials() async throws -> Bool {
        _ = try await validateAndFetchDeviceCount()
        return true
    }

    /// Validate credentials and fetch device count for onboarding
    func validateAndFetchDeviceCount() async throws -> Int {
        guard let baseURL = makerAPIBaseURL, let token = accessToken else {
            throw HubitatAuthError.notConfigured
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("devices"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "access_token", value: token)]

        guard let url = components?.url else {
            throw HubitatAuthError.invalidCredentials
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HubitatAuthError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                logger.error("Device fetch failed with status: \(httpResponse.statusCode)")
                throw HubitatAuthError.invalidCredentials
            }
            guard let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw HubitatAuthError.invalidResponse
            }
            return devices.count
        } catch let error as HubitatAuthError {
            throw error
        } catch {
            logger.error("Device fetch failed: \(error.localizedDescription)")
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

enum HubitatAuthError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Hubitat is not configured"
        case .invalidCredentials: return "Invalid hub URL, app ID, or access token"
        case .invalidResponse: return "Invalid response from Hubitat hub"
        }
    }
}
