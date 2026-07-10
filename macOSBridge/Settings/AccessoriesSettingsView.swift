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

    // MARK: - Persistent containers

    private var roomsSection: SimpleHeightContainer!

    // MARK: - Persistent table view

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
                     ServiceTypes.heaterCooler, ServiceTypes.thermostat, ServiceTypes.humidifierDehumidifier,
                     ServiceTypes.airPurifier, ServiceTypes.windowCovering,
                     ServiceTypes.door, ServiceTypes.window, ServiceTypes.lock, ServiceTypes.garageDoorOpener,
                     ServiceTypes.valve, ServiceTypes.faucet, ServiceTypes.slat, ServiceTypes.securitySystem,
                     ServiceTypes.contactSensor, ServiceTypes.motionSensor, ServiceTypes.occupancySensor,
                     ServiceTypes.leakSensor, ServiceTypes.smokeSensor, ServiceTypes.carbonMonoxideSensor,
                     ServiceTypes.carbonDioxideSensor, ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor,
                     ServiceTypes.sensor, ServiceTypes.binarySensor]

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
        let descLabel = NSTextField(wrappingLabelWithString: String(localized: "settings.accessories.description", defaultValue: "Manage your Home menu from here. Star accessories to add them to Favourites, use the eye icon to hide sections or devices, and pin items to the menu bar.", bundle: .macOSBridge))
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        addSpacer(height: 16)

        // Create group button
        let createButton = NSButton(title: String(localized: "settings.accessories.create_group", defaultValue: "Create group", bundle: .macOSBridge), target: self, action: #selector(createGroupTapped))
        createButton.bezelStyle = .rounded
        createButton.controlSize = .regular
        createButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(createButton)
        addSpacer(height: 16)

        // One table hosts every section (favourites, groups, scenes, rooms,
        // batteries, other) so they can all be reordered together.
        roomsSection = SimpleHeightContainer()
        roomsTableView = RoomsTableView()
        roomsTableView.roomTableItems = { [weak self] in self?.roomTableItems ?? [] }
        roomsTableView.contextMenuForRow = { [weak self] row in self?.roomsContextMenu(forRow: row) }
        configureTableView(roomsTableView, dragType: .roomItem, intercellSpacing: 4)
        roomsTableView.registerForDraggedTypes([.roomItem, .roomAccessoryItem, .sceneItem, .favouriteItem, .globalGroupItem, .groupDeviceItem])
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

    // MARK: - Section Updates

    private func updateAllSections() {
        rebuildAllData()
        updateRoomsSection()
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
        alert.messageText = String(localized: "alert.delete_group.title", defaultValue: "Delete group?", bundle: .macOSBridge)
        alert.informativeText = String(localized: "alert.delete_group.message", defaultValue: "Are you sure you want to delete \"\(group.name)\"? This cannot be undone.", bundle: .macOSBridge)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "common.delete", defaultValue: "Delete", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))

        if alert.runModal() == .alertFirstButtonReturn {
            PreferencesManager.shared.deleteDeviceGroup(id: group.id)
            rebuild()
        }
    }
}
