//
//  CloudSyncManager.swift
//  macOSBridge
//
//  Manages iCloud sync using NSUbiquitousKeyValueStore for Pro users
//

import Foundation

final class CloudSyncManager {

    static let shared = CloudSyncManager()

    static let syncStatusChangedNotification = Notification.Name("CloudSyncManagerStatusChanged")

    private let defaults = UserDefaults.standard
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private var isListening = false
    private var isSyncing = false
    private var isApplyingCloudChanges = false
    private var periodicSyncTimer: Timer?
    private let syncInterval: TimeInterval = 3600 // 1 hour

    // Bidirectional lookups built from MenuData
    private var serviceIdToStable: [String: String] = [:]
    private var stableToServiceId: [String: String] = [:]
    private var sceneIdToName: [String: String] = [:]
    private var sceneNameToId: [String: String] = [:]
    private var roomIdToName: [String: String] = [:]
    private var roomNameToId: [String: String] = [:]

    private enum Keys {
        static let syncEnabled = "cloudSyncEnabled"
        static let lastSyncTimestamp = "cloudSyncLastTimestamp"
    }

    // Keys that store ID arrays needing translation
    private let serviceIdKeys = ["orderedFavouriteIds", "favouriteServiceIds", "hiddenServiceIds"]
    private let sceneIdKeys = ["favouriteSceneIds", "hiddenSceneIds"]
    private let roomIdKeys = ["hiddenRoomIds"]
    // Keys that store encoded data with embedded IDs
    private let encodedKeys = ["deviceGroups", "shortcuts"]

    private init() {}

    // MARK: - Menu data

    func updateMenuData(_ data: MenuData) {
        let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })

        serviceIdToStable.removeAll()
        stableToServiceId.removeAll()
        sceneIdToName.removeAll()
        sceneNameToId.removeAll()
        roomIdToName = roomLookup
        roomNameToId = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.name, $0.uniqueIdentifier) })

        for accessory in data.accessories {
            let roomName = accessory.roomIdentifier.flatMap { roomLookup[$0] } ?? "Unknown"
            for service in accessory.services {
                let stable = "\(roomName)::\(accessory.name)::\(service.name)"
                serviceIdToStable[service.uniqueIdentifier] = stable
                stableToServiceId[stable] = service.uniqueIdentifier
            }
        }

        for scene in data.scenes {
            sceneIdToName[scene.uniqueIdentifier] = scene.name
            sceneNameToId[scene.name] = scene.uniqueIdentifier
        }

        print("[CloudSync] updateMenuData — \(serviceIdToStable.count) services, \(sceneIdToName.count) scenes, \(roomIdToName.count) rooms")
    }

    // MARK: - Public API

    var isSyncEnabled: Bool {
        get { defaults.bool(forKey: Keys.syncEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.syncEnabled)
            if newValue && ProStatusCache.shared.isPro {
                startListening()
                uploadAllSyncableKeys()
            } else if !newValue {
                stopListening()
            }
            NotificationCenter.default.post(name: Self.syncStatusChangedNotification, object: nil)
        }
    }

    var lastSyncTimestamp: Date? {
        get { defaults.object(forKey: Keys.lastSyncTimestamp) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSyncTimestamp) }
    }

    func syncNow() {
        guard !isSyncing else {
            print("[CloudSync] syncNow — already syncing, skipping")
            return
        }
        print("[CloudSync] syncNow called — isPro: \(ProStatusCache.shared.isPro), isSyncEnabled: \(isSyncEnabled)")
        guard ProStatusCache.shared.isPro && isSyncEnabled else {
            print("[CloudSync] syncNow guard failed, aborting")
            return
        }
        guard !serviceIdToStable.isEmpty else {
            print("[CloudSync] syncNow — no menu data yet, aborting")
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        cloudStore.synchronize()
        pullFromCloudStore()
        uploadAllSyncableKeys()
        NotificationCenter.default.post(name: Self.syncStatusChangedNotification, object: nil)
    }

    func startListening() {
        print("[CloudSync] startListening called — isListening: \(isListening), isPro: \(ProStatusCache.shared.isPro), isSyncEnabled: \(isSyncEnabled)")
        guard !isListening else { return }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }

        isListening = true
        print("[CloudSync] now listening for changes")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalChange),
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )

        // Pull cloud changes on startup (don't upload — let handleLocalChange handle uploads)
        isSyncing = true
        cloudStore.synchronize()
        pullFromCloudStore()
        isSyncing = false

        // Start periodic sync
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.periodicSync()
        }
        print("[CloudSync] periodic sync scheduled every \(Int(syncInterval / 60)) minutes")
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil

        NotificationCenter.default.removeObserver(
            self,
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        NotificationCenter.default.removeObserver(
            self,
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )
    }

    // MARK: - Sync handlers

    @objc private func handleCloudChange(_ notification: Notification) {
        print("[CloudSync] handleCloudChange notification received")
        guard !isSyncing else {
            print("[CloudSync] handleCloudChange — already syncing, skipping")
            return
        }
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            print("[CloudSync] handleCloudChange — no userInfo or changeReason")
            return
        }

        print("[CloudSync] handleCloudChange — reason: \(changeReason) (server=0, initial=1, quota=2, accountChange=3)")

        guard changeReason == NSUbiquitousKeyValueStoreServerChange ||
              changeReason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            print("[CloudSync] handleCloudChange — ignoring reason \(changeReason)")
            return
        }

        isSyncing = true
        pullFromCloudStore()
        isSyncing = false
    }

    @objc private func handleLocalChange(_ notification: Notification) {
        guard !isApplyingCloudChanges && !isSyncing else {
            print("[CloudSync] handleLocalChange — skipping (applying cloud changes or syncing)")
            return
        }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }

        print("[CloudSync] handleLocalChange — uploading")
        uploadAllSyncableKeys()
    }

    private func periodicSync() {
        guard !isSyncing else { return }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }
        print("[CloudSync] periodic sync triggered")
        isSyncing = true
        cloudStore.synchronize()
        pullFromCloudStore()
        uploadAllSyncableKeys()
        isSyncing = false
    }

    // MARK: - Translation helpers

    private func translateIdsToStable(_ ids: [String], type: String) -> [String] {
        ids.compactMap { id in
            switch type {
            case "service":
                // orderedFavouriteIds can contain both service and scene IDs
                return serviceIdToStable[id] ?? sceneIdToName[id]
            case "scene":
                return sceneIdToName[id]
            case "room":
                return roomIdToName[id]
            default:
                return nil
            }
        }
    }

    private func translateStableToIds(_ names: [String], type: String) -> [String] {
        names.compactMap { name in
            switch type {
            case "service":
                // orderedFavouriteIds can contain both service and scene names
                return stableToServiceId[name] ?? sceneNameToId[name]
            case "scene":
                return sceneNameToId[name]
            case "room":
                return roomNameToId[name]
            default:
                return nil
            }
        }
    }

    private func translateDeviceGroupsToCloud(_ data: Data) -> Data? {
        guard let groups = try? JSONDecoder().decode([DeviceGroup].self, from: data) else { return nil }
        let translated = groups.map { group -> [String: Any] in
            let stableIds = group.deviceIds.compactMap { serviceIdToStable[$0] }
            return ["id": group.id, "name": group.name, "icon": group.icon, "deviceIds": stableIds]
        }
        return try? JSONSerialization.data(withJSONObject: translated)
    }

    private func translateDeviceGroupsFromCloud(_ data: Data) -> Data? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let groups = array.compactMap { dict -> DeviceGroup? in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let icon = dict["icon"] as? String,
                  let stableIds = dict["deviceIds"] as? [String] else { return nil }
            let localIds = stableIds.compactMap { stableToServiceId[$0] }
            return DeviceGroup(id: id, name: name, icon: icon, deviceIds: localIds)
        }
        return try? JSONEncoder().encode(groups)
    }

    private func translateShortcutsToCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: data) else { return nil }
        var translated: [String: PreferencesManager.ShortcutData] = [:]
        for (id, shortcut) in dict {
            if let stable = serviceIdToStable[id] ?? sceneIdToName[id] {
                translated[stable] = shortcut
            }
        }
        return try? JSONEncoder().encode(translated)
    }

    private func translateShortcutsFromCloud(_ data: Data) -> Data? {
        guard let dict = try? JSONDecoder().decode([String: PreferencesManager.ShortcutData].self, from: data) else { return nil }
        var translated: [String: PreferencesManager.ShortcutData] = [:]
        for (stable, shortcut) in dict {
            if let id = stableToServiceId[stable] ?? sceneNameToId[stable] {
                translated[id] = shortcut
            }
        }
        return try? JSONEncoder().encode(translated)
    }

    // MARK: - Pull

    private func pullFromCloudStore() {
        guard let homeId = PreferencesManager.shared.currentHomeId,
              let homeName = PreferencesManager.shared.currentHomeName else {
            print("[CloudSync] pullFromCloudStore — no currentHomeId/homeName, aborting")
            return
        }
        guard !serviceIdToStable.isEmpty else {
            print("[CloudSync] pullFromCloudStore — no menu data yet, aborting")
            return
        }

        print("[CloudSync] pullFromCloudStore — homeName: \(homeName)")
        isApplyingCloudChanges = true
        defer { isApplyingCloudChanges = false }

        var appliedCount = 0

        // Pull ID-based keys (service, scene, room)
        for prefix in serviceIdKeys {
            let type = prefix == "orderedFavouriteIds" ? "service" : "service"
            if pullIdKey(prefix: prefix, type: type, homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }
        for prefix in sceneIdKeys {
            if pullIdKey(prefix: prefix, type: "scene", homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }
        for prefix in roomIdKeys {
            if pullIdKey(prefix: prefix, type: "room", homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }

        // Pull encoded keys (deviceGroups, shortcuts)
        if pullEncodedKey(prefix: "deviceGroups", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }
        if pullEncodedKey(prefix: "shortcuts", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }

        if appliedCount > 0 {
            print("[CloudSync] pullFromCloudStore — applied \(appliedCount) keys")
            lastSyncTimestamp = Date()
            NotificationCenter.default.post(
                name: PreferencesManager.preferencesChangedNotification,
                object: nil
            )
        } else {
            print("[CloudSync] pullFromCloudStore — no new data from cloud")
        }
    }

    private func pullIdKey(prefix: String, type: String, homeName: String, homeId: String) -> Bool {
        let cloudKey = "\(prefix)_\(homeName)"
        let localKey = "\(prefix)_\(homeId)"

        guard let cloudNames = cloudStore.object(forKey: cloudKey) as? [String] else {
            print("[CloudSync]   no cloud data for \(cloudKey)")
            return false
        }

        let localIds = translateStableToIds(cloudNames, type: type)
        let currentIds = defaults.object(forKey: localKey) as? [String] ?? []

        if localIds != currentIds {
            defaults.set(localIds, forKey: localKey)
            print("[CloudSync]   pulled \(cloudKey) — \(cloudNames.count) names → \(localIds.count) local IDs")
            return true
        } else {
            print("[CloudSync]   unchanged \(cloudKey)")
            return false
        }
    }

    private func pullEncodedKey(prefix: String, homeName: String, homeId: String) -> Bool {
        let cloudKey = "\(prefix)_\(homeName)"
        let localKey = "\(prefix)_\(homeId)"

        guard let cloudData = cloudStore.object(forKey: cloudKey) as? Data else {
            print("[CloudSync]   no cloud data for \(cloudKey)")
            return false
        }

        let translatedData: Data?
        if prefix == "deviceGroups" {
            translatedData = translateDeviceGroupsFromCloud(cloudData)
        } else {
            translatedData = translateShortcutsFromCloud(cloudData)
        }

        guard let newData = translatedData else {
            print("[CloudSync]   failed to translate \(cloudKey)")
            return false
        }

        let currentData = defaults.data(forKey: localKey)
        if newData != currentData {
            defaults.set(newData, forKey: localKey)
            print("[CloudSync]   pulled \(cloudKey) (\(newData.count) bytes)")
            return true
        } else {
            print("[CloudSync]   unchanged \(cloudKey)")
            return false
        }
    }

    // MARK: - Upload

    private func uploadAllSyncableKeys() {
        guard let homeId = PreferencesManager.shared.currentHomeId,
              let homeName = PreferencesManager.shared.currentHomeName else {
            print("[CloudSync] uploadAllSyncableKeys — no currentHomeId/homeName, aborting")
            return
        }
        guard !serviceIdToStable.isEmpty else {
            print("[CloudSync] uploadAllSyncableKeys — no menu data yet, aborting")
            return
        }

        print("[CloudSync] uploadAllSyncableKeys — homeName: \(homeName)")

        // Upload ID-based keys
        for prefix in serviceIdKeys {
            uploadIdKey(prefix: prefix, type: "service", homeName: homeName, homeId: homeId)
        }
        for prefix in sceneIdKeys {
            uploadIdKey(prefix: prefix, type: "scene", homeName: homeName, homeId: homeId)
        }
        for prefix in roomIdKeys {
            uploadIdKey(prefix: prefix, type: "room", homeName: homeName, homeId: homeId)
        }

        // Upload encoded keys
        uploadEncodedKey(prefix: "deviceGroups", homeName: homeName, homeId: homeId)
        uploadEncodedKey(prefix: "shortcuts", homeName: homeName, homeId: homeId)

        let syncResult = cloudStore.synchronize()
        print("[CloudSync] uploadAllSyncableKeys synchronize() returned: \(syncResult)")
        lastSyncTimestamp = Date()
    }

    private func uploadIdKey(prefix: String, type: String, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        guard let ids = defaults.object(forKey: localKey) as? [String], !ids.isEmpty else {
            return
        }

        let stableNames = translateIdsToStable(ids, type: type)
        guard !stableNames.isEmpty else { return }
        cloudStore.set(stableNames, forKey: cloudKey)
        print("[CloudSync]   upload \(cloudKey) — \(ids.count) IDs → \(stableNames.count) names")
    }

    private func uploadEncodedKey(prefix: String, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        guard let data = defaults.data(forKey: localKey) else {
            print("[CloudSync]   skip \(localKey) (nil)")
            return
        }

        let translatedData: Data?
        if prefix == "deviceGroups" {
            translatedData = translateDeviceGroupsToCloud(data)
        } else {
            translatedData = translateShortcutsToCloud(data)
        }

        if let cloudData = translatedData {
            cloudStore.set(cloudData, forKey: cloudKey)
            print("[CloudSync]   upload \(cloudKey) (\(cloudData.count) bytes)")
        } else {
            print("[CloudSync]   failed to translate \(localKey)")
        }
    }

}
