//
//  PlatformManager.swift
//  Itsyhome
//
//  Manages the selected smart home platform and coordinates between platforms
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "PlatformManager")

// MARK: - Platform selection

public enum SelectedPlatform: String, Codable {
    case none = "none"
    case homeKit = "homekit"
    case homeAssistant = "homeassistant"
}

// MARK: - Platform manager

public final class PlatformManager {

    // MARK: - Singleton

    public static let shared = PlatformManager()

    // MARK: - Keys

    private let selectedPlatformKey = "SelectedPlatform"
    private let hasCompletedOnboardingKey = "HasCompletedOnboarding"

    // MARK: - Properties

    /// The currently selected platform
    public var selectedPlatform: SelectedPlatform {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: selectedPlatformKey),
                  let platform = SelectedPlatform(rawValue: rawValue) else {
                return .none
            }
            return platform
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: selectedPlatformKey)
            logger.info("Platform set to: \(newValue.rawValue, privacy: .public)")
        }
    }

    /// Whether the user has completed onboarding (platform selection)
    public var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey)
        }
    }

    /// Whether a platform is configured and ready
    public var isPlatformConfigured: Bool {
        switch selectedPlatform {
        case .none:
            return false
        case .homeKit:
            return true  // HomeKit is always "configured" once selected (permission handled separately)
        case .homeAssistant:
            // Check if HA server URL is configured (HAAuthManager stores this in UserDefaults)
            return UserDefaults.standard.string(forKey: "HomeAssistantServerURL") != nil
        }
    }

    /// Whether the app needs to show onboarding
    public var needsOnboarding: Bool {
        !hasCompletedOnboarding || selectedPlatform == .none
    }

    // MARK: - Initialization

    private init() {
        logger.info("PlatformManager initialized, platform: \(self.selectedPlatform.rawValue, privacy: .public)")
    }

    // MARK: - Platform selection

    /// Select HomeKit as the platform
    public func selectHomeKit() {
        selectedPlatform = .homeKit
        hasCompletedOnboarding = true
        logger.info("HomeKit selected")
    }

    /// Select Home Assistant as the platform
    public func selectHomeAssistant() {
        selectedPlatform = .homeAssistant
        hasCompletedOnboarding = true
        logger.info("Home Assistant selected")
    }

    /// Reset platform selection (for testing/settings)
    public func resetPlatform() {
        selectedPlatform = .none
        hasCompletedOnboarding = false
        // Note: HA credentials are cleared separately via HAAuthManager when available
        logger.info("Platform reset")
    }

    /// Clear Home Assistant credentials (called from code that has access to HAAuthManager)
    public func clearHomeAssistantCredentials() {
        UserDefaults.standard.removeObject(forKey: "HomeAssistantServerURL")
        // Token is in Keychain, cleared by HAAuthManager
    }
}
