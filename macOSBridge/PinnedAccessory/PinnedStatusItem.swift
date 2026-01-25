//
//  PinnedStatusItem.swift
//  macOSBridge
//
//  Pinned status item for accessories and rooms in the menu bar.
//  Uses standard NSMenu with embedded existing menu items.
//

import AppKit

// MARK: - Protocols

protocol PinnedStatusItemDelegate: AnyObject {
    func pinnedStatusItemNeedsMenuBuilder(_ item: PinnedStatusItem) -> MenuBuilder?
    func pinnedStatusItemNeedsMenuData(_ item: PinnedStatusItem) -> MenuData?
    func pinnedStatusItem(_ item: PinnedStatusItem, readCharacteristic characteristicId: UUID)
    func pinnedStatusItem(_ item: PinnedStatusItem, getCachedValue characteristicId: UUID) -> Any?
}

// MARK: - Pinned item type

enum PinnedItemType {
    case service(ServiceData)
    case room(RoomData, [ServiceData])
    case scene(SceneData)
    case scenesSection([SceneData])
    case group(DeviceGroup, [ServiceData])
}

// MARK: - PinnedStatusItem

class PinnedStatusItem: NSObject, NSMenuDelegate {

    let itemId: String
    let itemName: String
    let itemType: PinnedItemType

    weak var delegate: PinnedStatusItemDelegate?

    private(set) var statusItem: NSStatusItem
    private let menu = StayOpenMenu()
    private var menuItems: [NSMenuItem] = []

    // MARK: - Initialization

    init(itemId: String, itemName: String, itemType: PinnedItemType) {
        self.itemId = itemId
        self.itemName = itemName
        self.itemType = itemType
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupButton()
        setupMenu()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }

        let showName = PreferencesManager.shared.pinnedItemShowsName(itemId: itemId)

        let icon: NSImage?
        switch itemType {
        case .service(let service):
            icon = IconMapping.iconForServiceType(service.serviceType)

        case .room:
            icon = IconMapping.iconForRoom(itemName)

        case .scene:
            icon = SceneIconInference.icon(for: itemName)

        case .scenesSection:
            icon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)

        case .group:
            icon = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        }

        button.image = icon
        button.image?.isTemplate = true
        button.imagePosition = showName ? .imageLeading : .imageOnly
        button.title = showName ? itemName : ""
    }

    private func setupMenu() {
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Menu building

    func menuWillOpen(_ menu: NSMenu) {
        // Close all other pinned panels when this menu opens
        NotificationCenter.default.post(name: Self.closeAllPanelsNotification, object: self)

        rebuildMenu()
    }

    private func rebuildMenu() {
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

        case .group(let group, _):
            // Add group menu item with all its services
            let item = GroupMenuItem(group: group, menuData: menuData, bridge: builder.bridge)
            menu.addItem(item)
            menuItems.append(item)
        }

        // Add separator and settings
        menu.addItem(NSMenuItem.separator())
        addSettingsItems()

        // Apply cached values immediately for smooth initial display
        applyCachedValues()

        // Request fresh values from HomeKit (will update if different from cached)
        refreshCharacteristics()
    }

    private func collectMenuItems(from menu: NSMenu) {
        for item in menu.items {
            if item is CharacteristicRefreshable {
                menuItems.append(item)
            }
            if let submenu = item.submenu {
                collectMenuItems(from: submenu)
            }
        }
    }

    private func applyCachedValues() {
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

    private func refreshCharacteristics() {
        for item in menuItems {
            if let refreshable = item as? CharacteristicRefreshable {
                for charId in refreshable.characteristicIdentifiers {
                    delegate?.pinnedStatusItem(self, readCharacteristic: charId)
                }
            }
        }
    }

    private func servicesAsAccessories(_ services: [ServiceData]) -> [AccessoryData] {
        // Wrap services as AccessoryData for the menu builder
        services.map { service in
            AccessoryData(
                uniqueIdentifier: UUID(uuidString: service.uniqueIdentifier)!,
                name: service.accessoryName,
                roomIdentifier: service.roomIdentifier.flatMap { UUID(uuidString: $0) },
                services: [service],
                isReachable: service.isReachable
            )
        }
    }

    private func addSettingsItems() {
        let showName = PreferencesManager.shared.pinnedItemShowsName(itemId: itemId)

        let showNameItem = NSMenuItem(
            title: "Show name in menu bar",
            action: #selector(toggleShowName(_:)),
            keyEquivalent: ""
        )
        showNameItem.target = self
        showNameItem.state = showName ? .on : .off
        menu.addItem(showNameItem)

        menu.addItem(NSMenuItem.separator())

        let unpinItem = NSMenuItem(
            title: "Unpin from menu bar",
            action: #selector(unpinItem(_:)),
            keyEquivalent: ""
        )
        unpinItem.target = self
        menu.addItem(unpinItem)
    }

    // MARK: - Actions

    @objc private func toggleShowName(_ sender: NSMenuItem) {
        let current = PreferencesManager.shared.pinnedItemShowsName(itemId: itemId)
        PreferencesManager.shared.setPinnedItemShowsName(!current, itemId: itemId)
        setupButton()
    }

    @objc private func unpinItem(_ sender: NSMenuItem) {
        menu.cancelTracking()
        PreferencesManager.shared.togglePinned(itemId: itemId)
    }

    // MARK: - Characteristic updates

    var characteristicIdentifiers: [UUID] {
        switch itemType {
        case .service(let service):
            return extractCharacteristicIds(from: service)
        case .room(_, let services):
            return services.flatMap { extractCharacteristicIds(from: $0) }
        case .scene, .scenesSection:
            return []  // Scenes don't have characteristics to monitor
        case .group(_, let services):
            return services.flatMap { extractCharacteristicIds(from: $0) }
        }
    }

    private func extractCharacteristicIds(from service: ServiceData) -> [UUID] {
        var ids: [UUID] = []
        if let id = service.powerStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.brightnessId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.hueId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.saturationId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.colorTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.currentTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.heatingCoolingStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetHeatingCoolingStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.activeId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetHeaterCoolerStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.coolingThresholdTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.heatingThresholdTemperatureId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.lockCurrentStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.lockTargetStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.currentPositionId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetPositionId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.rotationSpeedId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.currentDoorStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.targetDoorStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        return ids
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        // Update any menu items that track this characteristic
        for item in menuItems {
            if let refreshable = item as? CharacteristicRefreshable,
               refreshable.characteristicIdentifiers.contains(characteristicId),
               let updatable = item as? CharacteristicUpdatable {
                updatable.updateValue(for: characteristicId, value: value, isLocalChange: false)
            }
        }
    }

    // MARK: - Notifications

    static let closeAllPanelsNotification = Notification.Name("PinnedStatusItemCloseAllPanels")
}
