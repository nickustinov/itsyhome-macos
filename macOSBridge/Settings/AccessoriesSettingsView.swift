//
//  AccessoriesSettingsView.swift
//  macOSBridge
//
//  Accessories settings tab with favourites and visibility toggles
//

import AppKit

// MARK: - Main view

class AccessoriesSettingsView: NSView {

    private let stackView = NSStackView()
    var menuData: MenuData?
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
    var globalGroupsTableView: GroupsTableView!
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
        globalGroupsTableView = GroupsTableView()
        configureTableView(globalGroupsTableView, dragType: .globalGroupItem)
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
        roomsTableView.groupCountForRoom = { [weak self] roomId in self?.groupsByRoom[roomId]?.count ?? 0 }
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
