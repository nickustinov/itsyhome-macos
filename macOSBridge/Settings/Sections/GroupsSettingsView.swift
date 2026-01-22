//
//  GroupsSettingsView.swift
//  macOSBridge
//
//  Device groups management section
//

import AppKit

class GroupsSettingsView: SettingsCard {

    private var menuData: MenuData?
    private var groupsTableView: NSTableView?
    private var groups: [DeviceGroup] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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
        // Pro badge
        let proBadge = createProBadge()
        stackView.addArrangedSubview(proBadge)
        proBadge.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 8))

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Create custom groups of devices to control multiple devices at once. Groups appear in your menu and can be controlled via deeplinks.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 16))

        // Create group button
        let createButton = NSButton(title: "Create group", target: self, action: #selector(createGroupTapped))
        createButton.bezelStyle = .rounded
        createButton.controlSize = .regular
        stackView.addArrangedSubview(createButton)

        stackView.addArrangedSubview(createSpacer(height: 12))

        // Groups list header
        if !groups.isEmpty {
            let header = createSectionHeader("Your groups")
            stackView.addArrangedSubview(header)

            // Groups list
            let listContainer = createGroupsList()
            stackView.addArrangedSubview(listContainer)
            listContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        } else {
            let emptyLabel = createLabel("No groups yet. Create your first group to get started.", style: .caption)
            emptyLabel.textColor = .tertiaryLabelColor
            stackView.addArrangedSubview(emptyLabel)
        }

        stackView.addArrangedSubview(createSpacer(height: 16))
    }

    private func createGroupsList() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        for group in groups {
            let row = createGroupRow(group)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        return container
    }

    private func createGroupRow(_ group: DeviceGroup) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.97, alpha: 1.0).cgColor
        container.layer?.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

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

        // Edit button
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editGroupTapped(_:)))
        editButton.bezelStyle = .inline
        editButton.controlSize = .small
        editButton.tag = groups.firstIndex(where: { $0.id == group.id }) ?? 0
        editButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(editButton)

        // Delete button
        let deleteButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteGroupTapped(_:)))
        deleteButton.bezelStyle = .inline
        deleteButton.isBordered = false
        deleteButton.contentTintColor = .systemRed
        deleteButton.tag = groups.firstIndex(where: { $0.id == group.id }) ?? 0
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 50),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
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
            editButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func createProBadge() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.95, green: 0.92, blue: 1.0, alpha: 1.0).cgColor
        container.layer?.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .horizontal
        content.spacing = 8
        content.alignment = .centerY
        content.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Pro")
        iconView.contentTintColor = .systemPurple
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let label = NSTextField(labelWithString: "Itsyhome Pro feature")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor

        content.addArrangedSubview(iconView)
        content.addArrangedSubview(label)

        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }

    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func createSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func rebuildContent() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
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
