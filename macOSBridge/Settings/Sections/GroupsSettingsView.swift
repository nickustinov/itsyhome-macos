//
//  GroupsSettingsView.swift
//  macOSBridge
//
//  Device groups management section
//

import AppKit

extension NSPasteboard.PasteboardType {
    static let groupItem = NSPasteboard.PasteboardType("com.itsyhome.groupItem")
}

class GroupsSettingsView: NSView {

    private let stackView = NSStackView()
    private var menuData: MenuData?
    private var groupsTableView: NSTableView?
    private var groups: [DeviceGroup] = []

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

        loadGroups()
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with data: MenuData) {
        self.menuData = data
    }

    private func loadGroups() {
        groups = PreferencesManager.shared.deviceGroups
    }

    private func setupContent() {
        let isPro = ProStatusCache.shared.isPro

        // Pro banner (only shown for non-Pro users)
        if !isPro {
            let banner = SettingsCard.createProBanner()
            stackView.addArrangedSubview(banner)
            banner.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            addSpacer(height: 12)
        }

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Create custom groups of devices to control multiple devices at once. Groups appear in your menu and can be controlled via deeplinks.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        addSpacer(height: 16)

        // Create group button (disabled for non-pro)
        let createButton = NSButton(title: "Create group", target: self, action: #selector(createGroupTapped))
        createButton.bezelStyle = .rounded
        createButton.controlSize = .regular
        createButton.isEnabled = isPro
        createButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(createButton)
        addSpacer(height: 16)

        // Groups section
        if !groups.isEmpty {
            let header = AccessorySectionHeader(title: "Your groups")
            addView(header, height: 32)
            addSpacer(height: 4)

            // Groups table with drag/drop (50 row height + 4 spacing between rows)
            let tableHeight = CGFloat(groups.count) * 50 + CGFloat(max(0, groups.count - 1)) * 4
            let tableContainer = createGroupsTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
        } else {
            let emptyLabel = NSTextField(labelWithString: "No groups yet. Create your first group to get started.")
            emptyLabel.font = .systemFont(ofSize: 11)
            emptyLabel.textColor = .tertiaryLabelColor
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(emptyLabel)
        }

        addSpacer(height: 16)
    }

    private func createGroupsTable(height: CGFloat) -> NSView {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 50
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.gridStyleMask = []
        tableView.registerForDraggedTypes([.groupItem])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        self.groupsTableView = tableView

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Helpers

    private func addView(_ view: NSView, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func rebuildContent() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        groupsTableView = nil
        loadGroups()
        setupContent()
    }

    // MARK: - Actions

    @objc private func createGroupTapped() {
        showGroupEditor(group: nil)
    }

    @objc private func editGroupTapped(_ sender: NSButton) {
        guard sender.tag < groups.count else { return }
        let group = groups[sender.tag]
        showGroupEditor(group: group)
    }

    @objc private func deleteGroupTapped(_ sender: NSButton) {
        guard sender.tag < groups.count else { return }
        let group = groups[sender.tag]

        let alert = NSAlert()
        alert.messageText = "Delete group?"
        alert.informativeText = "Are you sure you want to delete \"\(group.name)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            PreferencesManager.shared.deleteDeviceGroup(id: group.id)
            rebuildContent()
        }
    }

    private func showGroupEditor(group: DeviceGroup?) {
        guard let data = menuData else { return }

        let editor = GroupEditorPanel(group: group, menuData: data)
        editor.onSave = { [weak self] savedGroup in
            if group == nil {
                PreferencesManager.shared.addDeviceGroup(savedGroup)
            } else {
                PreferencesManager.shared.updateDeviceGroup(savedGroup)
            }
            self?.rebuildContent()
        }

        guard let window = self.window else { return }
        window.beginSheet(editor.window!) { _ in }
    }
}

// MARK: - Table delegate

extension GroupsSettingsView: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        groups.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let group = groups[row]
        return createGroupRowView(group: group, row: row)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        50
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isGroupRowStyle = false
        return rowView
    }

    private func createGroupRowView(group: DeviceGroup, row: Int) -> NSView {
        let isPro = ProStatusCache.shared.isPro
        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Drag handle (hidden for non-pro)
        let dragHandle = DragHandleView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.isHidden = !isPro
        container.addSubview(dragHandle)

        // Icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: group.icon, accessibilityDescription: group.name)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        // Name and device count
        let nameLabel = NSTextField(labelWithString: group.name)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let countLabel = NSTextField(labelWithString: "\(group.deviceIds.count) device\(group.deviceIds.count == 1 ? "" : "s")")
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)

        // Shortcut button (disabled for non-pro)
        let shortcutButton = ShortcutButton(frame: .zero)
        shortcutButton.shortcut = PreferencesManager.shared.shortcut(for: group.id)
        shortcutButton.isEnabled = isPro
        shortcutButton.onShortcutRecorded = { shortcut in
            PreferencesManager.shared.setShortcut(shortcut, for: group.id)
        }
        shortcutButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(shortcutButton)

        // Edit button (disabled for non-pro)
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editGroupTapped(_:)))
        editButton.bezelStyle = .rounded
        editButton.controlSize = .regular
        editButton.tag = row
        editButton.isEnabled = isPro
        editButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(editButton)

        // Delete button (disabled for non-pro)
        let deleteButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteGroupTapped(_:)))
        deleteButton.bezelStyle = .inline
        deleteButton.isBordered = false
        deleteButton.contentTintColor = isPro ? .systemRed : .tertiaryLabelColor
        deleteButton.tag = row
        deleteButton.isEnabled = isPro
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            dragHandle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 12),
            dragHandle.heightAnchor.constraint(equalToConstant: 20),

            iconView.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            countLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            countLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            deleteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),

            editButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            editButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            shortcutButton.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -8),
            shortcutButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    // MARK: - Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        // Disable drag for non-pro users
        guard ProStatusCache.shared.isPro else { return nil }

        let group = groups[row]
        let pb = NSPasteboardItem()
        pb.setString(group.id, forType: .groupItem)
        return pb
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let pb = items.first,
              let draggedId = pb.string(forType: .groupItem),
              let originalRow = groups.firstIndex(where: { $0.id == draggedId }) else {
            return false
        }

        var newRow = row
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveDeviceGroup(from: originalRow, to: newRow)
        loadGroups()

        tableView.beginUpdates()
        tableView.moveRow(at: originalRow, to: newRow)
        tableView.endUpdates()

        return true
    }
}
