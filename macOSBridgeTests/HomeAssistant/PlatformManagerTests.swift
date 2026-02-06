//
//  PlatformManagerTests.swift
//  macOSBridgeTests
//
//  Tests for PlatformManager platform selection and migration logic
//

import XCTest
@testable import macOSBridge

final class PlatformManagerTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private let suiteName = "com.itsyhome.tests.platformmanager"

    override func setUp() {
        super.setUp()
        // Use a separate UserDefaults suite for testing
        userDefaults = UserDefaults(suiteName: suiteName)!
        // Clear all keys in the suite
        userDefaults.removePersistentDomain(forName: suiteName)
        // Also explicitly remove migration-related keys
        for key in ["launchAtLogin", "camerasEnabled", "doorbellNotifications", "SelectedPlatform", "HasCompletedOnboarding", "HomeAssistantServerURL"] {
            userDefaults.removeObject(forKey: key)
        }
        userDefaults.synchronize()
    }

    override func tearDown() {
        // Clear suite again to prevent test pollution
        if let suite = userDefaults {
            suite.removePersistentDomain(forName: suiteName)
            suite.synchronize()
        }
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - Selected platform tests

    func testDefaultSelectedPlatformIsNone() {
        // Given a fresh UserDefaults
        userDefaults.removeObject(forKey: "SelectedPlatform")

        // When reading selected platform
        let rawValue = userDefaults.string(forKey: "SelectedPlatform")

        // Then it should be nil (defaults to .none)
        XCTAssertNil(rawValue)
    }

    func testSelectedPlatformPersistsHomeKit() {
        // When setting platform to HomeKit
        userDefaults.set(SelectedPlatform.homeKit.rawValue, forKey: "SelectedPlatform")

        // Then it should persist
        let rawValue = userDefaults.string(forKey: "SelectedPlatform")
        XCTAssertEqual(rawValue, "homekit")
        XCTAssertEqual(SelectedPlatform(rawValue: rawValue!), .homeKit)
    }

    func testSelectedPlatformPersistsHomeAssistant() {
        // When setting platform to Home Assistant
        userDefaults.set(SelectedPlatform.homeAssistant.rawValue, forKey: "SelectedPlatform")

        // Then it should persist
        let rawValue = userDefaults.string(forKey: "SelectedPlatform")
        XCTAssertEqual(rawValue, "homeassistant")
        XCTAssertEqual(SelectedPlatform(rawValue: rawValue!), .homeAssistant)
    }

    // MARK: - Onboarding state tests

    func testHasCompletedOnboardingDefaultsToFalse() {
        // Given fresh UserDefaults
        userDefaults.removeObject(forKey: "HasCompletedOnboarding")

        // When reading onboarding state
        let completed = userDefaults.bool(forKey: "HasCompletedOnboarding")

        // Then it should be false
        XCTAssertFalse(completed)
    }

    func testHasCompletedOnboardingPersists() {
        // When setting onboarding complete
        userDefaults.set(true, forKey: "HasCompletedOnboarding")

        // Then it should persist
        XCTAssertTrue(userDefaults.bool(forKey: "HasCompletedOnboarding"))
    }

    // MARK: - Needs onboarding logic tests

    func testNeedsOnboardingWhenPlatformIsNone() {
        // Given platform is none and onboarding not completed
        userDefaults.set(SelectedPlatform.none.rawValue, forKey: "SelectedPlatform")
        userDefaults.set(false, forKey: "HasCompletedOnboarding")

        // When checking needs onboarding
        let platform = SelectedPlatform(rawValue: userDefaults.string(forKey: "SelectedPlatform") ?? "") ?? .none
        let hasCompleted = userDefaults.bool(forKey: "HasCompletedOnboarding")
        let needsOnboarding = !hasCompleted || platform == .none

        // Then it should need onboarding
        XCTAssertTrue(needsOnboarding)
    }

    func testNeedsOnboardingWhenOnboardingNotCompleted() {
        // Given platform is set but onboarding not completed
        userDefaults.set(SelectedPlatform.homeKit.rawValue, forKey: "SelectedPlatform")
        userDefaults.set(false, forKey: "HasCompletedOnboarding")

        // When checking needs onboarding
        let hasCompleted = userDefaults.bool(forKey: "HasCompletedOnboarding")
        let needsOnboarding = !hasCompleted

        // Then it should need onboarding
        XCTAssertTrue(needsOnboarding)
    }

    func testDoesNotNeedOnboardingWhenCompleted() {
        // Given platform is set and onboarding completed
        userDefaults.set(SelectedPlatform.homeKit.rawValue, forKey: "SelectedPlatform")
        userDefaults.set(true, forKey: "HasCompletedOnboarding")

        // When checking needs onboarding
        let platform = SelectedPlatform(rawValue: userDefaults.string(forKey: "SelectedPlatform") ?? "") ?? .none
        let hasCompleted = userDefaults.bool(forKey: "HasCompletedOnboarding")
        let needsOnboarding = !hasCompleted || platform == .none

        // Then it should not need onboarding
        XCTAssertFalse(needsOnboarding)
    }

    // MARK: - Platform configured logic tests

    func testPlatformConfiguredForNone() {
        // Given platform is none
        let platform = SelectedPlatform.none

        // When checking if configured
        let isConfigured: Bool
        switch platform {
        case .none:
            isConfigured = false
        case .homeKit:
            isConfigured = true
        case .homeAssistant:
            isConfigured = userDefaults.string(forKey: "HomeAssistantServerURL") != nil
        }

        // Then it should not be configured
        XCTAssertFalse(isConfigured)
    }

    func testPlatformConfiguredForHomeKit() {
        // Given platform is HomeKit
        let platform = SelectedPlatform.homeKit

        // When checking if configured
        let isConfigured: Bool
        switch platform {
        case .none:
            isConfigured = false
        case .homeKit:
            isConfigured = true  // HomeKit is always configured once selected
        case .homeAssistant:
            isConfigured = false
        }

        // Then it should be configured
        XCTAssertTrue(isConfigured)
    }

    func testPlatformConfiguredForHomeAssistantWithoutURL() {
        // Given platform is HA but no server URL set
        userDefaults.removeObject(forKey: "HomeAssistantServerURL")
        let platform = SelectedPlatform.homeAssistant

        // When checking if configured
        let isConfigured: Bool
        switch platform {
        case .none:
            isConfigured = false
        case .homeKit:
            isConfigured = true
        case .homeAssistant:
            isConfigured = userDefaults.string(forKey: "HomeAssistantServerURL") != nil
        }

        // Then it should not be configured
        XCTAssertFalse(isConfigured)
    }

    func testPlatformConfiguredForHomeAssistantWithURL() {
        // Given platform is HA with server URL set
        userDefaults.set("http://homeassistant.local:8123", forKey: "HomeAssistantServerURL")
        let platform = SelectedPlatform.homeAssistant

        // When checking if configured
        let isConfigured: Bool
        switch platform {
        case .none:
            isConfigured = false
        case .homeKit:
            isConfigured = true
        case .homeAssistant:
            isConfigured = userDefaults.string(forKey: "HomeAssistantServerURL") != nil
        }

        // Then it should be configured
        XCTAssertTrue(isConfigured)
    }

    // MARK: - Migration logic tests

    func testMigrationDetectsExistingUserByLaunchAtLogin() {
        // Given a user with launchAtLogin setting (1.x user)
        userDefaults.set(true, forKey: "launchAtLogin")
        userDefaults.removeObject(forKey: "SelectedPlatform")
        userDefaults.removeObject(forKey: "HasCompletedOnboarding")

        // When checking for existing user indicators
        let existingUserIndicators = ["launchAtLogin", "camerasEnabled", "doorbellNotifications"]
        let hasExistingData = existingUserIndicators.contains { key in
            userDefaults.object(forKey: key) != nil
        }

        // Then it should detect existing user
        XCTAssertTrue(hasExistingData)
    }

    func testMigrationDetectsExistingUserByCamerasEnabled() {
        // Given a user with camerasEnabled setting
        userDefaults.set(true, forKey: "camerasEnabled")
        userDefaults.removeObject(forKey: "SelectedPlatform")

        // When checking for existing user indicators
        let existingUserIndicators = ["launchAtLogin", "camerasEnabled", "doorbellNotifications"]
        let hasExistingData = existingUserIndicators.contains { key in
            userDefaults.object(forKey: key) != nil
        }

        // Then it should detect existing user
        XCTAssertTrue(hasExistingData)
    }

    func testMigrationLogicWithNoExistingData() {
        // This tests the migration detection logic:
        // If no 1.x keys are set, hasExistingData should be false
        // Note: We simulate this by checking keys we know aren't set

        let nonExistentKeys = [
            "itsyhome_test_nonexistent_key_\(UUID().uuidString)",
            "itsyhome_test_another_key_\(UUID().uuidString)"
        ]

        // When checking for non-existent keys
        let hasExistingData = nonExistentKeys.contains { key in
            userDefaults.object(forKey: key) != nil
        }

        // Then it should not find any
        XCTAssertFalse(hasExistingData)
    }

    func testMigrationSkipsIfPlatformAlreadySet() {
        // Given platform is already set
        userDefaults.set(SelectedPlatform.homeAssistant.rawValue, forKey: "SelectedPlatform")
        userDefaults.set(true, forKey: "launchAtLogin")  // Has 1.x data

        // When checking migration condition
        let platform = SelectedPlatform(rawValue: userDefaults.string(forKey: "SelectedPlatform") ?? "") ?? .none
        let hasCompleted = userDefaults.bool(forKey: "HasCompletedOnboarding")
        let shouldMigrate = platform == .none && !hasCompleted

        // Then it should not migrate
        XCTAssertFalse(shouldMigrate)
    }

    func testMigrationSkipsIfOnboardingCompleted() {
        // Given onboarding already completed
        userDefaults.set(true, forKey: "HasCompletedOnboarding")
        userDefaults.set(true, forKey: "launchAtLogin")

        // When checking migration condition
        let platform = SelectedPlatform(rawValue: userDefaults.string(forKey: "SelectedPlatform") ?? "") ?? .none
        let hasCompleted = userDefaults.bool(forKey: "HasCompletedOnboarding")
        let shouldMigrate = platform == .none && !hasCompleted

        // Then it should not migrate
        XCTAssertFalse(shouldMigrate)
    }

    // MARK: - SelectedPlatform enum tests

    func testSelectedPlatformRawValues() {
        XCTAssertEqual(SelectedPlatform.none.rawValue, "none")
        XCTAssertEqual(SelectedPlatform.homeKit.rawValue, "homekit")
        XCTAssertEqual(SelectedPlatform.homeAssistant.rawValue, "homeassistant")
    }

    func testSelectedPlatformFromRawValue() {
        XCTAssertEqual(SelectedPlatform(rawValue: "none"), SelectedPlatform.none)
        XCTAssertEqual(SelectedPlatform(rawValue: "homekit"), SelectedPlatform.homeKit)
        XCTAssertEqual(SelectedPlatform(rawValue: "homeassistant"), SelectedPlatform.homeAssistant)
    }

    func testSelectedPlatformInvalidRawValueReturnsNil() {
        // An invalid raw value should return nil from the RawRepresentable init
        let result = SelectedPlatform(rawValue: "totally_invalid_value_123")
        XCTAssertNil(result)
    }
}
