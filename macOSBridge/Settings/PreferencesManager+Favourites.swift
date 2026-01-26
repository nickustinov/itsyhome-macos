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
