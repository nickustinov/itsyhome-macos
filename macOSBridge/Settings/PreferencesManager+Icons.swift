//
//  PreferencesManager+Icons.swift
//  macOSBridge
//
//  Custom icon overrides management
//

import Foundation

extension PreferencesManager {

    // MARK: - Custom icons (per-home)

    /// Dictionary mapping item IDs (services, scenes, groups) to custom icon names
    var customIcons: [String: String] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.customIcons)),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.customIcons))
                postNotification()
            }
        }
    }

    func customIcon(for itemId: String) -> String? {
        customIcons[itemId]
    }

    func setCustomIcon(_ iconName: String?, for itemId: String) {
        var icons = customIcons
        if let iconName = iconName {
            icons[itemId] = iconName
        } else {
            icons.removeValue(forKey: itemId)
        }
        customIcons = icons
    }
}
