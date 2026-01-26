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

    // Cached values for status display
    private var cachedValues: [UUID: Any] = [:]

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

        var icon: NSImage?
        var statusText: String?

        switch itemType {
        case .service(let service):
            // Check if this service type should show status instead of icon
            let (displayIcon, displayText) = statusDisplay(for: service)
            icon = displayIcon
            statusText = displayText

        case .room:
            icon = IconMapping.iconForRoom(itemName)

        case .scene:
            icon = SceneIconInference.icon(for: itemName)

        case .scenesSection:
            icon = PhosphorIcon.regular("sparkle")

        case .group:
            icon = PhosphorIcon.regular("squares-four")
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

    // MARK: - Status display for services

    private func statusDisplay(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        switch service.serviceType {
        case ServiceTypes.heaterCooler:
            return heaterCoolerStatus(for: service)
        case ServiceTypes.thermostat:
            return thermostatStatus(for: service)
        case ServiceTypes.humidifierDehumidifier:
            return humidifierStatus(for: service)
        case ServiceTypes.windowCovering:
            return windowCoveringStatus(for: service)
        case ServiceTypes.lock:
            return lockStatus(for: service)
        case ServiceTypes.garageDoorOpener:
            return garageDoorStatus(for: service)
        case ServiceTypes.securitySystem:
            return securitySystemStatus(for: service)
        case ServiceTypes.airPurifier:
            return airPurifierStatus(for: service)
        default:
            // For lights, switches, outlets, fans, valves, etc. - check on/off state
            let isOn = getOnOffState(for: service)
            return (IconMapping.iconForServiceType(service.serviceType, filled: isOn), nil)
        }
    }

    /// Get on/off state for a service by checking powerStateId or activeId
    private func getOnOffState(for service: ServiceData) -> Bool {
        // Check powerStateId first (lights, switches, outlets)
        if let powerId = service.powerStateId.flatMap({ UUID(uuidString: $0) }),
           let power = cachedValues[powerId] as? Int ?? (cachedValues[powerId] as? Double).map({ Int($0) }) ?? (cachedValues[powerId] as? Bool).map({ $0 ? 1 : 0 }) {
            return power != 0
        }
        // Check activeId (fans, valves, purifiers)
        if let activeId = service.activeId.flatMap({ UUID(uuidString: $0) }),
           let active = cachedValues[activeId] as? Int ?? (cachedValues[activeId] as? Double).map({ Int($0) }) ?? (cachedValues[activeId] as? Bool).map({ $0 ? 1 : 0 }) {
            return active != 0
        }
        return false
    }

    private func heaterCoolerStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        // Get current temperature
        var tempText: String?
        if let tempId = service.currentTemperatureId.flatMap({ UUID(uuidString: $0) }),
           let temp = cachedValues[tempId] as? Double ?? (cachedValues[tempId] as? Int).map({ Double($0) }) {
            tempText = formatTemperature(temp)
        }

        // Check if active (on/off)
        var isActive = false
        if let activeId = service.activeId.flatMap({ UUID(uuidString: $0) }),
           let active = cachedValues[activeId] as? Int ?? (cachedValues[activeId] as? Double).map({ Int($0) }) ?? (cachedValues[activeId] as? Bool).map({ $0 ? 1 : 0 }) {
            isActive = active != 0
        }

        // When OFF, use default icon from centralized config
        if !isActive {
            return (IconMapping.iconForServiceType(service.serviceType, filled: false), tempText)
        }

        // Get mode icon from centralized config
        var modeIcon: NSImage?
        if let modeId = service.targetHeaterCoolerStateId.flatMap({ UUID(uuidString: $0) }),
           let modeValue = cachedValues[modeId] as? Int ?? (cachedValues[modeId] as? Double).map({ Int($0) }) {
            // 0 = auto, 1 = heat, 2 = cool
            let mode: String = switch modeValue {
            case 1: "heat"
            case 2: "cool"
            default: "auto"
            }
            modeIcon = PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: true)
        }

        return (modeIcon ?? IconMapping.iconForServiceType(service.serviceType, filled: true), tempText)
    }

    private func thermostatStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        var tempText: String?
        if let tempId = service.currentTemperatureId.flatMap({ UUID(uuidString: $0) }),
           let temp = cachedValues[tempId] as? Double ?? (cachedValues[tempId] as? Int).map({ Double($0) }) {
            tempText = formatTemperature(temp)
        }

        // Get mode icon from centralized config
        var modeIcon: NSImage?
        if let modeId = service.targetHeatingCoolingStateId.flatMap({ UUID(uuidString: $0) }),
           let modeValue = cachedValues[modeId] as? Int ?? (cachedValues[modeId] as? Double).map({ Int($0) }) {
            // 0 = off, 1 = heat, 2 = cool, 3 = auto
            if modeValue == 0 {
                // Off - use default icon
                modeIcon = IconMapping.iconForServiceType(service.serviceType, filled: false)
            } else {
                let mode: String = switch modeValue {
                case 1: "heat"
                case 2: "cool"
                default: "auto"
                }
                modeIcon = PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: true)
            }
        }

        return (modeIcon ?? IconMapping.iconForServiceType(service.serviceType, filled: false), tempText)
    }

    private func humidifierStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        var humidityText: String?
        if let humidityId = service.humidityId.flatMap({ UUID(uuidString: $0) }),
           let humidity = cachedValues[humidityId] as? Double ?? (cachedValues[humidityId] as? Int).map({ Double($0) }) {
            humidityText = "\(Int(humidity))%"
        }

        // Check if active (on/off)
        let isActive = getOnOffState(for: service)

        // When OFF, use default icon from centralized config
        if !isActive {
            return (IconMapping.iconForServiceType(service.serviceType, filled: false), humidityText)
        }

        // Get mode icon from centralized config
        // 0 = auto, 1 = humidifier, 2 = dehumidifier
        if let modeId = service.targetHumidifierDehumidifierStateId.flatMap({ UUID(uuidString: $0) }),
           let modeValue = cachedValues[modeId] as? Int ?? (cachedValues[modeId] as? Double).map({ Int($0) }) {
            let mode = modeValue == 2 ? "dehumidify" : "humidify"
            if let icon = PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: true) {
                return (icon, humidityText)
            }
        }

        return (IconMapping.iconForServiceType(service.serviceType, filled: true), humidityText)
    }

    private func windowCoveringStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        var positionText: String?
        var isOpen = false
        if let posId = service.currentPositionId.flatMap({ UUID(uuidString: $0) }),
           let position = cachedValues[posId] as? Int ?? (cachedValues[posId] as? Double).map({ Int($0) }) {
            positionText = "\(position)%"
            isOpen = position > 0
        }
        // Filled when open, regular when closed
        return (PhosphorIcon.icon("caret-up-down", filled: isOpen), positionText)
    }

    private func lockStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        if let lockId = service.lockCurrentStateId.flatMap({ UUID(uuidString: $0) }),
           let state = cachedValues[lockId] as? Int ?? (cachedValues[lockId] as? Double).map({ Int($0) }) {
            // 0 = unsecured, 1 = secured, 2 = jammed, 3 = unknown
            let icon: NSImage?
            let text: String?
            switch state {
            case 1:
                icon = PhosphorIcon.fill("lock")
                text = nil  // Icon is clear enough when locked
            case 2:
                icon = PhosphorIcon.regular("warning")
                text = "Jammed"
            default:
                icon = PhosphorIcon.regular("lock-open")
                text = nil  // Icon is clear enough when unlocked
            }
            return (icon, text)
        }
        return (IconMapping.iconForServiceType(service.serviceType), nil)
    }

    private func garageDoorStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        if let doorId = service.currentDoorStateId.flatMap({ UUID(uuidString: $0) }),
           let state = cachedValues[doorId] as? Int ?? (cachedValues[doorId] as? Double).map({ Int($0) }) {
            // 0 = open, 1 = closed, 2 = opening, 3 = closing, 4 = stopped
            let icon: NSImage?
            let text: String?
            switch state {
            case 1:
                icon = PhosphorIcon.fill("garage")
                text = nil
            case 2:
                icon = PhosphorIcon.regular("garage")
                text = "Opening"
            case 3:
                icon = PhosphorIcon.fill("garage")
                text = "Closing"
            case 4:
                icon = PhosphorIcon.regular("garage")
                text = "Stopped"
            default:
                icon = PhosphorIcon.regular("garage")
                text = nil
            }
            return (icon, text)
        }
        return (IconMapping.iconForServiceType(service.serviceType), nil)
    }

    private func securitySystemStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        if let secId = service.securitySystemCurrentStateId.flatMap({ UUID(uuidString: $0) }),
           let state = cachedValues[secId] as? Int ?? (cachedValues[secId] as? Double).map({ Int($0) }) {
            // 0 = stay arm, 1 = away arm, 2 = night arm, 3 = disarmed, 4 = triggered
            let icon: NSImage?
            let text: String?
            switch state {
            case 0:
                icon = PhosphorIcon.fill("shield-check")
                text = "Stay"
            case 1:
                icon = PhosphorIcon.fill("shield-check")
                text = "Away"
            case 2:
                icon = PhosphorIcon.fill("moon")
                text = "Night"
            case 4:
                icon = PhosphorIcon.fill("shield-warning")
                text = "Alarm!"
            default:
                icon = PhosphorIcon.regular("shield")
                text = nil
            }
            return (icon, text)
        }
        return (IconMapping.iconForServiceType(service.serviceType), nil)
    }

    private func airPurifierStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        let isActive = getOnOffState(for: service)
        return (IconMapping.iconForServiceType(service.serviceType, filled: isActive), nil)
    }

    private func formatTemperature(_ celsius: Double) -> String {
        // Check user's temperature unit preference (Fahrenheit for US locale, Celsius otherwise)
        let useFahrenheit = Locale.current.measurementSystem == .us
        if useFahrenheit {
            let fahrenheit = celsius * 9 / 5 + 32
            return "\(Int(round(fahrenheit)))°"
        } else {
            return "\(Int(round(celsius)))°"
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
        if let id = service.securitySystemCurrentStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.securitySystemTargetStateId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        if let id = service.humidityId.flatMap({ UUID(uuidString: $0) }) { ids.append(id) }
        return ids
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        // Cache the value for status display
        let oldValue = cachedValues[characteristicId]
        cachedValues[characteristicId] = value

        // Refresh button if value changed and this is a display characteristic
        if !valuesEqual(oldValue, value), isDisplayCharacteristic(characteristicId) {
            setupButton()
        }

        // Update any menu items that track this characteristic
        for item in menuItems {
            if let refreshable = item as? CharacteristicRefreshable,
               refreshable.characteristicIdentifiers.contains(characteristicId),
               let updatable = item as? CharacteristicUpdatable {
                updatable.updateValue(for: characteristicId, value: value, isLocalChange: false)
            }
        }
    }

    private func valuesEqual(_ a: Any?, _ b: Any) -> Bool {
        if a == nil { return false }
        if let aInt = a as? Int, let bInt = b as? Int { return aInt == bInt }
        if let aDouble = a as? Double, let bDouble = b as? Double { return aDouble == bDouble }
        if let aBool = a as? Bool, let bBool = b as? Bool { return aBool == bBool }
        return false
    }

    private func isDisplayCharacteristic(_ characteristicId: UUID) -> Bool {
        // Check if this characteristic affects the status bar display
        guard case .service(let service) = itemType else { return false }

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

        return displayIds.compactMap { $0.flatMap { UUID(uuidString: $0) } }.contains(characteristicId)
    }

    // MARK: - Notifications

    static let closeAllPanelsNotification = Notification.Name("PinnedStatusItemCloseAllPanels")
}
