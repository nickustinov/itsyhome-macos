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
    private let sceneIdKeys = ["favouriteSceneIds", "hiddenSceneIds", "sceneOrder"]
    private let roomIdKeys = ["hiddenRoomIds", "roomOrder"]
    private let cameraIdKeys = ["hiddenCameraIds", "cameraOrder"]

    private init() {}

    // MARK: - Menu data

    func updateMenuData(_ data: MenuData) {
        translator.updateMenuData(data)
        translator.updateGroupIds(Set(PreferencesManager.shared.deviceGroups.map { $0.id }))
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

    func startListening() {
        guard !isListening else {
            print("[CloudSync] startListening: already listening")
            return
        }
        guard ProStatusCache.shared.isPro && isSyncEnabled else {
            print("[CloudSync] startListening: skipped (isPro=\(ProStatusCache.shared.isPro), syncEnabled=\(isSyncEnabled))")
            return
        }

        print("[CloudSync] startListening: starting...")
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
        print("[CloudSync] startListening: pulling cloud changes...")
        isSyncing = true
        cloudStore.synchronize()
        pullFromCloudStore()
        isSyncing = false
        print("[CloudSync] startListening: complete")
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
        print("[CloudSync] handleCloudChange: received notification")
        guard !isSyncing else {
            print("[CloudSync] handleCloudChange: skipped (already syncing)")
            return
        }
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            print("[CloudSync] handleCloudChange: skipped (no change reason)")
            return
        }

        let reasonName: String
        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange: reasonName = "ServerChange"
        case NSUbiquitousKeyValueStoreInitialSyncChange: reasonName = "InitialSyncChange"
        case NSUbiquitousKeyValueStoreQuotaViolationChange: reasonName = "QuotaViolation"
        case NSUbiquitousKeyValueStoreAccountChange: reasonName = "AccountChange"
        default: reasonName = "Unknown(\(changeReason))"
        }
        print("[CloudSync] handleCloudChange: reason=\(reasonName)")

        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            print("[CloudSync] handleCloudChange: changedKeys=\(changedKeys)")
        }

        guard changeReason == NSUbiquitousKeyValueStoreServerChange ||
              changeReason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            print("[CloudSync] handleCloudChange: skipped (reason not relevant)")
            return
        }

        isSyncing = true
        pullFromCloudStore()
        isSyncing = false
        print("[CloudSync] handleCloudChange: complete")
    }

    @objc private func handleLocalChange(_ notification: Notification) {
        guard !isApplyingCloudChanges && !isSyncing else {
            print("[CloudSync] handleLocalChange: skipped (applyingCloud=\(isApplyingCloudChanges), syncing=\(isSyncing))")
            return
        }
        guard ProStatusCache.shared.isPro && isSyncEnabled else {
            print("[CloudSync] handleLocalChange: skipped (isPro=\(ProStatusCache.shared.isPro), syncEnabled=\(isSyncEnabled))")
            return
        }
        print("[CloudSync] handleLocalChange: uploading all syncable keys...")
        uploadAllSyncableKeys()
    }

    // MARK: - Pull

    private func pullFromCloudStore() {
        print("[CloudSync] pullFromCloudStore: starting...")
        guard let homeId = PreferencesManager.shared.currentHomeId,
              let homeName = PreferencesManager.shared.currentHomeName else {
            print("[CloudSync] pullFromCloudStore: skipped (no homeId/homeName)")
            return
        }
        print("[CloudSync] pullFromCloudStore: homeId=\(homeId), homeName=\(homeName)")
        guard translator.hasData else {
            print("[CloudSync] pullFromCloudStore: skipped (translator has no data)")
            return
        }

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
        for prefix in cameraIdKeys {
            if pullIdKey(prefix: prefix, type: .camera, homeName: homeName, homeId: homeId) {
                appliedCount += 1
            }
        }

        if pullEncodedKey(prefix: "cameraOverlayAccessories", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }
        if pullEncodedKey(prefix: "deviceGroups", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }
        if pullEncodedKey(prefix: "shortcuts", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }

        print("[CloudSync] pullFromCloudStore: appliedCount=\(appliedCount)")
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
            print("[CloudSync] pullIdKey(\(prefix)): no cloud data for key '\(cloudKey)'")
            return false
        }

        print("[CloudSync] pullIdKey(\(prefix)): cloudNames=\(cloudNames)")
        let localIds = translator.translateStableToIds(cloudNames, type: type)
        let currentIds = defaults.object(forKey: localKey) as? [String] ?? []
        print("[CloudSync] pullIdKey(\(prefix)): translatedIds=\(localIds), currentIds=\(currentIds)")

        if localIds != currentIds {
            print("[CloudSync] pullIdKey(\(prefix)): APPLYING change to '\(localKey)'")
            defaults.set(localIds, forKey: localKey)
            return true
        }
        print("[CloudSync] pullIdKey(\(prefix)): no change needed")
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
        } else if prefix == "cameraOverlayAccessories" {
            translatedData = translator.translateCameraOverlaysFromCloud(cloudData)
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
            print("[CloudSync] uploadAllSyncableKeys: skipped (no homeId/homeName)")
            return
        }
        guard translator.hasData else {
            print("[CloudSync] uploadAllSyncableKeys: skipped (translator has no data)")
            return
        }
        print("[CloudSync] uploadAllSyncableKeys: starting for home '\(homeName)'...")

        for prefix in serviceIdKeys {
            uploadIdKey(prefix: prefix, type: .service, homeName: homeName, homeId: homeId)
        }
        for prefix in sceneIdKeys {
            uploadIdKey(prefix: prefix, type: .scene, homeName: homeName, homeId: homeId)
        }
        for prefix in roomIdKeys {
            uploadIdKey(prefix: prefix, type: .room, homeName: homeName, homeId: homeId)
        }
        for prefix in cameraIdKeys {
            uploadIdKey(prefix: prefix, type: .camera, homeName: homeName, homeId: homeId)
        }

        uploadEncodedKey(prefix: "cameraOverlayAccessories", homeName: homeName, homeId: homeId)
        uploadEncodedKey(prefix: "deviceGroups", homeName: homeName, homeId: homeId)
        uploadEncodedKey(prefix: "shortcuts", homeName: homeName, homeId: homeId)

        let syncResult = cloudStore.synchronize()
        print("[CloudSync] uploadAllSyncableKeys: synchronize returned \(syncResult)")
        lastSyncTimestamp = Date()
    }

    private func uploadIdKey(prefix: String, type: CloudSyncTranslator.IdType, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        let ids = defaults.object(forKey: localKey) as? [String] ?? []

        // If local array is empty, remove from cloud to prevent stale data from overwriting
        if ids.isEmpty {
            print("[CloudSync] uploadIdKey(\(prefix)): local is empty, removing '\(cloudKey)' from cloud")
            cloudStore.removeObject(forKey: cloudKey)
            return
        }

        print("[CloudSync] uploadIdKey(\(prefix)): localIds=\(ids)")
        let stableNames = translator.translateIdsToStable(ids, type: type)
        print("[CloudSync] uploadIdKey(\(prefix)): stableNames=\(stableNames)")
        guard !stableNames.isEmpty else {
            print("[CloudSync] uploadIdKey(\(prefix)): skipped (no stable names)")
            return
        }
        cloudStore.set(stableNames, forKey: cloudKey)
        print("[CloudSync] uploadIdKey(\(prefix)): uploaded to '\(cloudKey)'")
    }

    private func uploadEncodedKey(prefix: String, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        guard let data = defaults.data(forKey: localKey) else { return }

        let translatedData: Data?
        if prefix == "deviceGroups" {
            translatedData = translator.translateDeviceGroupsToCloud(data)
        } else if prefix == "cameraOverlayAccessories" {
            translatedData = translator.translateCameraOverlaysToCloud(data)
        } else {
            translatedData = translator.translateShortcutsToCloud(data)
        }

        if let cloudData = translatedData {
            cloudStore.set(cloudData, forKey: cloudKey)
        }
    }

}
