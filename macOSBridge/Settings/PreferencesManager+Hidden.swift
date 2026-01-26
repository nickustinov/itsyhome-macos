//
//  PreferencesManager+Hidden.swift
//  macOSBridge
//
//  Hidden items management (scenes, services, rooms, cameras)
//

import Foundation

extension PreferencesManager {

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
}
