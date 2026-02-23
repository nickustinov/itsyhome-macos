//
//  PreferencesManager.swift
//  macOSBridge
//
//  Manages user preferences for favourites and settings
//  Per-home settings are keyed by home ID
//

import AppKit
import Foundation
import ServiceManagement

final class PreferencesManager {

    static let shared = PreferencesManager()

    static let preferencesChangedNotification = Notification.Name("PreferencesManagerDidChange")

    // Current home context - must be set before accessing per-home preferences
    var currentHomeId: String?
    var currentHomeName: String?

    enum Keys {
        // Global settings
        static let launchAtLogin = "launchAtLogin"
        static let camerasEnabled = "camerasEnabled"
        static let doorbellNotifications = "doorbellNotifications"
        static let doorbellSound = "doorbellSound"
        static let doorbellAutoClose = "doorbellAutoClose"
        static let doorbellAutoCloseDelay = "doorbellAutoCloseDelay"
        static let temperatureUnit = "temperatureUnit"
        static let entityCategoryFilter = "entityCategoryFilter"

        // Per-home settings (use with homeKey helper)
        static let orderedFavouriteIds = "orderedFavouriteIds"
        static let favouriteSceneIds = "favouriteSceneIds"
        static let favouriteServiceIds = "favouriteServiceIds"
        static let hiddenSceneIds = "hiddenSceneIds"
        static let hiddenServiceIds = "hiddenServiceIds"
        static let hideScenesSection = "hideScenesSection"
        static let hideOtherSection = "hideOtherSection"
        static let hiddenRoomIds = "hiddenRoomIds"
        static let deviceGroups = "deviceGroups"
        static let hiddenCameraIds = "hiddenCameraIds"
        static let cameraOrder = "cameraOrder"
        static let cameraOverlayAccessories = "cameraOverlayAccessories"
        static let roomOrder = "roomOrder"
        static let sceneOrder = "sceneOrder"
        static let pinnedServiceIds = "pinnedServiceIds"
        static let pinnedServiceShowName = "pinnedServiceShowName"
        static let globalGroupOrder = "globalGroupOrder"
        static let groupOrderByRoom = "groupOrderByRoom"
        static let favouriteGroupIds = "favouriteGroupIds"
        static let customIcons = "customIcons"
    }

    let defaults = UserDefaults.standard

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Keys.launchAtLogin: false,
            Keys.doorbellNotifications: true,
            Keys.doorbellSound: true,
            Keys.doorbellAutoClose: false,
            Keys.doorbellAutoCloseDelay: 60,
            Keys.temperatureUnit: "system",
            Keys.entityCategoryFilter: "hideAll"
        ])

        // Sync launch at login state with system on init
        syncLaunchAtLoginState()
    }

    // MARK: - Per-home key helper

    func homeKey(_ base: String) -> String {
        guard let homeId = currentHomeId else {
            // Fallback to global key if no home set (shouldn't happen in normal use)
            return base
        }
        return "\(base)_\(homeId)"
    }

    // MARK: - Launch at login state

    private func syncLaunchAtLoginState() {
        let shouldLaunch = defaults.bool(forKey: Keys.launchAtLogin)
        let currentStatus = SMAppService.mainApp.status

        // Only update if out of sync
        if shouldLaunch && currentStatus != .enabled {
            try? SMAppService.mainApp.register()
        } else if !shouldLaunch && currentStatus == .enabled {
            try? SMAppService.mainApp.unregister()
        }
    }

    // MARK: - Launch at login (global)

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            updateLaunchAtLoginState(newValue)
            postNotification()
        }
    }

    private func updateLaunchAtLoginState(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    // MARK: - Cameras enabled (global)

    var camerasEnabled: Bool {
        get { defaults.bool(forKey: Keys.camerasEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.camerasEnabled)
            postNotification()
        }
    }

    // MARK: - Doorbell notifications (global)

    var doorbellNotifications: Bool {
        get { defaults.bool(forKey: Keys.doorbellNotifications) }
        set {
            defaults.set(newValue, forKey: Keys.doorbellNotifications)
            postNotification()
        }
    }

    var doorbellSound: Bool {
        get { defaults.bool(forKey: Keys.doorbellSound) }
        set {
            defaults.set(newValue, forKey: Keys.doorbellSound)
            postNotification()
        }
    }

    // MARK: - Temperature unit (global)

    var temperatureUnit: String {
        get { defaults.string(forKey: Keys.temperatureUnit) ?? "system" }
        set {
            defaults.set(newValue, forKey: Keys.temperatureUnit)
            postNotification()
        }
    }

    // MARK: - Entity category filter (global)

    var entityCategoryFilter: String {
        get { defaults.string(forKey: Keys.entityCategoryFilter) ?? "hideAll" }
        set {
            defaults.set(newValue, forKey: Keys.entityCategoryFilter)
            postNotification()
        }
    }

    // MARK: - Doorbell auto-close (global)

    var doorbellAutoClose: Bool {
        get { defaults.bool(forKey: Keys.doorbellAutoClose) }
        set {
            defaults.set(newValue, forKey: Keys.doorbellAutoClose)
            postNotification()
        }
    }

    var doorbellAutoCloseDelay: Int {
        get { defaults.integer(forKey: Keys.doorbellAutoCloseDelay) }
        set {
            defaults.set(newValue, forKey: Keys.doorbellAutoCloseDelay)
            postNotification()
        }
    }

    // MARK: - Notification

    func postNotification() {
        NotificationCenter.default.post(name: Self.preferencesChangedNotification, object: nil)
    }
}
