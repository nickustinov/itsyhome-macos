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
            // Add groups that belong to this room first
            if ProStatusCache.shared.isPro {
                let preferences = PreferencesManager.shared
                let roomGroups = preferences.deviceGroups.filter { $0.roomId == room.uniqueIdentifier }
                let savedOrder = preferences.groupOrder(forRoom: room.uniqueIdentifier)
                let orderedGroups = roomGroups.sorted { g1, g2 in
                    let i1 = savedOrder.firstIndex(of: g1.id) ?? Int.max
                    let i2 = savedOrder.firstIndex(of: g2.id) ?? Int.max
                    return i1 < i2
                }
                for group in orderedGroups {
                    let item = GroupMenuItem(group: group, menuData: menuData, bridge: builder.bridge)
                    menu.addItem(item)
                    menuItems.append(item)
                }
                if !orderedGroups.isEmpty && !services.isEmpty {
                    menu.addItem(NSMenuItem.separator())
                }
            }
            // Add all services in the room
            builder.addServicesGroupedByType(to: menu, accessories: servicesAsAccessories(services))
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
            // Add group menu item with toggle at the top
            let groupItem = GroupMenuItem(group: group, menuData: menuData, bridge: builder.bridge)
            menu.addItem(groupItem)
            menuItems.append(groupItem)

            // Add separator
            menu.addItem(NSMenuItem.separator())

            // Add individual accessories from the group
            builder.addServicesGroupedByType(to: menu, accessories: servicesAsAccessories(services))
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
            title: "Show name in menu bar",
            action: #selector(toggleShowName(_:)),
            keyEquivalent: ""
        )
        showNameItem.target = self
        showNameItem.state = showName ? .on : .off
        menu.addItem(showNameItem)

        let unpinItem = NSMenuItem(
            title: "Unpin from menu bar",
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
