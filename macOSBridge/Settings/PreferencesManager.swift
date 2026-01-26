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

    private enum Keys {
        // Global settings
        static let launchAtLogin = "launchAtLogin"
        static let camerasEnabled = "camerasEnabled"

        // Per-home settings (use with homeKey helper)
        static let orderedFavouriteIds = "orderedFavouriteIds"
        static let favouriteSceneIds = "favouriteSceneIds"
        static let favouriteServiceIds = "favouriteServiceIds"
        static let hiddenSceneIds = "hiddenSceneIds"
        static let hiddenServiceIds = "hiddenServiceIds"
        static let hideScenesSection = "hideScenesSection"
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

    private let defaults = UserDefaults.standard

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Keys.launchAtLogin: false
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

    // MARK: - Cameras enabled (global)

    var camerasEnabled: Bool {
        get { defaults.bool(forKey: Keys.camerasEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.camerasEnabled)
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

    // MARK: - Pinned items (services and rooms, for menu bar, per-home)

    /// All pinned item IDs (can be service IDs or room IDs prefixed with "room:")
    var pinnedItemIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Keys.pinnedServiceIds)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Keys.pinnedServiceIds))
            postNotification()
        }
    }

    func isPinned(itemId: String) -> Bool {
        pinnedItemIds.contains(itemId)
    }

    func togglePinned(itemId: String) {
        var ids = pinnedItemIds
        if ids.contains(itemId) {
            ids.remove(itemId)
        } else {
            ids.insert(itemId)
        }
        pinnedItemIds = ids
    }

    // Legacy compatibility for service-only pinning
    var pinnedServiceIds: Set<String> {
        pinnedItemIds.filter { !$0.hasPrefix("room:") }
    }

    func isPinned(serviceId: String) -> Bool {
        isPinned(itemId: serviceId)
    }

    func togglePinned(serviceId: String) {
        togglePinned(itemId: serviceId)
    }

    // Room pinning helpers
    static func roomPinId(_ roomId: String) -> String {
        "room:\(roomId)"
    }

    func isPinnedRoom(roomId: String) -> Bool {
        isPinned(itemId: Self.roomPinId(roomId))
    }

    func togglePinnedRoom(roomId: String) {
        togglePinned(itemId: Self.roomPinId(roomId))
    }

    // Scene pinning helpers
    static func scenePinId(_ sceneId: String) -> String {
        "scene:\(sceneId)"
    }

    func isPinnedScene(sceneId: String) -> Bool {
        isPinned(itemId: Self.scenePinId(sceneId))
    }

    func togglePinnedScene(sceneId: String) {
        togglePinned(itemId: Self.scenePinId(sceneId))
    }

    // Scenes section pinning (the whole Scenes menu)
    static let scenesSectionPinId = "scenesSection"

    var isPinnedScenesSection: Bool {
        isPinned(itemId: Self.scenesSectionPinId)
    }

    func togglePinnedScenesSection() {
        togglePinned(itemId: Self.scenesSectionPinId)
    }

    // Group pinning helpers
    static func groupPinId(_ groupId: String) -> String {
        "group:\(groupId)"
    }

    func isPinnedGroup(groupId: String) -> Bool {
        isPinned(itemId: Self.groupPinId(groupId))
    }

    func togglePinnedGroup(groupId: String) {
        togglePinned(itemId: Self.groupPinId(groupId))
    }

    // MARK: - Pinned item show name setting (per-item, per-home)

    private var pinnedItemShowNameMap: [String: Bool] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.pinnedServiceShowName)),
                  let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.pinnedServiceShowName))
                postNotification()
            }
        }
    }

    func pinnedItemShowsName(itemId: String) -> Bool {
        pinnedItemShowNameMap[itemId] ?? false
    }

    func setPinnedItemShowsName(_ showName: Bool, itemId: String) {
        var map = pinnedItemShowNameMap
        map[itemId] = showName
        pinnedItemShowNameMap = map
    }

    // MARK: - Hidden rooms (per-home)

    var hiddenRoomIds: Set<String> {
        get {
            let key = homeKey(Keys.hiddenRoomIds)
            let array = defaults.stringArray(forKey: key) ?? []
            return Set(array)
        }
        set {
            let key = homeKey(Keys.hiddenRoomIds)
            let array = Array(newValue)
            defaults.set(array, forKey: key)
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

    // MARK: - Hidden cameras (per-home)

    var hiddenCameraIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Keys.hiddenCameraIds)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Keys.hiddenCameraIds))
            postNotification()
        }
    }

    func isHidden(cameraId: String) -> Bool {
        hiddenCameraIds.contains(cameraId)
    }

    func toggleHidden(cameraId: String) {
        var ids = hiddenCameraIds
        if ids.contains(cameraId) {
            ids.remove(cameraId)
        } else {
            ids.insert(cameraId)
        }
        hiddenCameraIds = ids
    }

    // MARK: - Camera order (per-home)

    var cameraOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.cameraOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.cameraOrder))
            postNotification()
        }
    }

    func moveCameraOrder(from sourceIndex: Int, to destinationIndex: Int) {
        var order = cameraOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        cameraOrder = order
    }

    // MARK: - Room order (per-home)

    var roomOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.roomOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.roomOrder))
            postNotification()
        }
    }

    func moveRoom(from sourceIndex: Int, to destinationIndex: Int) {
        var order = roomOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        roomOrder = order
    }

    // MARK: - Scene order (per-home)

    var sceneOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.sceneOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.sceneOrder))
            postNotification()
        }
    }

    func moveScene(from sourceIndex: Int, to destinationIndex: Int) {
        var order = sceneOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        sceneOrder = order
    }

    // MARK: - Camera overlay accessories (per-home)

    /// Mapping of camera ID to array of service IDs for overlay controls
    var cameraOverlayAccessories: [String: [String]] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.cameraOverlayAccessories)),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.cameraOverlayAccessories))
                postNotification()
            }
        }
    }

    func overlayAccessories(for cameraId: String) -> [String] {
        cameraOverlayAccessories[cameraId] ?? []
    }

    func addOverlayAccessory(serviceId: String, to cameraId: String) {
        var mapping = cameraOverlayAccessories
        var list = mapping[cameraId] ?? []
        if !list.contains(serviceId) {
            list.append(serviceId)
            mapping[cameraId] = list
            cameraOverlayAccessories = mapping
        }
    }

    func removeOverlayAccessory(serviceId: String, from cameraId: String) {
        var mapping = cameraOverlayAccessories
        var list = mapping[cameraId] ?? []
        list.removeAll { $0 == serviceId }
        mapping[cameraId] = list.isEmpty ? nil : list
        cameraOverlayAccessories = mapping
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

    // MARK: - Global group order (per-home)

    /// Order of groups that have no room assignment (global groups)
    var globalGroupOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.globalGroupOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.globalGroupOrder))
            postNotification()
        }
    }

    func moveGlobalGroup(from sourceIndex: Int, to destinationIndex: Int) {
        var order = globalGroupOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        globalGroupOrder = order
    }

    // MARK: - Group order by room (per-home)

    /// Per-room group ordering
    var groupOrderByRoom: [String: [String]] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.groupOrderByRoom)),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.groupOrderByRoom))
                postNotification()
            }
        }
    }

    func groupOrder(forRoom roomId: String) -> [String] {
        groupOrderByRoom[roomId] ?? []
    }

    func setGroupOrder(_ order: [String], forRoom roomId: String) {
        var mapping = groupOrderByRoom
        if order.isEmpty {
            mapping.removeValue(forKey: roomId)
        } else {
            mapping[roomId] = order
        }
        groupOrderByRoom = mapping
    }

    func moveGroupInRoom(_ roomId: String, from sourceIndex: Int, to destinationIndex: Int) {
        var order = groupOrder(forRoom: roomId)
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        setGroupOrder(order, forRoom: roomId)
    }

    // MARK: - Favourite groups (per-home)

    var favouriteGroupIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Keys.favouriteGroupIds)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Keys.favouriteGroupIds))
            postNotification()
        }
    }

    func isFavouriteGroup(groupId: String) -> Bool {
        favouriteGroupIds.contains(groupId)
    }

    func toggleFavouriteGroup(groupId: String) {
        var ids = favouriteGroupIds
        let favId = "groupFav:\(groupId)"
        if ids.contains(groupId) {
            ids.remove(groupId)
            removeFavourite(id: favId)
        } else {
            ids.insert(groupId)
            addFavourite(id: favId)
        }
        favouriteGroupIds = ids
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
        removeShortcut(for: id)
    }

    func moveDeviceGroup(from sourceIndex: Int, to destinationIndex: Int) {
        var groups = deviceGroups
        guard sourceIndex >= 0, sourceIndex < groups.count,
              destinationIndex >= 0, destinationIndex < groups.count else { return }
        let group = groups.remove(at: sourceIndex)
        groups.insert(group, at: destinationIndex)
        deviceGroups = groups
    }

    // MARK: - Custom icons (per-home)

    /// Dictionary mapping item IDs (services, scenes, groups) to custom icon names
    var customIcons: [String: String] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.customIcons)),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.customIcons))
                postNotification()
            }
        }
    }

    func customIcon(for itemId: String) -> String? {
        customIcons[itemId]
    }

    func setCustomIcon(_ iconName: String?, for itemId: String) {
        var icons = customIcons
        if let iconName = iconName {
            icons[itemId] = iconName
        } else {
            icons.removeValue(forKey: itemId)
        }
        customIcons = icons
    }

    // MARK: - Notification

    private func postNotification() {
        NotificationCenter.default.post(name: Self.preferencesChangedNotification, object: nil)
    }
}
