//
//  GroupEditorPanel.swift
//  macOSBridge
//
//  Sheet panel for creating/editing device groups
//

import AppKit

class GroupEditorPanel: NSViewController {

    private let existingGroup: DeviceGroup?
    private let menuData: MenuData

    private let nameField = NSTextField()
    private let roomPopup = NSPopUpButton()
    private var deviceCheckboxes: [(checkbox: NSButton, serviceId: String)] = []
    private var selectedDeviceIds: Set<String> = []
    private var selectedRoomId: String?
    private var showGroupSwitch: Bool = true
    private var showAsSubmenu: Bool = false
    private var groupSwitchCheckbox: NSButton!
    private var submenuCheckbox: NSButton!

    var onSave: ((DeviceGroup) -> Void)?
    var onDelete: ((DeviceGroup) -> Void)?

    init(group: DeviceGroup?, menuData: MenuData) {
        self.existingGroup = group
        self.menuData = menuData
        if let group = group {
            self.selectedDeviceIds = Set(group.deviceIds)
            self.selectedRoomId = group.roomId
            self.showGroupSwitch = group.showGroupSwitch
            self.showAsSubmenu = group.showAsSubmenu
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
        self.view = container

        // Title
        let titleLabel = NSTextField(labelWithString: existingGroup == nil ? String(localized: "group.create_title", defaultValue: "Create group", bundle: .macOSBridge) : String(localized: "group.edit_title", defaultValue: "Edit group", bundle: .macOSBridge))
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Name field
        let nameLabel = NSTextField(labelWithString: String(localized: "group.name_label", defaultValue: "Group name", bundle: .macOSBridge))
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        nameField.placeholderString = String(localized: "group.name_placeholder", defaultValue: "e.g. All bedroom lights", bundle: .macOSBridge)
        nameField.stringValue = existingGroup?.name ?? ""
        nameField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameField)

        // Room dropdown
        let roomLabel = NSTextField(labelWithString: String(localized: "group.room_label", defaultValue: "Room", bundle: .macOSBridge))
        roomLabel.font = .systemFont(ofSize: 12, weight: .medium)
        roomLabel.textColor = .secondaryLabelColor
        roomLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(roomLabel)

        roomPopup.addItem(withTitle: String(localized: "group.no_room", defaultValue: "No room (global)", bundle: .macOSBridge))
        roomPopup.menu?.addItem(NSMenuItem.separator())
        for room in menuData.rooms.sorted(by: { $0.name < $1.name }) {
            let item = NSMenuItem(title: room.name, action: nil, keyEquivalent: "")
            item.representedObject = room.uniqueIdentifier
            roomPopup.menu?.addItem(item)
        }
        roomPopup.target = self
        roomPopup.action = #selector(roomSelected(_:))
        roomPopup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(roomPopup)

        // Select existing room if editing
        if let roomId = selectedRoomId,
           let room = menuData.rooms.first(where: { $0.uniqueIdentifier == roomId }) {
            roomPopup.selectItem(withTitle: room.name)
        }

        // Display options (inline row)
        groupSwitchCheckbox = NSButton(checkboxWithTitle: String(localized: "group.group_switch", defaultValue: "Group switch", bundle: .macOSBridge), target: self, action: #selector(displayOptionToggled(_:)))
        groupSwitchCheckbox.state = showGroupSwitch ? .on : .off
        groupSwitchCheckbox.font = .systemFont(ofSize: 11)
        groupSwitchCheckbox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(groupSwitchCheckbox)

        submenuCheckbox = NSButton(checkboxWithTitle: String(localized: "group.submenu", defaultValue: "Submenu", bundle: .macOSBridge), target: self, action: #selector(displayOptionToggled(_:)))
        submenuCheckbox.state = showAsSubmenu ? .on : .off
        submenuCheckbox.font = .systemFont(ofSize: 11)
        submenuCheckbox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(submenuCheckbox)

        updateDisplayOptionStates()

        // Devices label
        let devicesLabel = NSTextField(labelWithString: String(localized: "group.select_devices", defaultValue: "Select devices", bundle: .macOSBridge))
        devicesLabel.font = .systemFont(ofSize: 12, weight: .medium)
        devicesLabel.textColor = .secondaryLabelColor
        devicesLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(devicesLabel)

        // Devices scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        let devicesStack = NSStackView()
        devicesStack.orientation = .vertical
        devicesStack.spacing = 4
        devicesStack.alignment = .leading
        devicesStack.translatesAutoresizingMaskIntoConstraints = false

        // Build device list grouped by room
        let servicesByRoom = groupServicesByRoom()
        for (roomName, services) in servicesByRoom.sorted(by: { $0.key < $1.key }) {
            // Room header
            let roomHeader = NSTextField(labelWithString: roomName)
            roomHeader.font = .systemFont(ofSize: 11, weight: .semibold)
            roomHeader.textColor = .secondaryLabelColor
            devicesStack.addArrangedSubview(roomHeader)

            // Services in room
            for service in services {
                let checkbox = NSButton(checkboxWithTitle: service.name, target: self, action: #selector(deviceToggled(_:)))
                checkbox.state = selectedDeviceIds.contains(service.uniqueIdentifier) ? .on : .off
                checkbox.font = .systemFont(ofSize: 12)
                deviceCheckboxes.append((checkbox, service.uniqueIdentifier))
                devicesStack.addArrangedSubview(checkbox)
            }

            // Spacer between rooms
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            devicesStack.addArrangedSubview(spacer)
        }

        let clipView = NSClipView()
        clipView.documentView = devicesStack
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        // Buttons
        var deleteButton: NSButton?
        if existingGroup != nil {
            let btn = NSButton(title: String(localized: "common.delete", defaultValue: "Delete", bundle: .macOSBridge), target: self, action: #selector(deleteTapped))
            btn.bezelStyle = .rounded
            btn.contentTintColor = .systemRed
            btn.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(btn)
            deleteButton = btn
        }

        let cancelButton = NSButton(title: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge), target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cancelButton)

        let saveButton = NSButton(title: existingGroup == nil ? String(localized: "common.create", defaultValue: "Create", bundle: .macOSBridge) : String(localized: "common.save", defaultValue: "Save", bundle: .macOSBridge), target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(saveButton)

        // Layout
        var constraints: [NSLayoutConstraint] = [
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            nameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            nameField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            nameField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            nameField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            roomLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 16),
            roomLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            roomPopup.topAnchor.constraint(equalTo: roomLabel.bottomAnchor, constant: 4),
            roomPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            roomPopup.widthAnchor.constraint(equalToConstant: 200),

            groupSwitchCheckbox.topAnchor.constraint(equalTo: roomPopup.bottomAnchor, constant: 12),
            groupSwitchCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            submenuCheckbox.centerYAnchor.constraint(equalTo: groupSwitchCheckbox.centerYAnchor),
            submenuCheckbox.leadingAnchor.constraint(equalTo: groupSwitchCheckbox.trailingAnchor, constant: 16),

            devicesLabel.topAnchor.constraint(equalTo: groupSwitchCheckbox.bottomAnchor, constant: 12),
            devicesLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: devicesLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -20),

            devicesStack.topAnchor.constraint(equalTo: clipView.topAnchor),
            devicesStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            devicesStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),

            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),

            saveButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ]

        if let deleteButton = deleteButton {
            constraints.append(contentsOf: [
                deleteButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
                deleteButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func groupServicesByRoom() -> [String: [ServiceData]] {
        var result: [String: [ServiceData]] = [:]

        // Get room name lookup
        let roomLookup = menuData.roomLookup()

        // Excluded types (sensors, etc.)
        let excludedTypes: Set<String> = [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]

        for accessory in menuData.accessories {
            for service in accessory.services where !excludedTypes.contains(service.serviceType) {
                let roomName = service.roomIdentifier.flatMap { roomLookup[$0] } ?? "Other"
                result[roomName, default: []].append(service)
            }
        }

        // Sort services within each room
        for (room, services) in result {
            result[room] = services.sorted { $0.name < $1.name }
        }

        return result
    }

    @objc private func roomSelected(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
            selectedRoomId = nil
        } else if let item = sender.selectedItem,
                  let roomId = item.representedObject as? String {
            selectedRoomId = roomId
        }
    }

    @objc private func displayOptionToggled(_ sender: NSButton) {
        showGroupSwitch = groupSwitchCheckbox.state == .on
        showAsSubmenu = submenuCheckbox.state == .on
        updateDisplayOptionStates()
    }

    private func updateDisplayOptionStates() {
        // When only one is checked, disable it so user can't uncheck both
        groupSwitchCheckbox.isEnabled = showAsSubmenu
        submenuCheckbox.isEnabled = showGroupSwitch
    }

    @objc private func deviceToggled(_ sender: NSButton) {
        guard let item = deviceCheckboxes.first(where: { $0.checkbox === sender }) else { return }
        if sender.state == .on {
            selectedDeviceIds.insert(item.serviceId)
        } else {
            selectedDeviceIds.remove(item.serviceId)
        }
    }

    @objc private func cancelTapped() {
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .cancel)
    }

    @objc private func deleteTapped() {
        guard let group = existingGroup else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "alert.delete_group.title", defaultValue: "Delete group?", bundle: .macOSBridge)
        alert.informativeText = String(localized: "alert.delete_group.message", defaultValue: "Are you sure you want to delete \"\(group.name)\"? This cannot be undone.", bundle: .macOSBridge)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "common.delete", defaultValue: "Delete", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onDelete?(group)
            view.window?.sheetParent?.endSheet(view.window!, returnCode: .OK)
        }
    }

    @objc private func saveTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation
        if name.isEmpty {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.name_required.title", defaultValue: "Name required", bundle: .macOSBridge)
            alert.informativeText = String(localized: "alert.name_required.message", defaultValue: "Please enter a name for the group.", bundle: .macOSBridge)
            alert.runModal()
            return
        }

        if selectedDeviceIds.isEmpty {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.no_devices_selected.title", defaultValue: "No devices selected", bundle: .macOSBridge)
            alert.informativeText = String(localized: "alert.no_devices_selected.message", defaultValue: "Please select at least one device for the group.", bundle: .macOSBridge)
            alert.runModal()
            return
        }

        // Create or update group
        let deviceIds = Array(selectedDeviceIds)
        let icon = DeviceGroup.inferIcon(for: deviceIds, in: menuData)

        let group: DeviceGroup
        if let existing = existingGroup {
            group = DeviceGroup(id: existing.id, name: name, icon: icon, deviceIds: deviceIds, roomId: selectedRoomId, showGroupSwitch: showGroupSwitch, showAsSubmenu: showAsSubmenu)
        } else {
            group = DeviceGroup(name: name, icon: icon, deviceIds: deviceIds, roomId: selectedRoomId, showGroupSwitch: showGroupSwitch, showAsSubmenu: showAsSubmenu)
        }

        onSave?(group)
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .OK)
    }

    // Window for sheet presentation
    lazy var window: NSWindow? = {
        let window = NSWindow(contentViewController: self)
        window.styleMask = [.titled]
        window.title = existingGroup == nil ? String(localized: "group.create_title", defaultValue: "Create group", bundle: .macOSBridge) : String(localized: "group.edit_title", defaultValue: "Edit group", bundle: .macOSBridge)
        return window
    }()
}
