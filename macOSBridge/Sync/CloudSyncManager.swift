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
    private var translator = CloudSyncTranslator()

    private enum Keys {
        static let syncEnabled = "cloudSyncEnabled"
        static let lastSyncTimestamp = "cloudSyncLastTimestamp"
    }

    // Keys that store ID arrays needing translation
    private let serviceIdKeys = ["orderedFavouriteIds", "favouriteServiceIds", "hiddenServiceIds"]
    private let sceneIdKeys = ["favouriteSceneIds", "hiddenSceneIds"]
    private let roomIdKeys = ["hiddenRoomIds"]

    private init() {}

    // MARK: - Menu data

    func updateMenuData(_ data: MenuData) {
        translator.updateMenuData(data)
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
        guard !isSyncing else { return }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }
        guard translator.hasData else { return }
        isSyncing = true
        defer { isSyncing = false }
        cloudStore.synchronize()
        pullFromCloudStore()
        uploadAllSyncableKeys()
        NotificationCenter.default.post(name: Self.syncStatusChangedNotification, object: nil)
    }

    func startListening() {
        guard !isListening else { return }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }

        isListening = true

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
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false

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
        guard !isSyncing else { return }
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        guard changeReason == NSUbiquitousKeyValueStoreServerChange ||
              changeReason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }

        isSyncing = true
        pullFromCloudStore()
        isSyncing = false
    }

    @objc private func handleLocalChange(_ notification: Notification) {
        guard !isApplyingCloudChanges && !isSyncing else { return }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }
        uploadAllSyncableKeys()
    }

    // MARK: - Pull

    private func pullFromCloudStore() {
        guard let homeId = PreferencesManager.shared.currentHomeId,
              let homeName = PreferencesManager.shared.currentHomeName else {
            return
        }
        guard translator.hasData else { return }

        isApplyingCloudChanges = true
        defer { isApplyingCloudChanges = false }

        var appliedCount = 0

        for prefix in serviceIdKeys {
            if pullIdKey(prefix: prefix, type: .service, homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }
        for prefix in sceneIdKeys {
            if pullIdKey(prefix: prefix, type: .scene, homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }
        for prefix in roomIdKeys {
            if pullIdKey(prefix: prefix, type: .room, homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }

        if pullEncodedKey(prefix: "deviceGroups", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }
        if pullEncodedKey(prefix: "shortcuts", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }

        if appliedCount > 0 {
            lastSyncTimestamp = Date()
            NotificationCenter.default.post(
                name: PreferencesManager.preferencesChangedNotification,
                object: nil
            )
        }
    }

    private func pullIdKey(prefix: String, type: CloudSyncTranslator.IdType, homeName: String, homeId: String) -> Bool {
        let cloudKey = "\(prefix)_\(homeName)"
        let localKey = "\(prefix)_\(homeId)"

        guard let cloudNames = cloudStore.object(forKey: cloudKey) as? [String] else {
            return false
        }

        let localIds = translator.translateStableToIds(cloudNames, type: type)
        let currentIds = defaults.object(forKey: localKey) as? [String] ?? []

        if localIds != currentIds {
            defaults.set(localIds, forKey: localKey)
            return true
        }
        return false
    }

    private func pullEncodedKey(prefix: String, homeName: String, homeId: String) -> Bool {
        let cloudKey = "\(prefix)_\(homeName)"
        let localKey = "\(prefix)_\(homeId)"

        guard let cloudData = cloudStore.object(forKey: cloudKey) as? Data else {
            return false
        }

        let translatedData: Data?
        if prefix == "deviceGroups" {
            translatedData = translator.translateDeviceGroupsFromCloud(cloudData)
        } else {
            translatedData = translator.translateShortcutsFromCloud(cloudData)
        }

        guard let newData = translatedData else { return false }

        let currentData = defaults.data(forKey: localKey)
        if newData != currentData {
            defaults.set(newData, forKey: localKey)
            return true
        }
        return false
    }

    // MARK: - Upload

    private func uploadAllSyncableKeys() {
        guard let homeId = PreferencesManager.shared.currentHomeId,
              let homeName = PreferencesManager.shared.currentHomeName else {
            return
        }
        guard translator.hasData else { return }

        for prefix in serviceIdKeys {
            uploadIdKey(prefix: prefix, type: .service, homeName: homeName, homeId: homeId)
        }
        for prefix in sceneIdKeys {
            uploadIdKey(prefix: prefix, type: .scene, homeName: homeName, homeId: homeId)
        }
        for prefix in roomIdKeys {
            uploadIdKey(prefix: prefix, type: .room, homeName: homeName, homeId: homeId)
        }

        uploadEncodedKey(prefix: "deviceGroups", homeName: homeName, homeId: homeId)
        uploadEncodedKey(prefix: "shortcuts", homeName: homeName, homeId: homeId)

        cloudStore.synchronize()
        lastSyncTimestamp = Date()
    }

    private func uploadIdKey(prefix: String, type: CloudSyncTranslator.IdType, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        guard let ids = defaults.object(forKey: localKey) as? [String], !ids.isEmpty else {
            return
        }

        let stableNames = translator.translateIdsToStable(ids, type: type)
        guard !stableNames.isEmpty else { return }
        cloudStore.set(stableNames, forKey: cloudKey)
    }

    private func uploadEncodedKey(prefix: String, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        guard let data = defaults.data(forKey: localKey) else { return }

        let translatedData: Data?
        if prefix == "deviceGroups" {
            translatedData = translator.translateDeviceGroupsToCloud(data)
        } else {
            translatedData = translator.translateShortcutsToCloud(data)
        }

        if let cloudData = translatedData {
            cloudStore.set(cloudData, forKey: cloudKey)
        }
    }

}
