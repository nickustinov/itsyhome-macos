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
    private var isUISetup = false

    // MARK: - Persistent section containers

    private var favouritesSection: SettingsSectionContainer!
    private var globalGroupsSection: SettingsSectionContainer!
    private var scenesHeaderContainer: SimpleHeightContainer!
    private var scenesTableSection: SettingsSectionContainer!
    private var scenesSeparator: NSView!
    private var roomsSection: SimpleHeightContainer!
    private var otherHeaderContainer: SimpleHeightContainer!
    private var otherContentContainer: SimpleHeightContainer!

    // MARK: - Persistent table views

    var favouritesTableView: NSTableView!
    var globalGroupsTableView: NSTableView!
    var scenesTableView: NSTableView!
    var roomsTableView: RoomsTableView!

    // MARK: - Data

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

    let typeOrder = [ServiceTypes.lightbulb, ServiceTypes.switch, ServiceTypes.outlet, ServiceTypes.fan, ServiceTypes.fanV2,
                     ServiceTypes.heaterCooler, ServiceTypes.thermostat, ServiceTypes.windowCovering,
                     ServiceTypes.door, ServiceTypes.window, ServiceTypes.lock, ServiceTypes.garageDoorOpener]

    // MARK: - Initialization

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

    // MARK: - Public API

    func configure(with data: MenuData) {
        self.menuData = data
        PreferencesManager.shared.currentHomeId = data.selectedHomeId

        if !isUISetup {
            setupUI()
            isUISetup = true
        }

        updateAllSections()
    }

    func rebuild() {
        updateAllSections()
    }

    // MARK: - UI Setup (called once)

    private func setupUI() {
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Manage your Home menu from here. Star accessories to add them to Favourites, use the eye icon to hide sections or devices, and pin items to the menu bar.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        addSpacer(height: 16)

        // Create group button
        let createButton = NSButton(title: "Create group", target: self, action: #selector(createGroupTapped))
        createButton.bezelStyle = .rounded
        createButton.controlSize = .regular
        createButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(createButton)
        addSpacer(height: 16)

        // Favourites section
        favouritesSection = SettingsSectionContainer()
        favouritesTableView = createTableView(dragType: .favouriteItem)
        favouritesSection.setContent(favouritesTableView)
        addSection(favouritesSection)

        // Global groups section
        globalGroupsSection = SettingsSectionContainer()
        globalGroupsTableView = createTableView(dragType: .globalGroupItem)
        globalGroupsSection.setContent(globalGroupsTableView)
        addSection(globalGroupsSection)

        // Scenes header (always present if there are scenes, but content toggles)
        scenesHeaderContainer = SimpleHeightContainer()
        addSection(scenesHeaderContainer)

        // Scenes table section
        scenesTableSection = SettingsSectionContainer()
        scenesTableView = createTableView(dragType: .sceneItem)
        scenesTableSection.setContent(scenesTableView)
        addSection(scenesTableSection)

        // Separator after scenes
        scenesSeparator = createSectionSeparator()
        addSection(scenesSeparator)

        // Rooms section
        roomsSection = SimpleHeightContainer()
        roomsTableView = RoomsTableView()
        roomsTableView.roomTableItems = { [weak self] in self?.roomTableItems ?? [] }
        configureTableView(roomsTableView, dragType: .roomItem, intercellSpacing: 4)
        roomsTableView.registerForDraggedTypes([.roomItem, .roomGroupItem])
        roomsTableView.translatesAutoresizingMaskIntoConstraints = false
        roomsSection.addSubview(roomsTableView)
        NSLayoutConstraint.activate([
            roomsTableView.topAnchor.constraint(equalTo: roomsSection.topAnchor),
            roomsTableView.leadingAnchor.constraint(equalTo: roomsSection.leadingAnchor),
            roomsTableView.trailingAnchor.constraint(equalTo: roomsSection.trailingAnchor),
            roomsTableView.bottomAnchor.constraint(equalTo: roomsSection.bottomAnchor)
        ])
        addSection(roomsSection)
        addSpacer(height: 12)

        // Other section header
        otherHeaderContainer = SimpleHeightContainer()
        addSection(otherHeaderContainer)

        // Other section content
        otherContentContainer = SimpleHeightContainer()
        addSection(otherContentContainer)
        addSpacer(height: 12)
    }

    private func createTableView(dragType: NSPasteboard.PasteboardType) -> NSTableView {
        let tableView = NSTableView()
        configureTableView(tableView, dragType: dragType)
        return tableView
    }

    private func configureTableView(_ tableView: NSTableView, dragType: NSPasteboard.PasteboardType, intercellSpacing: CGFloat = 0) {
        tableView.headerView = nil
        tableView.rowHeight = AccessoryRowLayout.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: intercellSpacing)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.gridStyleMask = []
        tableView.registerForDraggedTypes([dragType])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        tableView.delegate = self
        tableView.dataSource = self
    }

    private func addSection(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func createSectionSeparator() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 16),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    // MARK: - Section Updates

    private func updateAllSections() {
        rebuildAllData()
        updateFavouritesSection()
        updateGlobalGroupsSection()
        updateScenesSection()
        updateRoomsSection()
        updateOtherSection()
    }

    func updateFavouritesSection() {
        rebuildFavouritesList()

        let isEmpty = favouriteItems.isEmpty
        favouritesSection.isHidden = isEmpty

        if !isEmpty {
            let height = CGFloat(favouriteItems.count) * AccessoryRowLayout.rowHeight
            favouritesSection.setContentHeight(height)
            favouritesTableView.reloadData()
        }
    }

    func updateGlobalGroupsSection() {
        // globalGroups already rebuilt in rebuildAllData
        let isEmpty = globalGroups.isEmpty
        globalGroupsSection.isHidden = isEmpty

        if !isEmpty {
            let height = CGFloat(globalGroups.count) * AccessoryRowLayout.rowHeight
            globalGroupsSection.setContentHeight(height)
            globalGroupsTableView.reloadData()
        }
    }

    func updateScenesSection() {
        guard let data = menuData else {
            scenesHeaderContainer.isHidden = true
            scenesTableSection.isHidden = true
            scenesSeparator.isHidden = true
            return
        }

        let hasScenes = !data.scenes.isEmpty
        scenesHeaderContainer.isHidden = !hasScenes
        scenesSeparator.isHidden = !hasScenes

        if hasScenes {
            let preferences = PreferencesManager.shared
            let scenesKey = "scenes"
            let isHidden = preferences.hideScenesSection
            let isCollapsed = !expandedSections.contains(scenesKey)

            // Update header
            updateScenesHeader(isHidden: isHidden, isCollapsed: isCollapsed)

            // Update table visibility and content
            scenesTableSection.isHidden = isCollapsed
            if !isCollapsed {
                let height = CGFloat(sceneItems.count) * AccessoryRowLayout.rowHeight
                scenesTableSection.setContentHeight(height)
                scenesTableView.reloadData()
            }
        } else {
            scenesTableSection.isHidden = true
        }
    }

    func updateRoomsSection() {
        rebuildRoomData()

        let isEmpty = roomTableItems.isEmpty
        roomsSection.isHidden = isEmpty

        if !isEmpty {
            let height = calculateRoomsTableHeight()
            roomsSection.setHeight(height)
            roomsTableView.reloadData()
        }
    }

    func updateOtherSection() {
        let hasOther = !noRoomServices.isEmpty
        otherHeaderContainer.isHidden = !hasOther
        otherContentContainer.isHidden = !hasOther

        if hasOther {
            let otherKey = "other"
            let isCollapsed = !expandedSections.contains(otherKey)

            updateOtherHeader(isCollapsed: isCollapsed)

            if isCollapsed {
                otherContentContainer.isHidden = true
            } else {
                otherContentContainer.isHidden = false
                updateOtherContent()
            }
        }
    }

    private func updateScenesHeader(isHidden: Bool, isCollapsed: Bool) {
        let L = AccessoryRowLayout.self
        scenesHeaderContainer.subviews.forEach { $0.removeFromSuperview() }

        let header = createScenesHeaderStrip(isHidden: isHidden, isCollapsed: isCollapsed, sceneCount: sceneItems.count)
        header.translatesAutoresizingMaskIntoConstraints = false
        scenesHeaderContainer.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: scenesHeaderContainer.topAnchor),
            header.leadingAnchor.constraint(equalTo: scenesHeaderContainer.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: scenesHeaderContainer.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: scenesHeaderContainer.bottomAnchor)
        ])
        scenesHeaderContainer.setHeight(L.rowHeight)
    }

    private func updateOtherHeader(isCollapsed: Bool) {
        let L = AccessoryRowLayout.self
        otherHeaderContainer.subviews.forEach { $0.removeFromSuperview() }

        let header = createOtherHeaderStrip(isCollapsed: isCollapsed)
        header.translatesAutoresizingMaskIntoConstraints = false
        otherHeaderContainer.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: otherHeaderContainer.topAnchor),
            header.leadingAnchor.constraint(equalTo: otherHeaderContainer.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: otherHeaderContainer.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: otherHeaderContainer.bottomAnchor)
        ])
        otherHeaderContainer.setHeight(L.rowHeight)
    }

    private func updateOtherContent() {
        let L = AccessoryRowLayout.self
        otherContentContainer.subviews.forEach { $0.removeFromSuperview() }

        let sorted = noRoomServices.sorted { s1, s2 in
            let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
            let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
            return i1 != i2 ? i1 < i2 : s1.name < s2.name
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        for service in sorted {
            let row = createAccessoryRow(service: service, roomHidden: false)
            row.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            row.heightAnchor.constraint(equalToConstant: L.rowHeight).isActive = true
        }

        otherContentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: otherContentContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: otherContentContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: otherContentContainer.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: otherContentContainer.bottomAnchor)
        ])

        let height = CGFloat(sorted.count) * L.rowHeight
        otherContentContainer.setHeight(height)
    }

    // MARK: - Data Building

    private func rebuildAllData() {
        rebuildGroupData()
        rebuildFavouritesList()
        rebuildRoomData()
        rebuildSceneData()
    }

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
                    let icon = PhosphorIcon.regular(group.icon)
                    items.append(FavouriteItem(kind: .group(group), id: id, name: group.name, icon: icon))
                }
            } else if let scene = sceneLookup[id] {
                items.append(FavouriteItem(kind: .scene(scene), id: id, name: scene.name, icon: SceneIconInference.icon(for: scene.name)))
            } else if let service = serviceLookup[id] {
                items.append(FavouriteItem(kind: .service(service), id: id, name: service.name, icon: IconResolver.icon(for: service)))
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

    // MARK: - Height Calculation

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

    // MARK: - Room Index Helpers

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

    // MARK: - Group Actions

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
        editor.onDelete = { [weak self] deletedGroup in
            PreferencesManager.shared.deleteDeviceGroup(id: deletedGroup.id)
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
