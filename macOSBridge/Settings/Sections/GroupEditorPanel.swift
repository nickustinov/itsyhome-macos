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
    private var deviceCheckboxes: [(checkbox: NSButton, serviceId: String)] = []
    private var selectedDeviceIds: Set<String> = []

    var onSave: ((DeviceGroup) -> Void)?

    init(group: DeviceGroup?, menuData: MenuData) {
        self.existingGroup = group
        self.menuData = menuData
        if let group = group {
            self.selectedDeviceIds = Set(group.deviceIds)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 450))
        self.view = container

        // Title
        let titleLabel = NSTextField(labelWithString: existingGroup == nil ? "Create group" : "Edit group")
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Name field
        let nameLabel = NSTextField(labelWithString: "Group name")
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        nameField.placeholderString = "e.g. All bedroom lights"
        nameField.stringValue = existingGroup?.name ?? ""
        nameField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameField)

        // Devices label
        let devicesLabel = NSTextField(labelWithString: "Select devices")
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
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cancelButton)

        let saveButton = NSButton(title: existingGroup == nil ? "Create" : "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(saveButton)

        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            nameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            nameField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            nameField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            nameField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            devicesLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 16),
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
        ])
    }

    private func groupServicesByRoom() -> [String: [ServiceData]] {
        var result: [String: [ServiceData]] = [:]

        // Get room name lookup
        let roomLookup = Dictionary(uniqueKeysWithValues: menuData.rooms.map { ($0.uniqueIdentifier, $0.name) })

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

    @objc private func saveTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation
        if name.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Name required"
            alert.informativeText = "Please enter a name for the group."
            alert.runModal()
            return
        }

        if selectedDeviceIds.isEmpty {
            let alert = NSAlert()
            alert.messageText = "No devices selected"
            alert.informativeText = "Please select at least one device for the group."
            alert.runModal()
            return
        }

        // Create or update group
        let deviceIds = Array(selectedDeviceIds)
        let icon = DeviceGroup.inferIcon(for: deviceIds, in: menuData)

        let group: DeviceGroup
        if let existing = existingGroup {
            group = DeviceGroup(id: existing.id, name: name, icon: icon, deviceIds: deviceIds)
        } else {
            group = DeviceGroup(name: name, icon: icon, deviceIds: deviceIds)
        }

        onSave?(group)
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .OK)
    }

    // Window for sheet presentation
    lazy var window: NSWindow? = {
        let window = NSWindow(contentViewController: self)
        window.styleMask = [.titled]
        window.title = existingGroup == nil ? "Create group" : "Edit group"
        return window
    }()
}
