//
//  AccessoriesSettingsView.swift
//  macOSBridge
//
//  Accessories settings tab with favourites and visibility toggles
//

import AppKit

// MARK: - Pasteboard types

extension NSPasteboard.PasteboardType {
    static let favouriteItem = NSPasteboard.PasteboardType("com.itsyhome.favouriteItem")
    static let roomItem = NSPasteboard.PasteboardType("com.itsyhome.roomItem")
    static let sceneItem = NSPasteboard.PasteboardType("com.itsyhome.sceneItem")
    static let globalGroupItem = NSPasteboard.PasteboardType("com.itsyhome.globalGroupItem")
    static let roomGroupItem = NSPasteboard.PasteboardType("com.itsyhome.roomGroupItem")
}

// MARK: - Data models

struct FavouriteItem {
    enum Kind {
        case scene(SceneData)
        case service(ServiceData)
        case group(DeviceGroup)
    }
    let kind: Kind
    let id: String
    let name: String
    let icon: NSImage?
}

enum RoomTableItem {
    case header(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int)
    case group(group: DeviceGroup, roomId: String?)
    case groupSeparator
    case accessory(service: ServiceData, roomHidden: Bool)
    case separator

    var isHeader: Bool {
        if case .header = self { return true }
        return false
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }
}

// MARK: - Main view

class AccessoriesSettingsView: NSView {

    private let stackView = NSStackView()
    private var menuData: MenuData?
    private var needsRebuild = false

    // Tables
    var favouritesTableView: NSTableView?
    var roomsTableView: RoomsTableView?
    var scenesTableView: NSTableView?

    // Data
    var favouriteItems: [FavouriteItem] = []
    var roomTableItems: [RoomTableItem] = []
    var sceneItems: [SceneData] = []
    var orderedRooms: [RoomData] = []
    var expandedSections: Set<String> = []
    var servicesByRoom: [String: [ServiceData]] = [:]
    var noRoomServices: [ServiceData] = []

    // Groups data
    var globalGroups: [DeviceGroup] = []
    var groupsByRoom: [String: [DeviceGroup]] = [:]
    var globalGroupsTableView: NSTableView?

    let typeOrder = [ServiceTypes.lightbulb, ServiceTypes.switch, ServiceTypes.outlet, ServiceTypes.fan,
                     ServiceTypes.heaterCooler, ServiceTypes.thermostat, ServiceTypes.windowCovering,
                     ServiceTypes.lock, ServiceTypes.garageDoorOpener]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        if needsRebuild {
            needsRebuild = false
            rebuildContent()
        }
    }

    func configure(with data: MenuData) {
        self.menuData = data
        PreferencesManager.shared.currentHomeId = data.selectedHomeId
        needsRebuild = true
        needsLayout = true
    }

    func rebuild() {
        needsRebuild = true
        needsLayout = true
    }

    // MARK: - Data building

    func rebuildFavouritesList() {
        guard let data = menuData else {
            favouriteItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let serviceLookup = Dictionary(uniqueKeysWithValues: data.accessories.flatMap { $0.services }.map { ($0.uniqueIdentifier, $0) })
        let groupLookup = Dictionary(uniqueKeysWithValues: preferences.deviceGroups.map { ($0.id, $0) })

        var items: [FavouriteItem] = []
        for id in preferences.orderedFavouriteIds {
            if id.hasPrefix("groupFav:") {
                let groupId = String(id.dropFirst("groupFav:".count))
                if let group = groupLookup[groupId] {
                    let icon = NSImage(systemSymbolName: group.icon, accessibilityDescription: group.name)
                    items.append(FavouriteItem(kind: .group(group), id: id, name: group.name, icon: icon))
                }
            } else if let scene = sceneLookup[id] {
                items.append(FavouriteItem(kind: .scene(scene), id: id, name: scene.name, icon: SceneIconInference.icon(for: scene.name)))
            } else if let service = serviceLookup[id] {
                items.append(FavouriteItem(kind: .service(service), id: id, name: service.name, icon: IconMapping.iconForServiceType(service.serviceType)))
            }
        }
        favouriteItems = items
    }

    func rebuildRoomData() {
        guard let data = menuData else {
            roomTableItems = []
            orderedRooms = []
            return
        }

        let preferences = PreferencesManager.shared
        let excludedTypes: Set<String> = [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]

        servicesByRoom = [:]
        noRoomServices = []

        for accessory in data.accessories {
            for service in accessory.services where !excludedTypes.contains(service.serviceType) {
                if let roomId = service.roomIdentifier {
                    servicesByRoom[roomId, default: []].append(service)
                } else {
                    noRoomServices.append(service)
                }
            }
        }

        // Order rooms by saved order, with unseen rooms appended at end
        let roomsWithServices = data.rooms.filter { servicesByRoom[$0.uniqueIdentifier] != nil }
        let savedOrder = preferences.roomOrder
        var ordered: [RoomData] = []
        for roomId in savedOrder {
            if let room = roomsWithServices.first(where: { $0.uniqueIdentifier == roomId }) {
                ordered.append(room)
            }
        }
        for room in roomsWithServices where !ordered.contains(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) {
            ordered.append(room)
        }
        orderedRooms = ordered
        preferences.roomOrder = ordered.map { $0.uniqueIdentifier }

        // Build flat table items
        var items: [RoomTableItem] = []
        for room in ordered {
            let roomId = room.uniqueIdentifier
            let isHidden = preferences.isHidden(roomId: roomId)
            let isCollapsed = !expandedSections.contains(roomId)
            let services = servicesByRoom[roomId] ?? []
            let roomGroups = groupsByRoom[roomId] ?? []

            items.append(.header(room: room, isHidden: isHidden, isCollapsed: isCollapsed, serviceCount: services.count))

            if !isCollapsed {
                // Add groups at the top of each room
                for group in roomGroups {
                    items.append(.group(group: group, roomId: roomId))
                }

                // Add separator after groups if there are both groups and services
                if !roomGroups.isEmpty && !services.isEmpty {
                    items.append(.groupSeparator)
                }

                // Group services by type
                var servicesByType: [String: [ServiceData]] = [:]
                for service in services {
                    servicesByType[service.serviceType, default: []].append(service)
                }

                // Sort types by typeOrder and add separators between groups
                let sortedTypes = servicesByType.keys.sorted { type1, type2 in
                    let i1 = typeOrder.firstIndex(of: type1) ?? Int.max
                    let i2 = typeOrder.firstIndex(of: type2) ?? Int.max
                    return i1 < i2
                }

                var isFirstGroup = true
                for serviceType in sortedTypes {
                    guard let typeServices = servicesByType[serviceType] else { continue }

                    if !isFirstGroup {
                        items.append(.separator)
                    }
                    isFirstGroup = false

                    let sortedServices = typeServices.sorted { $0.name < $1.name }
                    for service in sortedServices {
                        items.append(.accessory(service: service, roomHidden: isHidden))
                    }
                }
            }
        }
        roomTableItems = items
    }

    func rebuildSceneData() {
        guard let data = menuData else {
            sceneItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let savedOrder = preferences.sceneOrder
        var ordered: [SceneData] = []
        for sceneId in savedOrder {
            if let scene = data.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
                ordered.append(scene)
            }
        }
        for scene in data.scenes where !ordered.contains(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) {
            ordered.append(scene)
        }
        sceneItems = ordered
        preferences.sceneOrder = ordered.map { $0.uniqueIdentifier }
    }

    func rebuildGroupData() {
        let preferences = PreferencesManager.shared
        let allGroups = preferences.deviceGroups

        // Separate groups by room assignment
        var global: [DeviceGroup] = []
        var byRoom: [String: [DeviceGroup]] = [:]

        for group in allGroups {
            if let roomId = group.roomId {
                byRoom[roomId, default: []].append(group)
            } else {
                global.append(group)
            }
        }

        // Order global groups
        let savedGlobalOrder = preferences.globalGroupOrder
        var orderedGlobal: [DeviceGroup] = []
        for groupId in savedGlobalOrder {
            if let group = global.first(where: { $0.id == groupId }) {
                orderedGlobal.append(group)
            }
        }
        for group in global where !orderedGlobal.contains(where: { $0.id == group.id }) {
            orderedGlobal.append(group)
        }
        globalGroups = orderedGlobal
        if !orderedGlobal.isEmpty {
            preferences.globalGroupOrder = orderedGlobal.map { $0.id }
        }

        // Order groups per room
        for (roomId, roomGroups) in byRoom {
            let savedRoomOrder = preferences.groupOrder(forRoom: roomId)
            var ordered: [DeviceGroup] = []
            for groupId in savedRoomOrder {
                if let group = roomGroups.first(where: { $0.id == groupId }) {
                    ordered.append(group)
                }
            }
            for group in roomGroups where !ordered.contains(where: { $0.id == group.id }) {
                ordered.append(group)
            }
            byRoom[roomId] = ordered
            if !ordered.isEmpty {
                preferences.setGroupOrder(ordered.map { $0.id }, forRoom: roomId)
            }
        }
        groupsByRoom = byRoom
    }

    // MARK: - Content building

    private func rebuildContent() {
        rebuildGroupData()
        rebuildFavouritesList()
        rebuildRoomData()
        rebuildSceneData()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        favouritesTableView = nil
        roomsTableView = nil
        scenesTableView = nil
        globalGroupsTableView = nil

        guard let data = menuData else { return }

        let preferences = PreferencesManager.shared
        let L = AccessoryRowLayout.self
        let isPro = ProStatusCache.shared.isPro

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Add accessories to Favourites to pin them at the top of your menu. Use the eye icon to hide sections or devices you don't need.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        addSpacer(height: 16)

        // Create group button (Pro only)
        let createButton = NSButton(title: "Create group", target: self, action: #selector(createGroupTapped))
        createButton.bezelStyle = .rounded
        createButton.controlSize = .regular
        createButton.isEnabled = isPro
        createButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(createButton)
        addSpacer(height: 16)

        // Favourites section
        if !favouriteItems.isEmpty {
            let tableHeight = CGFloat(favouriteItems.count) * L.rowHeight
            let tableContainer = createFavouritesTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
            favouritesTableView?.reloadData()
            addSeparator()
        }

        // Global groups section (groups with no room)
        if !globalGroups.isEmpty {
            let tableHeight = CGFloat(globalGroups.count) * L.rowHeight
            let tableContainer = createGlobalGroupsTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
            globalGroupsTableView?.reloadData()
            addSeparator()
        }

        // Scenes section
        if !data.scenes.isEmpty {
            let scenesKey = "scenes"
            let isHidden = preferences.hideScenesSection
            let isScenesCollapsed = !expandedSections.contains(scenesKey)

            let header = createScenesHeaderStrip(isHidden: isHidden, isCollapsed: isScenesCollapsed, sceneCount: sceneItems.count)
            addView(header, height: L.rowHeight)

            if !isScenesCollapsed {
                let tableHeight = CGFloat(sceneItems.count) * L.rowHeight
                let tableContainer = createScenesTable(height: tableHeight)
                addView(tableContainer, height: tableHeight)
                scenesTableView?.reloadData()
            }
            addSeparator()
        }

        // Rooms section
        if !roomTableItems.isEmpty {
            let tableHeight = calculateRoomsTableHeight()
            let tableContainer = createRoomsTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
            roomsTableView?.reloadData()
            addSpacer(height: 12)
        }

        // Other section (no room)
        if !noRoomServices.isEmpty {
            buildOtherSection()
        }
    }

    private func buildOtherSection() {
        let L = AccessoryRowLayout.self
        let otherKey = "other"
        let isOtherCollapsed = !expandedSections.contains(otherKey)

        let header = createOtherHeaderStrip(isCollapsed: isOtherCollapsed)
        addView(header, height: L.rowHeight)

        if !isOtherCollapsed {
            let sorted = noRoomServices.sorted { s1, s2 in
                let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                return i1 != i2 ? i1 < i2 : s1.name < s2.name
            }

            // All accessories can be pinned to the menu bar
            for service in sorted {
                let row = createAccessoryRow(service: service, roomHidden: false)
                addView(row, height: L.rowHeight)
            }
        }
        addSpacer(height: 12)
    }

    // MARK: - Layout helpers

    func addHeader(title: String) {
        let header = AccessorySectionHeader(title: title)
        addView(header, height: 32)
    }

    func addView(_ view: NSView, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func addSeparator() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        stackView.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        container.heightAnchor.constraint(equalToConstant: 16).isActive = true
    }

    private func calculateRoomsTableHeight() -> CGFloat {
        let L = AccessoryRowLayout.self
        var height: CGFloat = 0
        for (index, item) in roomTableItems.enumerated() {
            switch item {
            case .separator, .groupSeparator:
                height += 12
            default:
                height += L.rowHeight
            }
            // Add intercell spacing (except for last row)
            if index < roomTableItems.count - 1 {
                height += 4
            }
        }
        return height
    }

    // MARK: - Room index helpers

    func roomIndex(forTableRow row: Int) -> Int? {
        var headerCount = 0
        for i in 0...row {
            if case .header = roomTableItems[i] {
                if i == row { return headerCount }
                headerCount += 1
            }
        }
        return nil
    }

    func tableRow(forRoomIndex roomIndex: Int) -> Int? {
        var headerCount = 0
        for (i, item) in roomTableItems.enumerated() {
            if case .header = item {
                if headerCount == roomIndex { return i }
                headerCount += 1
            }
        }
        return nil
    }

    // MARK: - Group actions

    @objc func createGroupTapped() {
        showGroupEditor(group: nil)
    }

    func showGroupEditor(group: DeviceGroup?) {
        guard let data = menuData else { return }

        let editor = GroupEditorPanel(group: group, menuData: data)
        editor.onSave = { [weak self] savedGroup in
            if group == nil {
                PreferencesManager.shared.addDeviceGroup(savedGroup)
            } else {
                PreferencesManager.shared.updateDeviceGroup(savedGroup)
            }
            self?.rebuild()
        }

        guard let window = self.window else { return }
        window.beginSheet(editor.window!) { _ in }
    }

    func deleteGroup(_ group: DeviceGroup) {
        let alert = NSAlert()
        alert.messageText = "Delete group?"
        alert.informativeText = "Are you sure you want to delete \"\(group.name)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            PreferencesManager.shared.deleteDeviceGroup(id: group.id)
            rebuild()
        }
    }
}
