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

    private enum Keys {
        // Global settings
        static let launchAtLogin = "launchAtLogin"
        static let scenesDisplayMode = "scenesDisplayMode"

        // Per-home settings (use with homeKey helper)
        static let orderedFavouriteIds = "orderedFavouriteIds"
        static let favouriteSceneIds = "favouriteSceneIds"
        static let favouriteServiceIds = "favouriteServiceIds"
        static let hiddenSceneIds = "hiddenSceneIds"
        static let hiddenServiceIds = "hiddenServiceIds"
        static let hideScenesSection = "hideScenesSection"
        static let hiddenRoomIds = "hiddenRoomIds"
        static let deviceGroups = "deviceGroups"
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

    // MARK: - Per-home key helper

    private func homeKey(_ base: String) -> String {
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

    // MARK: - Scenes display mode (global)

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

    // MARK: - Unified ordered favourites list (per-home)

    /// Single ordered list of all favourite IDs (scenes and services mixed)
    var orderedFavouriteIds: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.orderedFavouriteIds)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.orderedFavouriteIds))
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

    // MARK: - Favourite scenes (per-home)

    var orderedFavouriteSceneIds: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.favouriteSceneIds)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.favouriteSceneIds))
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

    // MARK: - Hidden scenes (per-home)

    var hiddenSceneIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Keys.hiddenSceneIds)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Keys.hiddenSceneIds))
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

    // MARK: - Favourite services (per-home)

    var orderedFavouriteServiceIds: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.favouriteServiceIds)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.favouriteServiceIds))
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

    // MARK: - Hidden services (per-home)

    var hiddenServiceIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Keys.hiddenServiceIds)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Keys.hiddenServiceIds))
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

    // MARK: - Hide scenes section (per-home)

    var hideScenesSection: Bool {
        get { defaults.bool(forKey: homeKey(Keys.hideScenesSection)) }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.hideScenesSection))
            postNotification()
        }
    }

    // MARK: - Hidden rooms (per-home)

    var hiddenRoomIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Keys.hiddenRoomIds)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Keys.hiddenRoomIds))
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

    // MARK: - Shortcuts (per-home)

    /// Shortcut data: keyCode (UInt16) and modifiers (UInt)
    struct ShortcutData: Codable, Equatable {
        let keyCode: UInt16
        let modifiers: UInt  // NSEvent.ModifierFlags.rawValue

        var modifierFlags: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(rawValue: modifiers)
        }

        init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifiers = modifiers.rawValue
        }
    }

    private var shortcutsKey: String {
        homeKey("shortcuts")
    }

    /// Get all shortcuts for current home
    var shortcuts: [String: ShortcutData] {
        get {
            guard let data = defaults.data(forKey: shortcutsKey),
                  let dict = try? JSONDecoder().decode([String: ShortcutData].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: shortcutsKey)
                postNotification()
            }
        }
    }

    func shortcut(for favouriteId: String) -> ShortcutData? {
        shortcuts[favouriteId]
    }

    func setShortcut(_ shortcut: ShortcutData?, for favouriteId: String) {
        var current = shortcuts
        current[favouriteId] = shortcut
        shortcuts = current
    }

    func removeShortcut(for favouriteId: String) {
        setShortcut(nil, for: favouriteId)
    }

    /// Find favourite ID by shortcut (for lookup when hotkey triggered)
    func favouriteId(for shortcut: ShortcutData) -> String? {
        shortcuts.first { $0.value == shortcut }?.key
    }

    // MARK: - Device Groups (per-home)

    var deviceGroups: [DeviceGroup] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.deviceGroups)),
                  let groups = try? JSONDecoder().decode([DeviceGroup].self, from: data) else {
                return []
            }
            return groups
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.deviceGroups))
                postNotification()
            }
        }
    }

    func deviceGroup(id: String) -> DeviceGroup? {
        deviceGroups.first { $0.id == id }
    }

    func addDeviceGroup(_ group: DeviceGroup) {
        var groups = deviceGroups
        groups.append(group)
        deviceGroups = groups
    }

    func updateDeviceGroup(_ group: DeviceGroup) {
        var groups = deviceGroups
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            deviceGroups = groups
        }
    }

    func deleteDeviceGroup(id: String) {
        var groups = deviceGroups
        groups.removeAll { $0.id == id }
        deviceGroups = groups
    }

    func moveDeviceGroup(from sourceIndex: Int, to destinationIndex: Int) {
        var groups = deviceGroups
        guard sourceIndex >= 0, sourceIndex < groups.count,
              destinationIndex >= 0, destinationIndex < groups.count else { return }
        let group = groups.remove(at: sourceIndex)
        groups.insert(group, at: destinationIndex)
        deviceGroups = groups
    }

    // MARK: - Notification

    private func postNotification() {
        NotificationCenter.default.post(name: Self.preferencesChangedNotification, object: nil)
    }
}
