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
}
