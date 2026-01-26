//
//  PreferencesManager+Pinned.swift
//  macOSBridge
//
//  Pinned items management for menu bar (services, rooms, scenes, groups)
//

import Foundation

extension PreferencesManager {

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
}
