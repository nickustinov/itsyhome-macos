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
    private var isApplyingCloudChanges = false

    private enum Keys {
        static let syncEnabled = "cloudSyncEnabled"
        static let lastSyncTimestamp = "cloudSyncLastTimestamp"
    }

    // Keys that should be synced (per-home, will be suffixed with homeId)
    private let syncableKeyPrefixes = [
        "orderedFavouriteIds",
        "favouriteSceneIds",
        "favouriteServiceIds",
        "hiddenSceneIds",
        "hiddenServiceIds",
        "hiddenRoomIds",
        "deviceGroups",
        "shortcuts"
    ]

    private init() {}

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

        // Listen for external iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )

        // Listen for local preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalChange),
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )

        // Synchronize to get any pending changes
        cloudStore.synchronize()
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
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Only process server changes and initial sync downloads
        guard changeReason == NSUbiquitousKeyValueStoreServerChange ||
              changeReason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }

        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        applyCloudChanges(for: changedKeys)
    }

    @objc private func handleLocalChange(_ notification: Notification) {
        // Prevent feedback loop when applying cloud changes
        guard !isApplyingCloudChanges else { return }
        guard ProStatusCache.shared.isPro && isSyncEnabled else { return }

        uploadAllSyncableKeys()
    }

    // MARK: - Upload

    private func uploadAllSyncableKeys() {
        guard let homeId = PreferencesManager.shared.currentHomeId else { return }

        for prefix in syncableKeyPrefixes {
            let key = "\(prefix)_\(homeId)"
            if let value = defaults.object(forKey: key) {
                cloudStore.set(value, forKey: key)
            }
        }

        cloudStore.synchronize()
        lastSyncTimestamp = Date()
    }

    // MARK: - Download

    private func applyCloudChanges(for changedKeys: [String]) {
        isApplyingCloudChanges = true
        defer { isApplyingCloudChanges = false }

        for key in changedKeys {
            // Only sync keys that match our syncable prefixes
            guard syncableKeyPrefixes.contains(where: { key.hasPrefix($0) }) else {
                continue
            }

            if let value = cloudStore.object(forKey: key) {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        lastSyncTimestamp = Date()

        // Notify that preferences changed from cloud
        NotificationCenter.default.post(
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )
    }
}
