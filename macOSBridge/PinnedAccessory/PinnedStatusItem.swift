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
    let menu = StayOpenMenu()
    var menuItems: [NSMenuItem] = []

    // Cached values for status display
    var cachedValues: [UUID: Any] = [:]

    // MARK: - Initialization

    init(itemId: String, itemName: String, itemType: PinnedItemType) {
        self.itemId = itemId
        self.itemName = itemName
        self.itemType = itemType
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.autosaveName = "com.itsyhome.pinned.\(itemId)"

        super.init()

        setupButton()
        setupMenu()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    func setupButton() {
        guard let button = statusItem.button else { return }

        let showName = PreferencesManager.shared.pinnedItemShowsName(itemId: itemId)

        var icon: NSImage?
        var statusText: String?

        switch itemType {
        case .service(let service):
            // Check if this service type should show status instead of icon
            let (displayIcon, displayText) = statusDisplay(for: service)
            icon = displayIcon
            statusText = displayText

        case .room(let roomData, _):
            icon = IconResolver.icon(forRoomId: roomData.uniqueIdentifier, roomName: itemName)

        case .scene:
            icon = IconResolver.icon(forSceneId: itemId, sceneName: itemName)

        case .scenesSection:
            icon = PhosphorIcon.regular("sparkle")

        case .group:
            icon = IconResolver.icon(forGroupId: itemId)
        }

        // Resize icon for menu bar (18x18 is standard)
        if let icon = icon {
            icon.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.image?.isTemplate = true
        }

        // Determine what to show in the title
        if let statusText = statusText {
            // Show status text (e.g., "21°") with optional name - icon first, then name
            button.imagePosition = .imageLeading
            button.title = showName ? "\(itemName) \(statusText)" : statusText
        } else if showName {
            button.imagePosition = .imageLeading
            button.title = itemName
        } else {
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    private func setupMenu() {
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Call after setting delegate to load initial cached values and refresh display
    func loadInitialValues() {
        guard case .service(let service) = itemType else { return }

        // Get characteristic IDs that affect display
        let displayIds: [String?] = [
            service.powerStateId,  // For lights, switches, outlets on/off state
            service.activeId,  // For heater/cooler, fans, valves on/off state
            service.currentTemperatureId,
            service.targetHeaterCoolerStateId,
            service.targetHeatingCoolingStateId,
            service.targetHumidifierDehumidifierStateId,  // For humidifier mode
            service.humidityId,
            service.currentPositionId,
            service.lockCurrentStateId,
            service.currentDoorStateId,
            service.securitySystemCurrentStateId
        ]

        // Load cached values from delegate
        var hasValues = false
        for idString in displayIds.compactMap({ $0 }) {
            guard let charId = UUID(uuidString: idString) else { continue }
            if let value = delegate?.pinnedStatusItem(self, getCachedValue: charId) {
                cachedValues[charId] = value
                hasValues = true
            }
        }

        // Refresh button if we loaded any values
        if hasValues {
            setupButton()
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Close all other pinned panels when this menu opens
        NotificationCenter.default.post(name: Self.closeAllPanelsNotification, object: self)

        rebuildMenu()
    }

    // MARK: - Notifications

    static let closeAllPanelsNotification = Notification.Name("PinnedStatusItemCloseAllPanels")
}
