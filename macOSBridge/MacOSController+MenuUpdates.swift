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
        // Pinned status items (visible in the menu bar), SSE clients, and the
        // automation engine always need live updates, regardless of whether the
        // dropdown is open: the engine evaluates state-duration triggers (e.g.
        // "door open for 15 min") continuously, not just while the menu is open.
        updatePinnedStatusItems(for: characteristicId, value: value)
        WebhookServer.shared.publishCharacteristicChange(characteristicId: characteristicId, value: value)
        AutomationEngine.shared.handleCharacteristicChange(id: characteristicId, value: value)

        // History capture must see every change, even while the dropdown is
        // closed, so it sits above the menu-closed guard alongside pinned/SSE.
        HistoryStore.shared.record(id: characteristicId, value: value)

        // The dropdown's rows aren't visible while it's closed, and menuWillOpen
        // re-reads every characteristic via refreshCharacteristics(), so skip the
        // recursive menu/scene walk when idle. This avoids constant main-thread
        // work from chatty bridges that kept the app awake and drained battery
        // (#113). Local changes happen with the menu open, so they still apply.
        guard menuIsOpen || isLocalChange else { return }

        if let refs = updatableItemIndex[characteristicId] {
            for ref in refs {
                (ref.item as? CharacteristicUpdatable)?.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
            }
        }
        for ref in unindexedUpdatableItems {
            (ref.item as? CharacteristicUpdatable)?.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
        }

        for sceneItem in menuBuilder.sceneMenuItems {
            sceneItem.updateValue(for: characteristicId, value: value, isLocalChange: isLocalChange)
        }
    }

    /// Rebuilds the characteristic-to-menu-item routing index. Must run after
    /// every menu rebuild, before the first refresh.
    func rebuildUpdatableItemIndex() {
        updatableItemIndex.removeAll()
        unindexedUpdatableItems.removeAll()
        indexUpdatableItems(in: mainMenu)
    }

    private func indexUpdatableItems(in menu: NSMenu) {
        for item in menu.items {
            if item is CharacteristicUpdatable {
                let ref = WeakMenuItemRef(item: item)
                let ids = (item as? CharacteristicRefreshable)?.characteristicIdentifiers ?? []
                if ids.isEmpty {
                    unindexedUpdatableItems.append(ref)
                } else {
                    for id in ids {
                        updatableItemIndex[id, default: []].append(ref)
                    }
                }
            }
            if let submenu = item.submenu {
                indexUpdatableItems(in: submenu)
            }
        }
    }

    func updatePinnedStatusItems(for characteristicId: UUID, value: Any) {
        // Update all pinned status items that have this characteristic
        for (_, statusItem) in pinnedStatusItems {
            if statusItem.characteristicIdentifiers.contains(characteristicId) {
                statusItem.updateValue(for: characteristicId, value: value)
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
        // The same device can appear in several places (its room, favourites,
        // group and auto-group submenus) – read each characteristic once, not
        // once per row. Every row still updates: value changes fan out to all
        // menu items by characteristic id. Menu order is preserved so the
        // rows the user is looking at refresh first – reads drain roughly in
        // issue order, and a randomized order leaves the visible top of the
        // menu waiting behind everything else.
        var seen: Set<UUID> = []
        var ordered: [UUID] = []
        collectCharacteristicIdentifiers(in: mainMenu, seen: &seen, ordered: &ordered)
        for id in ordered {
            readCharacteristic(identifier: id)
        }
    }

    private func collectCharacteristicIdentifiers(in menu: NSMenu, seen: inout Set<UUID>, ordered: inout [UUID]) {
        for item in menu.items {
            if let refreshable = item as? CharacteristicRefreshable {
                for id in refreshable.characteristicIdentifiers where seen.insert(id).inserted {
                    ordered.append(id)
                }
            }
            if let submenu = item.submenu {
                collectCharacteristicIdentifiers(in: submenu, seen: &seen, ordered: &ordered)
            }
        }
    }
}
