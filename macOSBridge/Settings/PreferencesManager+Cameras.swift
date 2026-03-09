//
//  PreferencesManager+Cameras.swift
//  macOSBridge
//
//  Camera-specific preferences (overlays)
//

import Foundation

extension PreferencesManager {

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

    // MARK: - Motion-triggered camera open (per-home)

    private static let motionOpenCameraIdsKey = "motionOpenCameraIds"

    /// Set of camera IDs that should auto-open on motion
    var motionOpenCameraIds: Set<String> {
        get {
            let array = defaults.stringArray(forKey: homeKey(Self.motionOpenCameraIdsKey)) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: homeKey(Self.motionOpenCameraIdsKey))
            postNotification()
        }
    }

    func isMotionOpenEnabled(for cameraId: String) -> Bool {
        motionOpenCameraIds.contains(cameraId)
    }

    func toggleMotionOpen(for cameraId: String) {
        var ids = motionOpenCameraIds
        if ids.contains(cameraId) {
            ids.remove(cameraId)
        } else {
            ids.insert(cameraId)
        }
        motionOpenCameraIds = ids
    }

    /// Whether any camera has motion-open enabled
    var hasAnyMotionOpenEnabled: Bool {
        !motionOpenCameraIds.isEmpty
    }
}
