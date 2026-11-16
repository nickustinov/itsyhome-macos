//
//  PreferencesManager+Favourites.swift
//  macOSBridge
//
//  Favourite items management (scenes, services, groups)
//

import Foundation

extension PreferencesManager {

    // MARK: - Unified ordered favourites list (per-home)

    /// Single ordered list of all favourite IDs (scenes and services mixed)
    var orderedFavouriteIds: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.orderedFavouriteIds)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.orderedFavouriteIds))
            postNotification()
        }
    }

    /// Moves favourite `id` to position `index` among `displayedIds`, the
    /// favourites on screen. The saved list can also hold favourites that
    /// aren't shown – a deleted accessory or scene – so the move goes by ID:
    /// the favourite lands before the one shown after it, or at the end (#183).
    func moveFavourite(id: String, to index: Int, displayedIds: [String]) {
        var ids = orderedFavouriteIds
        guard ids.contains(id), index >= 0 else { return }
        let shownAfterMove = displayedIds.filter { $0 != id }
        ids.removeAll { $0 == id }
        if index < shownAfterMove.count, let insertAt = ids.firstIndex(of: shownAfterMove[index]) {
            ids.insert(id, at: insertAt)
        } else {
            ids.append(id)
        }
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
}
