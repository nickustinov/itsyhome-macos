//
//  HomeKitBridgeSection.swift
//  macOSBridge
//
//  Settings pane for the virtual HomeKit bridge: a master enable toggle, the
//  pairing setup code + status + reset, and the managed list of virtual devices.
//  Each device has a state toggle button to flip its reading and watch it move
//  in Apple Home + the events feed. Pairing instructions live behind an info
//  popover (one-time content), and the add/edit form replaces the list inline.
//  Rooms are assigned in Apple Home after pairing.
//
import AppKit

class HomeKitBridgeSection: SettingsCard {

    private let enableSwitch = NSSwitch()
    private var statusLabel: NSTextField!
    private var codeLabel: NSTextField!

    private var devicesHeader: NSView!
    private let devicesStack = NSStackView()

    // Inline add / edit form (replaces the device list while open)
    private let addContainer = NSView()
    private let nameField = NSTextField()
    private let typePopUp = NSPopUpButton()
    private let rolePopUp = NSPopUpButton()
    private var roleRow: NSView!
    private var criticalNote: NSTextField!
    private var addErrorLabel: NSTextField!
    private var formTitleLabel: NSTextField!
    private var editingDeviceId: UUID?

    private let orderedTypes: [VirtualSensorType] =
        [.contact, .motion, .occupancy, .leak, .smoke, .carbonMonoxide, .carbonDioxide]
    private let orderedRoles: [ContactRole] = [.generic, .door, .window]

    private lazy var instructionsPopover: NSPopover = makeInstructionsPopover()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        observeNotifications()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Layout

    private func setupContent() {
        if !ProStatusCache.shared.isPro {
            stackView.addArrangedSubview(Self.createProBanner())
            stackView.addArrangedSubview(createSpacer(height: 8))
        }

        let desc = wrappingLabel(
            "Publish virtual sensors to Apple Home over HomeKit. Rooms are assigned in Apple Home after pairing.")
        stackView.addArrangedSubview(desc)
        stackView.addArrangedSubview(createSpacer(height: 10))

        stackView.addArrangedSubview(createEnableRow())
        stackView.addArrangedSubview(createSpacer(height: 8))
        stackView.addArrangedSubview(createStatusContent())
        stackView.addArrangedSubview(createSpacer(height: 14))

        devicesHeader = createDevicesHeader()
        stackView.addArrangedSubview(devicesHeader)
        devicesHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        devicesStack.orientation = .vertical
        devicesStack.spacing = 6
        devicesStack.alignment = .leading
        devicesStack.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(devicesStack)
        devicesStack.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        setupAddForm()
        stackView.addArrangedSubview(addContainer)
        addContainer.isHidden = true
        addContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        enableSwitch.state = PreferencesManager.shared.virtualBridgeEnabled ? .on : .off
        rebuildDevicesList()
        updateStatusDisplay()
    }

    private func createEnableRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = createLabel("Enable HomeKit Bridge", style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false

        enableSwitch.controlSize = .mini
        enableSwitch.target = self
        enableSwitch.action = #selector(enableSwitchChanged)
        enableSwitch.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(enableSwitch)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 36),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: enableSwitch.leadingAnchor, constant: -16),
            enableSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            enableSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func createStatusContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading

        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .centerY
        let statusTitle = createLabel("Status:", style: .body)
        statusTitle.translatesAutoresizingMaskIntoConstraints = false
        statusTitle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        statusLabel = createLabel("Stopped", style: .body)
        statusRow.addArrangedSubview(statusTitle)
        statusRow.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(statusRow)

        // Setup code, an info affordance for the (one-time) pairing steps, and reset.
        let codeRow = NSStackView()
        codeRow.orientation = .horizontal
        codeRow.spacing = 8
        codeRow.alignment = .centerY
        let codeTitle = createLabel("Setup code:", style: .body)
        codeTitle.translatesAutoresizingMaskIntoConstraints = false
        codeTitle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        codeLabel = createLabel(PreferencesManager.shared.virtualBridgeSetupCode, style: .code)

        let infoButton = NSButton(title: "", target: self, action: #selector(showInstructions(_:)))
        infoButton.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "How to pair")
        infoButton.imagePosition = .imageOnly
        infoButton.isBordered = false
        infoButton.contentTintColor = .secondaryLabelColor
        infoButton.toolTip = "How to add this bridge to Apple Home"

        let resetButton = NSButton(title: "Reset Pairing", target: self, action: #selector(resetPairingAction))
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .small

        codeRow.addArrangedSubview(codeTitle)
        codeRow.addArrangedSubview(codeLabel)
        codeRow.addArrangedSubview(infoButton)
        codeRow.addArrangedSubview(NSView())  // spacer pushes reset to the right
        codeRow.addArrangedSubview(resetButton)
        stack.addArrangedSubview(codeRow)
        codeRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return stack
    }

    private func createDevicesHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let title = createLabel("Virtual devices", style: .sectionHeader)
        row.addArrangedSubview(title)
        row.addArrangedSubview(NSView())  // spacer

        let addButton = NSButton(title: "Add Device", target: self, action: #selector(showAddForm))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small
        row.addArrangedSubview(addButton)

        return row
    }

    // MARK: - Add / edit form

    private func setupAddForm() {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.spacing = 8
        panel.alignment = .leading
        panel.translatesAutoresizingMaskIntoConstraints = false

        formTitleLabel = createLabel("New device", style: .sectionHeader)
        panel.addArrangedSubview(formTitleLabel)

        nameField.placeholderString = "Name (e.g. Front Door)"
        nameField.controlSize = .regular
        panel.addArrangedSubview(labeledRow("Name", nameField))

        for type in orderedTypes { typePopUp.addItem(withTitle: displayName(type)) }
        typePopUp.controlSize = .regular
        typePopUp.target = self
        typePopUp.action = #selector(typeChanged)
        panel.addArrangedSubview(labeledRow("Type", typePopUp))

        for role in orderedRoles { rolePopUp.addItem(withTitle: displayName(role)) }
        rolePopUp.controlSize = .regular
        roleRow = labeledRow("Role", rolePopUp)
        panel.addArrangedSubview(roleRow)

        criticalNote = wrappingLabel("")
        criticalNote.textColor = .systemOrange
        panel.addArrangedSubview(criticalNote)

        let note = wrappingLabel("The room is chosen in the Apple Home app after pairing.")
        note.textColor = .tertiaryLabelColor
        panel.addArrangedSubview(note)

        addErrorLabel = createLabel("", style: .caption)
        addErrorLabel.textColor = .systemRed
        panel.addArrangedSubview(addErrorLabel)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.addArrangedSubview(NSView())  // spacer
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelAdd))
        cancel.bezelStyle = .rounded
        cancel.controlSize = .small
        cancel.keyEquivalent = "\u{1b}"  // Esc
        buttons.addArrangedSubview(cancel)
        let save = NSButton(title: "Save", target: self, action: #selector(saveDevice))
        save.bezelStyle = .rounded
        save.controlSize = .small
        save.keyEquivalent = "\r"
        buttons.addArrangedSubview(save)
        panel.addArrangedSubview(buttons)
        buttons.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        addContainer.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: addContainer.topAnchor),
            panel.leadingAnchor.constraint(equalTo: addContainer.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: addContainer.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: addContainer.bottomAnchor)
        ])
    }

    private func labeledRow(_ label: String, _ control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        let l = createLabel(label, style: .body)
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: 110).isActive = true
        control.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(l)
        row.addArrangedSubview(control)
        return row
    }

    /// Swap the device list for the add/edit form (and back).
    private func setFormVisible(_ visible: Bool) {
        devicesHeader.isHidden = visible
        devicesStack.isHidden = visible
        addContainer.isHidden = !visible
    }

    // MARK: - Device list

    private func rebuildDevicesList() {
        for view in devicesStack.arrangedSubviews {
            devicesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let devices = VirtualDeviceStore.shared.devices
        if devices.isEmpty {
            devicesStack.addArrangedSubview(createLabel("No virtual devices yet.", style: .caption))
            return
        }
        for device in devices {
            let row = createDeviceRow(device)
            devicesStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: devicesStack.widthAnchor).isActive = true
        }
    }

    private func createDeviceRow(_ device: VirtualDevice) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let name = createLabel(device.name, style: .body)
        row.addArrangedSubview(name)

        let detail = createLabel(displayName(device.type), style: .caption)
        detail.textColor = .secondaryLabelColor
        row.addArrangedSubview(detail)

        row.addArrangedSubview(NSView())  // spacer

        // State toggle BUTTON - clicking flips the reading (not a power switch).
        let stateButton = NSButton(title: device.type.stateWord(on: device.state),
                                   target: self, action: #selector(deviceToggled(_:)))
        stateButton.bezelStyle = .rounded
        stateButton.controlSize = .small
        stateButton.toolTip = "Toggle state"
        stateButton.identifier = NSUserInterfaceItemIdentifier(device.id.uuidString)
        stateButton.contentTintColor = device.state ? .controlAccentColor : .secondaryLabelColor
        stateButton.translatesAutoresizingMaskIntoConstraints = false
        stateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
        row.addArrangedSubview(stateButton)

        row.addArrangedSubview(iconButton("pencil", action: #selector(editDeviceAction(_:)), id: device.id))
        row.addArrangedSubview(iconButton("xmark.circle.fill", action: #selector(removeDeviceAction(_:)), id: device.id))

        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return row
    }

    private func iconButton(_ symbol: String, action: Selector, id: UUID) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 20).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20).isActive = true
        button.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        return button
    }

    // MARK: - Actions

    @objc private func enableSwitchChanged(_ sender: NSSwitch) {
        let enabled = sender.state == .on
        PreferencesManager.shared.virtualBridgeEnabled = enabled
        if enabled {
            VirtualBridgeService.shared.startIfEnabled()
        } else {
            Task { await VirtualBridgeService.shared.stop() }
        }
    }

    @objc private func showInstructions(_ sender: NSButton) {
        instructionsPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func showAddForm() {
        editingDeviceId = nil
        formTitleLabel.stringValue = "New device"
        nameField.stringValue = ""
        typePopUp.selectItem(at: 0)
        rolePopUp.selectItem(at: 0)
        addErrorLabel.stringValue = ""
        typeChanged()
        setFormVisible(true)
        window?.makeFirstResponder(nameField)
    }

    private func showEditForm(_ device: VirtualDevice) {
        editingDeviceId = device.id
        formTitleLabel.stringValue = "Edit device"
        nameField.stringValue = device.name
        if let idx = orderedTypes.firstIndex(of: device.type) { typePopUp.selectItem(at: idx) }
        if let role = device.role, let idx = orderedRoles.firstIndex(of: role) {
            rolePopUp.selectItem(at: idx)
        } else {
            rolePopUp.selectItem(at: 0)
        }
        addErrorLabel.stringValue = ""
        typeChanged()
        setFormVisible(true)
        window?.makeFirstResponder(nameField)
    }

    @objc private func cancelAdd() {
        editingDeviceId = nil
        setFormVisible(false)
    }

    /// Role only applies to contact; the safety sensors carry a critical-alert note.
    @objc private func typeChanged() {
        let type = orderedTypes[typePopUp.indexOfSelectedItem]
        roleRow.isHidden = (type != .contact)
        criticalNote.isHidden = !type.isCriticalAlertType
        criticalNote.stringValue = type.isCriticalAlertType
            ? "Apple Home can raise critical alerts for \(displayName(type)) sensors."
            : ""
    }

    @objc private func saveDevice() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { addErrorLabel.stringValue = "Name is required."; return }
        let type = orderedTypes[typePopUp.indexOfSelectedItem]
        let role = orderedRoles[rolePopUp.indexOfSelectedItem]

        if let editId = editingDeviceId, var device = VirtualDeviceStore.shared.device(id: editId) {
            let clash = VirtualDeviceStore.shared.devices.contains {
                $0.id != editId && $0.name.lowercased() == name.lowercased()
            }
            if clash { addErrorLabel.stringValue = "A device named \"\(name)\" already exists."; return }
            device.name = name
            device.type = type
            device.role = type == .contact ? role : nil
            VirtualDeviceStore.shared.update(device)
            editingDeviceId = nil
            Task { await VirtualBridgeService.shared.updateDevice(device) }
            setFormVisible(false)
            rebuildDevicesList()
        } else {
            do {
                let device = try VirtualDeviceStore.shared.add(
                    name: name, type: type, role: role, room: nil)
                Task { await VirtualBridgeService.shared.addDevice(device) }
                setFormVisible(false)
                rebuildDevicesList()
            } catch {
                addErrorLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc private func removeDeviceAction(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let id = UUID(uuidString: idString),
              let device = VirtualDeviceStore.shared.device(id: id) else { return }

        let usedBy = AutomationStore.shared.automations.filter { automation in
            automation.actions.contains { if case .setVirtualSensor(let a) = $0 { return a.deviceId == id }; return false }
        }
        let alert = NSAlert()
        alert.messageText = "Delete \"\(device.name)\"?"
        if usedBy.isEmpty {
            alert.informativeText = "This virtual sensor will be removed from Apple Home."
        } else {
            let names = usedBy.map { "\u{2022} \($0.name)" }.joined(separator: "\n")
            let plural = usedBy.count == 1
            alert.informativeText = "This sensor is used by \(usedBy.count) automation\(plural ? "" : "s"):\n\(names)\n\nDeleting it will break \(plural ? "that automation" : "those automations")."
        }
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let aid = device.aid
        VirtualDeviceStore.shared.remove(id: id)
        Task { await VirtualBridgeService.shared.removeDevice(aid: aid) }
        AutomationEngine.shared.reload()   // drop/stop any automation that depended on it
        rebuildDevicesList()
    }

    @objc private func editDeviceAction(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let id = UUID(uuidString: idString),
              let device = VirtualDeviceStore.shared.device(id: id) else { return }
        showEditForm(device)
    }

    @objc private func deviceToggled(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let id = UUID(uuidString: idString),
              let device = VirtualDeviceStore.shared.device(id: id) else { return }
        let newState = !device.state
        VirtualControl.setState(device, on: newState)
        sender.title = device.type.stateWord(on: newState)
        sender.contentTintColor = newState ? .controlAccentColor : .secondaryLabelColor
    }

    @objc private func resetPairingAction() {
        let alert = NSAlert()
        alert.messageText = "Reset HomeKit pairing?"
        alert.informativeText = "This unpairs the bridge and generates a new setup code. Remove \"Itsyhome Bridge\" from the Apple Home app, then add it again with the new code."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            await VirtualBridgeService.shared.resetPairing()
            await MainActor.run {
                self.codeLabel.stringValue = PreferencesManager.shared.virtualBridgeSetupCode
                self.updateStatusDisplay()
            }
        }
    }

    // MARK: - Status

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(statusDidChange),
            name: VirtualBridgeService.statusChangedNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeDidChange),
            name: VirtualDeviceStore.didChangeNotification, object: nil)
    }

    @objc private func statusDidChange() {
        DispatchQueue.main.async { [weak self] in self?.updateStatusDisplay() }
    }

    @objc private func storeDidChange() {
        DispatchQueue.main.async { [weak self] in self?.rebuildDevicesList() }
    }

    private func updateStatusDisplay() {
        switch VirtualBridgeService.shared.status {
        case .stopped:
            statusLabel.stringValue = "Stopped"
            statusLabel.textColor = .secondaryLabelColor
        case .running:
            statusLabel.stringValue = "Running"
            statusLabel.textColor = .systemGreen
        case .error(let message):
            statusLabel.stringValue = "Error: \(message)"
            statusLabel.textColor = .systemRed
        }
    }

    // MARK: - Instructions popover

    private func makeInstructionsPopover() -> NSPopover {
        let pop = NSPopover()
        pop.behavior = .transient

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(createLabel("Add to Apple Home", style: .sectionHeader))
        let steps = [
            "1. Add a device and enable the bridge.",
            "2. In the Home app: Add Accessory, then More options.",
            "3. Pick \u{201C}Itsyhome Bridge\u{201D} and enter the setup code.",
            "4. Assign each device to a room in the Home app."
        ]
        for step in steps {
            let l = createLabel(step, style: .body)
            l.lineBreakMode = .byWordWrapping
            l.maximumNumberOfLines = 0
            l.preferredMaxLayoutWidth = 280
            stack.addArrangedSubview(l)
        }

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        let vc = NSViewController()
        vc.view = container
        pop.contentViewController = vc
        pop.contentSize = NSSize(width: 320, height: 188)
        return pop
    }

    // MARK: - Helpers

    private func wrappingLabel(_ text: String) -> NSTextField {
        let label = createLabel(text, style: .caption)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 460
        return label
    }

    private func displayName(_ type: VirtualSensorType) -> String {
        switch type {
        case .contact: return "Contact"
        case .motion: return "Motion"
        case .occupancy: return "Occupancy"
        case .leak: return "Leak"
        case .smoke: return "Smoke"
        case .carbonMonoxide: return "Carbon Monoxide"
        case .carbonDioxide: return "Carbon Dioxide"
        }
    }

    private func displayName(_ role: ContactRole) -> String {
        switch role {
        case .generic: return "Generic"
        case .door: return "Door"
        case .window: return "Window"
        }
    }

    private func createSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }
}
