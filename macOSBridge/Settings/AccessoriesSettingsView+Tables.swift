//
//  AccessoriesSettingsView+Tables.swift
//  macOSBridge
//
//  Table creation and header strips for accessories settings
//

import AppKit

// MARK: - Table creation

extension AccessoriesSettingsView {

    func createFavouritesTable(height: CGFloat) -> NSView {
        let tableView = NSTableView()
        self.favouritesTableView = tableView
        configureTableView(tableView, dragType: .favouriteItem)

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)
        pinToEdges(tableView, in: container)

        return container
    }

    func createRoomsTable(height: CGFloat) -> NSView {
        let tableView = RoomsTableView()
        tableView.roomTableItems = { [weak self] in self?.roomTableItems ?? [] }
        self.roomsTableView = tableView
        configureTableView(tableView, dragType: .roomItem, intercellSpacing: 4)

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)
        pinToEdges(tableView, in: container)

        return container
    }

    func createScenesTable(height: CGFloat) -> NSView {
        let tableView = NSTableView()
        self.scenesTableView = tableView
        configureTableView(tableView, dragType: .sceneItem)

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)
        pinToEdges(tableView, in: container)

        return container
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

    private func pinToEdges(_ view: NSView, in container: NSView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

// MARK: - Header strips using AccessoryRowView

extension AccessoriesSettingsView {

    func createScenesHeaderStrip(isHidden: Bool, isCollapsed: Bool) -> NSView {
        let config = AccessoryRowConfig(
            name: "Scenes",
            showChevron: true,
            isCollapsed: isCollapsed,
            isItemHidden: isHidden,
            showEyeButton: true,
            isSectionHeader: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.scenesChevronTapped()
        }
        rowView.onEyeToggled = { [weak self] in
            self?.scenesEyeTapped()
        }
        return rowView
    }

    func createOtherHeaderStrip(isCollapsed: Bool) -> NSView {
        let config = AccessoryRowConfig(
            name: "Other",
            showChevron: true,
            isCollapsed: isCollapsed,
            isSectionHeader: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.otherChevronTapped()
        }
        return rowView
    }

    func createRoomHeaderView(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int) -> NSView {
        let preferences = PreferencesManager.shared
        let isPinned = preferences.isPinnedRoom(roomId: room.uniqueIdentifier)
        let roomIndex = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) ?? 0

        let config = AccessoryRowConfig(
            name: room.name,
            icon: IconMapping.iconForRoom(room.name),
            count: serviceCount,
            showDragHandle: true,
            showChevron: true,
            isCollapsed: isCollapsed,
            isItemHidden: isHidden,
            isPinned: isPinned,
            showEyeButton: true,
            showPinButton: true,
            rowTag: roomIndex,
            isSectionHeader: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.roomChevronToggled(roomIndex: roomIndex)
        }
        rowView.onEyeToggled = { [weak self] in
            self?.roomEyeToggled(roomIndex: roomIndex)
        }
        rowView.onPinToggled = { [weak self] in
            self?.roomPinToggled(roomIndex: roomIndex)
        }
        return rowView
    }

    // MARK: - Actions

    func scenesChevronTapped() {
        let scenesKey = "scenes"
        if expandedSections.contains(scenesKey) {
            expandedSections.remove(scenesKey)
        } else {
            expandedSections.insert(scenesKey)
        }
        rebuild()
    }

    func scenesEyeTapped() {
        PreferencesManager.shared.hideScenesSection.toggle()
        rebuild()
    }

    func otherChevronTapped() {
        let otherKey = "other"
        if expandedSections.contains(otherKey) {
            expandedSections.remove(otherKey)
        } else {
            expandedSections.insert(otherKey)
        }
        rebuild()
    }

    private func roomChevronToggled(roomIndex: Int) {
        guard roomIndex < orderedRooms.count else { return }
        let roomId = orderedRooms[roomIndex].uniqueIdentifier
        if expandedSections.contains(roomId) {
            expandedSections.remove(roomId)
        } else {
            expandedSections.insert(roomId)
        }
        rebuild()
    }

    private func roomEyeToggled(roomIndex: Int) {
        guard roomIndex < orderedRooms.count else { return }
        let roomId = orderedRooms[roomIndex].uniqueIdentifier
        PreferencesManager.shared.toggleHidden(roomId: roomId)
        rebuild()
    }

    private func roomPinToggled(roomIndex: Int) {
        guard roomIndex < orderedRooms.count else { return }
        let room = orderedRooms[roomIndex]
        PreferencesManager.shared.togglePinnedRoom(roomId: room.uniqueIdentifier)
        rebuild()
    }
}

// MARK: - Rooms table view (prevents dragging accessory rows)

class RoomsTableView: NSTableView {

    var roomTableItems: (() -> [RoomTableItem])?

    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .withinApplication ? .move : []
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)

        // Only allow drag initiation from header rows
        if clickedRow >= 0, let items = roomTableItems?(), clickedRow < items.count {
            if !items[clickedRow].isHeader {
                // For accessory rows, handle click but don't allow drag
                // Just select/deselect without initiating drag
                return
            }
        }

        super.mouseDown(with: event)
    }
}
