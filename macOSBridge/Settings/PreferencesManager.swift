//
//  PreferencesManager.swift
//  macOSBridge
//
//  Manages user preferences for favourites and settings
//

import Foundation
import ServiceManagement

final class PreferencesManager {

    static let shared = PreferencesManager()

    static let preferencesChangedNotification = Notification.Name("PreferencesManagerDidChange")

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let favouriteSceneIds = "favouriteSceneIds"
        static let favouriteServiceIds = "favouriteServiceIds"
        static let hiddenSceneIds = "hiddenSceneIds"
        static let hiddenServiceIds = "hiddenServiceIds"
    }

    private let defaults = UserDefaults.standard

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Keys.launchAtLogin: true
        ])

        // Sync launch at login state with system on init
        syncLaunchAtLoginState()
    }

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

    // MARK: - Launch at login

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

    // MARK: - Favourite scenes

    var favouriteSceneIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: Keys.favouriteSceneIds) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.favouriteSceneIds)
            postNotification()
        }
    }

    func isFavourite(sceneId: String) -> Bool {
        favouriteSceneIds.contains(sceneId)
    }

    func toggleFavourite(sceneId: String) {
        var ids = favouriteSceneIds
        if ids.contains(sceneId) {
            ids.remove(sceneId)
        } else {
            ids.insert(sceneId)
        }
        favouriteSceneIds = ids
    }

    // MARK: - Hidden scenes

    var hiddenSceneIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: Keys.hiddenSceneIds) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.hiddenSceneIds)
            postNotification()
        }
    }

    func isHidden(sceneId: String) -> Bool {
        hiddenSceneIds.contains(sceneId)
    }

    func toggleHidden(sceneId: String) {
        var ids = hiddenSceneIds
        if ids.contains(sceneId) {
            ids.remove(sceneId)
        } else {
            ids.insert(sceneId)
        }
        hiddenSceneIds = ids
    }

    // MARK: - Favourite services

    var favouriteServiceIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: Keys.favouriteServiceIds) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.favouriteServiceIds)
            postNotification()
        }
    }

    func isFavourite(serviceId: String) -> Bool {
        favouriteServiceIds.contains(serviceId)
    }

    func toggleFavourite(serviceId: String) {
        var ids = favouriteServiceIds
        if ids.contains(serviceId) {
            ids.remove(serviceId)
        } else {
            ids.insert(serviceId)
        }
        favouriteServiceIds = ids
    }

    // MARK: - Hidden services

    var hiddenServiceIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: Keys.hiddenServiceIds) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.hiddenServiceIds)
            postNotification()
        }
    }

    func isHidden(serviceId: String) -> Bool {
        hiddenServiceIds.contains(serviceId)
    }

    func toggleHidden(serviceId: String) {
        var ids = hiddenServiceIds
        if ids.contains(serviceId) {
            ids.remove(serviceId)
        } else {
            ids.insert(serviceId)
        }
        hiddenServiceIds = ids
    }

    // MARK: - Notification

    private func postNotification() {
        NotificationCenter.default.post(name: Self.preferencesChangedNotification, object: nil)
    }
}
