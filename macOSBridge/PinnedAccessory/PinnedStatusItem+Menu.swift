//
//  PinnedStatusItem+Menu.swift
//  macOSBridge
//
//  Menu building and handling for pinned status items
//

import AppKit

extension PinnedStatusItem {

    // MARK: - Menu building

    func rebuildMenu() {
        menu.removeAllItems()
        menuItems.removeAll()

        guard let builder = delegate?.pinnedStatusItemNeedsMenuBuilder(self),
              let menuData = delegate?.pinnedStatusItemNeedsMenuData(self) else {
            return
        }

        switch itemType {
        case .service(let service):
            // Add the service's menu item
            if let item = builder.createMenuItemForService(service) {
                menu.addItem(item)
                menuItems.append(item)

                // Update reachability
                if let reachabilityItem = item as? ReachabilityUpdatable {
                    reachabilityItem.setReachable(service.isReachable)
                }
            }

        case .room(let room, let services):
            // Same layout as the room's submenu in the main menu: groups and
            // services in the user's saved order (groups on top by default).
            var roomGroups: [DeviceGroup] = []
            if ProStatusCache.shared.isPro {
                let preferences = PreferencesManager.shared
                let savedOrder = preferences.groupOrder(forRoom: room.uniqueIdentifier)
                roomGroups = preferences.deviceGroups
                    .filter { $0.roomId == room.uniqueIdentifier }
                    .sorted { g1, g2 in
                        let i1 = savedOrder.firstIndex(of: g1.id) ?? Int.max
                        let i2 = savedOrder.firstIndex(of: g2.id) ?? Int.max
                        return i1 < i2
                    }
            }
            builder.addServicesGroupedByType(
                to: menu,
                accessories: servicesAsAccessories(services),
                roomId: room.uniqueIdentifier,
                groups: roomGroups
            )
            collectMenuItems(from: menu)

        case .scene(let scene):
            // Add the scene menu item
            let item = SceneMenuItem(sceneData: scene, bridge: builder.bridge)
            menu.addItem(item)
            menuItems.append(item)

        case .scenesSection(let scenes):
            // Add all scenes
            for scene in scenes {
                let item = SceneMenuItem(sceneData: scene, bridge: builder.bridge)
                menu.addItem(item)
                menuItems.append(item)
            }

        case .group(let group, let services):
            if group.showGroupSwitch {
                // Add group menu item with toggle at the top
                let groupItem = GroupMenuItem(group: group, menuData: menuData, bridge: builder.bridge)
                menu.addItem(groupItem)

                // Add separator
                menu.addItem(NSMenuItem.separator())
            }

            // Individual accessories in the group's deviceIds order (the one
            // set by dragging in Settings → Home), not grouped by type.
            for service in services {
                if let item = builder.createMenuItemForService(service) {
                    menu.addItem(item)
                }
            }
            collectMenuItems(from: menu)
        }

        // Add separator and settings
        menu.addItem(NSMenuItem.separator())
        addSettingsItems()

        // Apply cached values immediately for smooth initial display
        applyCachedValues()

        // Request fresh values from HomeKit (will update if different from cached)
        refreshCharacteristics()
    }

    func collectMenuItems(from menu: NSMenu) {
        for item in menu.items {
            if item is CharacteristicRefreshable {
                menuItems.append(item)
            }
            if let submenu = item.submenu {
                collectMenuItems(from: submenu)
            }
        }
    }

    func applyCachedValues() {
        // Apply cached values to menu items immediately for a smooth initial display
        for item in menuItems {
            if let refreshable = item as? CharacteristicRefreshable,
               let updatable = item as? CharacteristicUpdatable {
                for charId in refreshable.characteristicIdentifiers {
                    if let value = delegate?.pinnedStatusItem(self, getCachedValue: charId) {
                        updatable.updateValue(for: charId, value: value, isLocalChange: false)
                    }
                }
            }
        }
    }

    func refreshCharacteristics() {
        for item in menuItems {
            if let refreshable = item as? CharacteristicRefreshable {
                for charId in refreshable.characteristicIdentifiers {
                    delegate?.pinnedStatusItem(self, readCharacteristic: charId)
                }
            }
        }
    }

    func servicesAsAccessories(_ services: [ServiceData]) -> [AccessoryData] {
        // Wrap services as AccessoryData for the menu builder
        services.map { service in
            AccessoryData(
                uniqueIdentifier: service.uniqueIdentifier,
                name: service.accessoryName,
                roomIdentifier: service.roomIdentifier,
                services: [service],
                isReachable: service.isReachable
            )
        }
    }

    func addSettingsItems() {
        let showName = PreferencesManager.shared.pinnedItemShowsName(itemId: itemId)

        let showNameItem = NSMenuItem(
            title: String(localized: "pinned.show_name", defaultValue: "Show name in menu bar", bundle: .macOSBridge),
            action: #selector(toggleShowName(_:)),
            keyEquivalent: ""
        )
        showNameItem.target = self
        showNameItem.state = showName ? .on : .off
        menu.addItem(showNameItem)

        let unpinItem = NSMenuItem(
            title: String(localized: "pinned.unpin", defaultValue: "Unpin from menu bar", bundle: .macOSBridge),
            action: #selector(unpinItem(_:)),
            keyEquivalent: ""
        )
        unpinItem.target = self
        menu.addItem(unpinItem)
    }

    // MARK: - Actions

    @objc func toggleShowName(_ sender: NSMenuItem) {
        let current = PreferencesManager.shared.pinnedItemShowsName(itemId: itemId)
        PreferencesManager.shared.setPinnedItemShowsName(!current, itemId: itemId)
        setupButton()
    }

    @objc func unpinItem(_ sender: NSMenuItem) {
        menu.cancelTracking()
        PreferencesManager.shared.togglePinned(itemId: itemId)
    }
}
