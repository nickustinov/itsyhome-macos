//
//  CloudSyncManager.swift
//  macOSBridge
//
//  Manages iCloud sync using NSUbiquitousKeyValueStore for Pro users
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "CloudSync")

final class CloudSyncManager {

    static let shared = CloudSyncManager()

    static let syncStatusChangedNotification = Notification.Name("CloudSyncManagerStatusChanged")

    private let defaults = UserDefaults.standard
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private var isListening = false
    private var isSyncing = false
    private var isApplyingCloudChanges = false
    private var translator = CloudSyncTranslator()

    /// Homes whose cloud state has been pulled this run. Uploads are held
    /// back until the home's initial pull has happened – otherwise a fresh
    /// install (empty local arrays) uploads first and deletes the cloud keys
    /// the other Mac pushed, before ever reading them.
    private var pulledHomeIds: Set<String> = []

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

        // The startup pull in startListening usually runs before HomeKit has
        // delivered any accessories (translator empty) and silently no-ops.
        // The arrival of menu data is the real "ready" signal – pull once per
        // home here, which also unblocks uploads for that home.
        guard isListening, ProStatusCache.shared.isPro, isSyncEnabled,
              let homeId = PreferencesManager.shared.currentHomeId,
              !pulledHomeIds.contains(homeId) else { return }
        logger.info("Menu data ready – running initial pull for current home")
        isSyncing = true
        cloudStore.synchronize()
        pullFromCloudStore()
        isSyncing = false
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
            logger.info("Pull skipped – no current home selected yet")
            return
        }
        guard translator.hasData else {
            logger.info("Pull skipped – accessory data not loaded yet")
            return
        }

        // The pull ran with real data: uploads for this home are safe now.
        pulledHomeIds.insert(homeId)

        isApplyingCloudChanges = true

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
        if pullEncodedKey(prefix: "customIcons", homeName: homeName, homeId: homeId) {
            appliedCount += 1
        }

        logger.info("Pull complete – applied \(appliedCount) key(s)")

        if appliedCount > 0 {
            lastSyncTimestamp = Date()
            DispatchQueue.main.async { [self] in
                NotificationCenter.default.post(
                    name: PreferencesManager.preferencesChangedNotification,
                    object: nil
                )
                isApplyingCloudChanges = false
            }
        } else {
            isApplyingCloudChanges = false
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
        } else if prefix == "cameraOverlayAccessories" {
            translatedData = translator.translateCameraOverlaysFromCloud(cloudData)
        } else if prefix == "customIcons" {
            translatedData = translator.translateCustomIconsFromCloud(cloudData)
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
            logger.info("Upload skipped – no current home selected yet")
            return
        }
        guard translator.hasData else {
            logger.info("Upload skipped – accessory data not loaded yet")
            return
        }
        // Never upload before this home's initial pull: a fresh install's
        // empty arrays would delete the cloud copies before reading them.
        guard pulledHomeIds.contains(homeId) else {
            logger.info("Upload skipped – waiting for initial pull of this home")
            return
        }

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
        uploadEncodedKey(prefix: "customIcons", homeName: homeName, homeId: homeId)

        cloudStore.synchronize()
        lastSyncTimestamp = Date()
        logger.info("Upload complete")
    }

    private func uploadIdKey(prefix: String, type: CloudSyncTranslator.IdType, homeName: String, homeId: String) {
        let localKey = "\(prefix)_\(homeId)"
        let cloudKey = "\(prefix)_\(homeName)"

        let ids = defaults.object(forKey: localKey) as? [String] ?? []

        // If local array is empty, remove from cloud to prevent stale data from overwriting
        if ids.isEmpty {
            cloudStore.removeObject(forKey: cloudKey)
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
        } else if prefix == "cameraOverlayAccessories" {
            translatedData = translator.translateCameraOverlaysToCloud(data)
        } else if prefix == "customIcons" {
            translatedData = translator.translateCustomIconsToCloud(data)
        } else {
            translatedData = translator.translateShortcutsToCloud(data)
        }

        if let cloudData = translatedData {
            cloudStore.set(cloudData, forKey: cloudKey)
        }
    }

}
