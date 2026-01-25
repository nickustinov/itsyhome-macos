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

// MARK: - Header strips

extension AccessoriesSettingsView {

    func createScenesHeaderStrip(isHidden: Bool, isCollapsed: Bool) -> NSView {
        let L = AccessoryRowLayout.self
        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let chevronButton = createChevronButton(isCollapsed: isCollapsed)
        chevronButton.target = self
        chevronButton.action = #selector(scenesChevronTapped)
        container.addSubview(chevronButton)

        let eyeButton = createEyeButton(isHidden: isHidden)
        eyeButton.target = self
        eyeButton.action = #selector(scenesEyeTapped)
        container.addSubview(eyeButton)

        let nameLabel = createHeaderLabel(text: "Scenes", isHidden: isHidden)
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            chevronButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: L.leftPadding),
            chevronButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 14),
            chevronButton.heightAnchor.constraint(equalToConstant: 14),

            eyeButton.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: L.spacing),
            eyeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            eyeButton.widthAnchor.constraint(equalToConstant: L.buttonSize),
            eyeButton.heightAnchor.constraint(equalToConstant: L.buttonSize),

            nameLabel.leadingAnchor.constraint(equalTo: eyeButton.trailingAnchor, constant: L.spacing),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -L.rightPadding)
        ])

        return container
    }

    func createOtherHeaderStrip(isCollapsed: Bool) -> NSView {
        let L = AccessoryRowLayout.self
        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let chevronButton = createChevronButton(isCollapsed: isCollapsed)
        chevronButton.target = self
        chevronButton.action = #selector(otherChevronTapped)
        container.addSubview(chevronButton)

        let nameLabel = createHeaderLabel(text: "Other", isHidden: false)
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            chevronButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: L.leftPadding),
            chevronButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 14),
            chevronButton.heightAnchor.constraint(equalToConstant: 14),

            nameLabel.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: L.spacing),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -L.rightPadding)
        ])

        return container
    }

    func createRoomHeaderView(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int) -> NSView {
        let L = AccessoryRowLayout.self
        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let dragHandle = DragHandleView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dragHandle)

        let chevronButton = createChevronButton(isCollapsed: isCollapsed)
        chevronButton.tag = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) ?? 0
        chevronButton.target = self
        chevronButton.action = #selector(roomChevronTapped(_:))
        container.addSubview(chevronButton)

        let eyeButton = createEyeButton(isHidden: isHidden)
        eyeButton.tag = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) ?? 0
        eyeButton.target = self
        eyeButton.action = #selector(roomEyeTapped(_:))
        container.addSubview(eyeButton)

        let nameLabel = createHeaderLabel(text: room.name, isHidden: isHidden)
        nameLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(nameLabel)

        let countLabel = NSTextField(labelWithString: "\(serviceCount)")
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alphaValue = isHidden ? 0.5 : 1.0
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)

        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: L.leftPadding),
            dragHandle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: L.dragHandleWidth),
            dragHandle.heightAnchor.constraint(equalToConstant: 14),

            chevronButton.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: L.spacing),
            chevronButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 14),
            chevronButton.heightAnchor.constraint(equalToConstant: 14),

            eyeButton.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: L.spacing),
            eyeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            eyeButton.widthAnchor.constraint(equalToConstant: L.buttonSize),
            eyeButton.heightAnchor.constraint(equalToConstant: L.buttonSize),

            nameLabel.leadingAnchor.constraint(equalTo: eyeButton.trailingAnchor, constant: L.spacing),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            countLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 4),
            countLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -L.rightPadding)
        ])

        return container
    }

    // MARK: - Button factories

    private func createChevronButton(isCollapsed: Bool) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        let symbol = isCollapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        button.contentTintColor = .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func createEyeButton(isHidden: Bool) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        let symbol = isHidden ? "eye.slash" : "eye"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.contentTintColor = isHidden ? .tertiaryLabelColor : .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func createHeaderLabel(text: String, isHidden: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = isHidden ? .tertiaryLabelColor : .labelColor
        label.alphaValue = isHidden ? 0.5 : 1.0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Actions

    @objc func scenesChevronTapped() {
        let scenesKey = "scenes"
        if expandedSections.contains(scenesKey) {
            expandedSections.remove(scenesKey)
        } else {
            expandedSections.insert(scenesKey)
        }
        rebuild()
    }

    @objc func scenesEyeTapped() {
        PreferencesManager.shared.hideScenesSection.toggle()
        rebuild()
    }

    @objc func otherChevronTapped() {
        let otherKey = "other"
        if expandedSections.contains(otherKey) {
            expandedSections.remove(otherKey)
        } else {
            expandedSections.insert(otherKey)
        }
        rebuild()
    }

    @objc func roomChevronTapped(_ sender: NSButton) {
        guard sender.tag < orderedRooms.count else { return }
        let roomId = orderedRooms[sender.tag].uniqueIdentifier
        if expandedSections.contains(roomId) {
            expandedSections.remove(roomId)
        } else {
            expandedSections.insert(roomId)
        }
        rebuild()
    }

    @objc func roomEyeTapped(_ sender: NSButton) {
        guard sender.tag < orderedRooms.count else { return }
        let roomId = orderedRooms[sender.tag].uniqueIdentifier
        PreferencesManager.shared.toggleHidden(roomId: roomId)
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
