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
        static let orderedFavouriteIds = "orderedFavouriteIds"  // Unified ordered list
        static let hiddenSceneIds = "hiddenSceneIds"
        static let hiddenServiceIds = "hiddenServiceIds"
        static let hideScenesSection = "hideScenesSection"
        static let hiddenRoomIds = "hiddenRoomIds"
        static let scenesDisplayMode = "scenesDisplayMode"  // "list" or "grid"
    }

    enum ScenesDisplayMode: String {
        case list = "list"
        case grid = "grid"
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

    // MARK: - Unified ordered favourites list

    /// Single ordered list of all favourite IDs (scenes and services mixed)
    var orderedFavouriteIds: [String] {
        get { defaults.stringArray(forKey: Keys.orderedFavouriteIds) ?? [] }
        set {
            defaults.set(newValue, forKey: Keys.orderedFavouriteIds)
            postNotification()
        }
    }

    func moveFavourite(from sourceIndex: Int, to destinationIndex: Int) {
        var ids = orderedFavouriteIds
        guard sourceIndex >= 0, sourceIndex < ids.count,
              destinationIndex >= 0, destinationIndex < ids.count else { return }
        let item = ids.remove(at: sourceIndex)
        ids.insert(item, at: destinationIndex)
        orderedFavouriteIds = ids
    }

    func addFavourite(id: String) {
        var ids = orderedFavouriteIds
        if !ids.contains(id) {
            ids.append(id)
            orderedFavouriteIds = ids
        }
    }

    func removeFavourite(id: String) {
        var ids = orderedFavouriteIds
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
            orderedFavouriteIds = ids
        }
    }

    // MARK: - Favourite scenes (ordered)

    var orderedFavouriteSceneIds: [String] {
        get { defaults.stringArray(forKey: Keys.favouriteSceneIds) ?? [] }
        set {
            defaults.set(newValue, forKey: Keys.favouriteSceneIds)
            postNotification()
        }
    }

    // Set-based access for backward compatibility
    var favouriteSceneIds: Set<String> {
        get { Set(orderedFavouriteSceneIds) }
        set { orderedFavouriteSceneIds = Array(newValue) }
    }

    func isFavourite(sceneId: String) -> Bool {
        orderedFavouriteSceneIds.contains(sceneId)
    }

    func toggleFavourite(sceneId: String) {
        var ids = orderedFavouriteSceneIds
        if let index = ids.firstIndex(of: sceneId) {
            ids.remove(at: index)
            removeFavourite(id: sceneId)
        } else {
            ids.append(sceneId)
            addFavourite(id: sceneId)
        }
        orderedFavouriteSceneIds = ids
    }

    func moveFavouriteScene(from sourceIndex: Int, to destinationIndex: Int) {
        var ids = orderedFavouriteSceneIds
        let item = ids.remove(at: sourceIndex)
        ids.insert(item, at: destinationIndex)
        orderedFavouriteSceneIds = ids
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

    // MARK: - Favourite services (ordered)

    var orderedFavouriteServiceIds: [String] {
        get { defaults.stringArray(forKey: Keys.favouriteServiceIds) ?? [] }
        set {
            defaults.set(newValue, forKey: Keys.favouriteServiceIds)
            postNotification()
        }
    }

    // Set-based access for backward compatibility
    var favouriteServiceIds: Set<String> {
        get { Set(orderedFavouriteServiceIds) }
        set { orderedFavouriteServiceIds = Array(newValue) }
    }

    func isFavourite(serviceId: String) -> Bool {
        orderedFavouriteServiceIds.contains(serviceId)
    }

    func toggleFavourite(serviceId: String) {
        var ids = orderedFavouriteServiceIds
        if let index = ids.firstIndex(of: serviceId) {
            ids.remove(at: index)
            removeFavourite(id: serviceId)
        } else {
            ids.append(serviceId)
            addFavourite(id: serviceId)
        }
        orderedFavouriteServiceIds = ids
    }

    func moveFavouriteService(from sourceIndex: Int, to destinationIndex: Int) {
        var ids = orderedFavouriteServiceIds
        let item = ids.remove(at: sourceIndex)
        ids.insert(item, at: destinationIndex)
        orderedFavouriteServiceIds = ids
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

    // MARK: - Hide scenes section

    var hideScenesSection: Bool {
        get { defaults.bool(forKey: Keys.hideScenesSection) }
        set {
            defaults.set(newValue, forKey: Keys.hideScenesSection)
            postNotification()
        }
    }

    // MARK: - Scenes display mode

    var scenesDisplayMode: ScenesDisplayMode {
        get {
            let raw = defaults.string(forKey: Keys.scenesDisplayMode) ?? ScenesDisplayMode.list.rawValue
            return ScenesDisplayMode(rawValue: raw) ?? .list
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.scenesDisplayMode)
            postNotification()
        }
    }

    // MARK: - Hidden rooms

    var hiddenRoomIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: Keys.hiddenRoomIds) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.hiddenRoomIds)
            postNotification()
        }
    }

    func isHidden(roomId: String) -> Bool {
        hiddenRoomIds.contains(roomId)
    }

    func toggleHidden(roomId: String) {
        var ids = hiddenRoomIds
        if ids.contains(roomId) {
            ids.remove(roomId)
        } else {
            ids.insert(roomId)
        }
        hiddenRoomIds = ids
    }

    // MARK: - Notification

    private func postNotification() {
        NotificationCenter.default.post(name: Self.preferencesChangedNotification, object: nil)
    }
}
