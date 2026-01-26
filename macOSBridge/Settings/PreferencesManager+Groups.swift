//
//  PreferencesManager+Groups.swift
//  macOSBridge
//
//  Device groups management
//

import Foundation

extension PreferencesManager {

    // MARK: - Device Groups (per-home)

    var deviceGroups: [DeviceGroup] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.deviceGroups)),
                  let groups = try? JSONDecoder().decode([DeviceGroup].self, from: data) else {
                return []
            }
            return groups
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.deviceGroups))
                postNotification()
            }
        }
    }

    func deviceGroup(id: String) -> DeviceGroup? {
        deviceGroups.first { $0.id == id }
    }

    func addDeviceGroup(_ group: DeviceGroup) {
        var groups = deviceGroups
        groups.append(group)
        deviceGroups = groups
    }

    func updateDeviceGroup(_ group: DeviceGroup) {
        var groups = deviceGroups
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            deviceGroups = groups
        }
    }

    func deleteDeviceGroup(id: String) {
        var groups = deviceGroups
        groups.removeAll { $0.id == id }
        deviceGroups = groups
        removeShortcut(for: id)
    }

    func moveDeviceGroup(from sourceIndex: Int, to destinationIndex: Int) {
        var groups = deviceGroups
        guard sourceIndex >= 0, sourceIndex < groups.count,
              destinationIndex >= 0, destinationIndex < groups.count else { return }
        let group = groups.remove(at: sourceIndex)
        groups.insert(group, at: destinationIndex)
        deviceGroups = groups
    }
}
