//
//  MacOSController+MenuUpdates.swift
//  macOSBridge
//
//  Menu item updates and characteristic refresh handling
//

import AppKit

extension MacOSController {

    // MARK: - Menu Updates

    func updateMenuItems(for characteristicId: UUID, value: Any, isLocalChange: Bool) {
        updateMenuItemsRecursively(in: mainMenu, characteristicId: characteristicId, value: value, isLocalChange: isLocalChange)

        for sceneItem in menuBuilder.sceneMenuItems {
            sceneItem.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
        }

        // Update pinned status items
        updatePinnedStatusItems(for: characteristicId, value: value)
    }

    func updatePinnedStatusItems(for characteristicId: UUID, value: Any) {
        // Update all pinned status items that have this characteristic
        for (_, statusItem) in pinnedStatusItems {
            if statusItem.characteristicIdentifiers.contains(characteristicId) {
                statusItem.updateValue(for: characteristicId, value: value)
            }
        }
    }

    func updateMenuItemsRecursively(in menu: NSMenu, characteristicId: UUID, value: Any, isLocalChange: Bool) {
        for item in menu.items {
            if let updatable = item as? CharacteristicUpdatable {
                updatable.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
            }
            if let submenu = item.submenu {
                updateMenuItemsRecursively(in: submenu, characteristicId: characteristicId, value: value, isLocalChange: isLocalChange)
            }
        }
    }

    func updateAccessoryReachability(_ accessoryId: UUID, isReachable: Bool) {
        guard let menuData = currentMenuData,
              let accessory = menuData.accessories.first(where: { $0.uniqueIdentifier == accessoryId.uuidString }) else {
            return
        }

        let serviceIds = Set(accessory.services.compactMap { UUID(uuidString: $0.uniqueIdentifier) })
        updateReachabilityRecursively(in: mainMenu, serviceIds: serviceIds, isReachable: isReachable)
    }

    func updateReachabilityRecursively(in menu: NSMenu, serviceIds: Set<UUID>, isReachable: Bool) {
        for item in menu.items {
            if let reachabilityItem = item as? ReachabilityUpdatable,
               let id = reachabilityItem.serviceIdentifier,
               serviceIds.contains(id) {
                reachabilityItem.setReachable(isReachable)
            }
            if let submenu = item.submenu {
                updateReachabilityRecursively(in: submenu, serviceIds: serviceIds, isReachable: isReachable)
            }
        }
    }

    // MARK: - Characteristic Refresh

    func refreshCharacteristics() {
        refreshCharacteristicsRecursively(in: mainMenu)
    }

    func refreshCharacteristicsRecursively(in menu: NSMenu) {
        for item in menu.items {
            if let refreshable = item as? CharacteristicRefreshable {
                for id in refreshable.characteristicIdentifiers {
                    readCharacteristic(identifier: id)
                }
            }
            if let submenu = item.submenu {
                refreshCharacteristicsRecursively(in: submenu)
            }
        }
    }
}
