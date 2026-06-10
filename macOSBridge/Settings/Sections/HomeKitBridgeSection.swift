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
    private var devicesBox: NSView!

    // Inline add / edit form (replaces the device list while open)
    private var formBox: NSView!
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

    /// Embedded below the bridge content - automations belong to the bridge.
    private let automationsSection = AutomationsSection()

    /// Rebuilt on each show so the QR code always reflects the current setup code.
    private var instructionsPopover: NSPopover?

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
            stackView.addArrangedSubview(createSpacer(height: 12))
        }

        let desc = wrappingLabel(
            String(localized: "settings.homekit_bridge.description", defaultValue: "Publish virtual sensors to Apple Home over HomeKit. Rooms are assigned in Apple Home after pairing.", bundle: .macOSBridge))
        stackView.addArrangedSubview(desc)
        desc.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        stackView.addArrangedSubview(createSpacer(height: 4))

        let enableBox = createCardBox()
        addContentToBox(enableBox, content: createEnableRow())
        stackView.addArrangedSubview(enableBox)
        enableBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 8))

        let statusBox = createCardBox()
        addContentToBox(statusBox, content: createStatusContent())
        stackView.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 12))

        devicesHeader = createDevicesHeader()
        stackView.addArrangedSubview(devicesHeader)
        devicesHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        devicesStack.orientation = .vertical
        devicesStack.spacing = 6
        devicesStack.alignment = .leading
        devicesStack.translatesAutoresizingMaskIntoConstraints = false
        devicesBox = createCardBox()
        addContentToBox(devicesBox, content: devicesStack)
        stackView.addArrangedSubview(devicesBox)
        devicesBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        formBox = createCardBox()
        setupAddForm()
        stackView.addArrangedSubview(formBox)
        formBox.isHidden = true
        formBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Automations drive the virtual sensors published by this bridge, so
        // they live at the bottom of the same pane rather than in their own tab.
        stackView.addArrangedSubview(createSpacer(height: 16))
        stackView.addArrangedSubview(automationsSection)
        automationsSection.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        enableSwitch.state = PreferencesManager.shared.virtualBridgeEnabled ? .on : .off
        rebuildDevicesList()
        updateStatusDisplay()
    }

    /// Forward live accessory data to the embedded automations section (its
    /// trigger picker lists HomeKit sensors).
    func configure(with data: MenuData) {
        automationsSection.configure(with: data)
    }

    private func createEnableRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = createLabel(String(localized: "settings.homekit_bridge.enable_toggle", defaultValue: "Enable HomeKit bridge", bundle: .macOSBridge), style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false

        enableSwitch.controlSize = .mini
        enableSwitch.target = self
        enableSwitch.action = #selector(enableSwitchChanged)
        enableSwitch.isEnabled = ProStatusCache.shared.isPro
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
        let statusTitle = createLabel(String(localized: "settings.homekit_bridge.status_label", defaultValue: "Status:", bundle: .macOSBridge), style: .body)
        statusTitle.translatesAutoresizingMaskIntoConstraints = false
        statusTitle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        statusLabel = createLabel(String(localized: "settings.homekit_bridge.status.stopped", defaultValue: "Stopped", bundle: .macOSBridge), style: .body)
        statusRow.addArrangedSubview(statusTitle)
        statusRow.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(statusRow)

        // Setup code, an info affordance for the (one-time) pairing steps, and reset.
        let codeRow = NSStackView()
        codeRow.orientation = .horizontal
        codeRow.spacing = 8
        codeRow.alignment = .centerY
        let codeTitle = createLabel(String(localized: "settings.homekit_bridge.setup_code_label", defaultValue: "Setup code:", bundle: .macOSBridge), style: .body)
        codeTitle.translatesAutoresizingMaskIntoConstraints = false
        codeTitle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        codeLabel = createLabel(PreferencesManager.shared.virtualBridgeSetupCode, style: .code)

        let infoButton = NSButton(title: "", target: self, action: #selector(showInstructions(_:)))
        infoButton.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: String(localized: "settings.homekit_bridge.info.accessibility", defaultValue: "How to pair", bundle: .macOSBridge))
        infoButton.imagePosition = .imageOnly
        infoButton.isBordered = false
        infoButton.contentTintColor = .secondaryLabelColor
        infoButton.toolTip = String(localized: "settings.homekit_bridge.info.tooltip", defaultValue: "How to add this bridge to Apple Home", bundle: .macOSBridge)

        let resetButton = NSButton(title: String(localized: "settings.homekit_bridge.reset_pairing_button", defaultValue: "Reset pairing", bundle: .macOSBridge), target: self, action: #selector(resetPairingAction))
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

        let title = createLabel(String(localized: "settings.homekit_bridge.devices_header", defaultValue: "Virtual devices", bundle: .macOSBridge), style: .sectionHeader)
        row.addArrangedSubview(title)
        row.addArrangedSubview(NSView())  // spacer

        let addButton = NSButton(title: String(localized: "settings.homekit_bridge.add_device_button", defaultValue: "Add device", bundle: .macOSBridge), target: self, action: #selector(showAddForm))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small
        row.addArrangedSubview(addButton)

        row.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return row
    }

    // MARK: - Add / edit form

    private func setupAddForm() {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.spacing = 8
        panel.alignment = .leading
        panel.translatesAutoresizingMaskIntoConstraints = false

        formTitleLabel = createLabel(String(localized: "settings.homekit_bridge.form.new_title", defaultValue: "New device", bundle: .macOSBridge), style: .sectionHeader)
        panel.addArrangedSubview(formTitleLabel)

        nameField.placeholderString = String(localized: "settings.homekit_bridge.form.name_placeholder", defaultValue: "Name (e.g. Front Door)", bundle: .macOSBridge)
        nameField.controlSize = .regular
        panel.addArrangedSubview(labeledRow(String(localized: "settings.homekit_bridge.form.name_label", defaultValue: "Name", bundle: .macOSBridge), nameField))

        for type in orderedTypes { typePopUp.addItem(withTitle: displayName(type)) }
        typePopUp.controlSize = .regular
        typePopUp.target = self
        typePopUp.action = #selector(typeChanged)
        panel.addArrangedSubview(labeledRow(String(localized: "settings.homekit_bridge.form.type_label", defaultValue: "Type", bundle: .macOSBridge), typePopUp))

        for role in orderedRoles { rolePopUp.addItem(withTitle: displayName(role)) }
        rolePopUp.controlSize = .regular
        roleRow = labeledRow(String(localized: "settings.homekit_bridge.form.role_label", defaultValue: "Role", bundle: .macOSBridge), rolePopUp)
        panel.addArrangedSubview(roleRow)

        criticalNote = wrappingLabel("")
        criticalNote.textColor = .systemOrange
        panel.addArrangedSubview(criticalNote)

        let note = wrappingLabel(String(localized: "settings.homekit_bridge.form.room_note", defaultValue: "The room is chosen in the Apple Home app after pairing.", bundle: .macOSBridge))
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
        let cancel = NSButton(title: String(localized: "settings.homekit_bridge.form.cancel_button", defaultValue: "Cancel", bundle: .macOSBridge), target: self, action: #selector(cancelAdd))
        cancel.bezelStyle = .rounded
        cancel.controlSize = .small
        cancel.keyEquivalent = "\u{1b}"  // Esc
        buttons.addArrangedSubview(cancel)
        let save = NSButton(title: String(localized: "settings.homekit_bridge.form.save_button", defaultValue: "Save", bundle: .macOSBridge), target: self, action: #selector(saveDevice))
        save.bezelStyle = .rounded
        save.controlSize = .small
        save.keyEquivalent = "\r"
        buttons.addArrangedSubview(save)
        panel.addArrangedSubview(buttons)
        buttons.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        addContentToBox(formBox, content: panel)
    }

    /// Swap the device list for the add/edit form (and back).
    private func setFormVisible(_ visible: Bool) {
        devicesHeader.isHidden = visible
        devicesBox.isHidden = visible
        formBox.isHidden = !visible
    }

    // MARK: - Device list

    private func rebuildDevicesList() {
        for view in devicesStack.arrangedSubviews {
            devicesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let devices = VirtualDeviceStore.shared.devices
        if devices.isEmpty {
            devicesStack.addArrangedSubview(createLabel(String(localized: "settings.homekit_bridge.devices_empty", defaultValue: "No virtual devices yet.", bundle: .macOSBridge), style: .caption))
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
        stateButton.toolTip = String(localized: "settings.homekit_bridge.toggle_state.tooltip", defaultValue: "Toggle state", bundle: .macOSBridge)
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
        // start() is a silent no-op with zero devices (no status notification
        // fires), so refresh here to surface the "waiting for devices" hint.
        updateStatusDisplay()
    }

    @objc private func showInstructions(_ sender: NSButton) {
        let popover = makeInstructionsPopover()
        instructionsPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func showAddForm() {
        editingDeviceId = nil
        formTitleLabel.stringValue = String(localized: "settings.homekit_bridge.form.new_title", defaultValue: "New device", bundle: .macOSBridge)
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
        formTitleLabel.stringValue = String(localized: "settings.homekit_bridge.form.edit_title", defaultValue: "Edit device", bundle: .macOSBridge)
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
            ? String(localized: "settings.homekit_bridge.form.critical_note", defaultValue: "Apple Home can raise critical alerts for \(displayName(type)) sensors.", bundle: .macOSBridge)
            : ""
    }

    @objc private func saveDevice() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { addErrorLabel.stringValue = String(localized: "settings.homekit_bridge.form.error.name_required", defaultValue: "Name is required.", bundle: .macOSBridge); return }
        let type = orderedTypes[typePopUp.indexOfSelectedItem]
        let role = orderedRoles[rolePopUp.indexOfSelectedItem]

        if let editId = editingDeviceId, var device = VirtualDeviceStore.shared.device(id: editId) {
            let clash = VirtualDeviceStore.shared.devices.contains {
                $0.id != editId && $0.name.lowercased() == name.lowercased()
            }
            if clash { addErrorLabel.stringValue = String(localized: "error.virtual_device.duplicate_name", defaultValue: "A device named \"\(name)\" already exists.", bundle: .macOSBridge); return }
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
        alert.messageText = String(localized: "settings.homekit_bridge.delete_alert.title", defaultValue: "Delete \"\(device.name)\"?", bundle: .macOSBridge)
        if usedBy.isEmpty {
            alert.informativeText = String(localized: "settings.homekit_bridge.delete_alert.message", defaultValue: "This virtual sensor will be removed from Apple Home.", bundle: .macOSBridge)
        } else {
            let names = usedBy.map { "\u{2022} \($0.name)" }.joined(separator: "\n")
            let plural = usedBy.count == 1
            alert.informativeText = String(localized: "settings.homekit_bridge.delete_alert.used_by", defaultValue: "This sensor is used by \(usedBy.count) automation\(plural ? "" : "s"):\n\(names)\n\nDeleting it will break \(plural ? "that automation" : "those automations").", bundle: .macOSBridge)
        }
        alert.addButton(withTitle: String(localized: "common.delete", defaultValue: "Delete", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))
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
        alert.messageText = String(localized: "settings.homekit_bridge.reset_alert.title", defaultValue: "Reset HomeKit pairing?", bundle: .macOSBridge)
        alert.informativeText = String(localized: "settings.homekit_bridge.reset_alert.message", defaultValue: "This unpairs the bridge and generates a new setup code. Remove \"Itsyhome Bridge\" from the Apple Home app, then add it again with the new code.", bundle: .macOSBridge)
        alert.addButton(withTitle: String(localized: "settings.homekit_bridge.reset_alert.confirm_button", defaultValue: "Reset", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "settings.homekit_bridge.reset_alert.cancel_button", defaultValue: "Cancel", bundle: .macOSBridge))
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
        DispatchQueue.main.async { [weak self] in
            self?.rebuildDevicesList()
            self?.updateStatusDisplay()   // adding/removing the last device flips the waiting hint
        }
    }

    private func updateStatusDisplay() {
        switch VirtualBridgeService.shared.status {
        case .stopped:
            // The bridge deliberately doesn't start with zero devices, and the
            // start call is a silent no-op - explain what's missing instead of
            // showing a bare "Stopped".
            if PreferencesManager.shared.virtualBridgeEnabled, VirtualDeviceStore.shared.devices.isEmpty {
                statusLabel.stringValue = String(localized: "settings.homekit_bridge.status.waiting_for_devices", defaultValue: "Waiting – add a virtual device to start", bundle: .macOSBridge)
                statusLabel.textColor = .systemOrange
            } else {
                statusLabel.stringValue = String(localized: "settings.homekit_bridge.status.stopped", defaultValue: "Stopped", bundle: .macOSBridge)
                statusLabel.textColor = .secondaryLabelColor
            }
        case .running:
            statusLabel.stringValue = String(localized: "settings.homekit_bridge.status.running", defaultValue: "Running", bundle: .macOSBridge)
            statusLabel.textColor = .systemGreen
        case .error(let message):
            statusLabel.stringValue = String(localized: "settings.homekit_bridge.status.error", defaultValue: "Error: \(message)", bundle: .macOSBridge)
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

        stack.addArrangedSubview(createLabel(String(localized: "settings.homekit_bridge.instructions.title", defaultValue: "Add to Apple Home", bundle: .macOSBridge), style: .sectionHeader))

        if let uri = HAPSetupQRCode.setupURI(setupCode: PreferencesManager.shared.virtualBridgeSetupCode,
                                             setupID: VirtualBridgeService.setupID),
           let qr = HAPSetupQRCode.qrImage(uri: uri, size: 140) {
            let imageView = NSImageView(image: qr)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            let wrap = NSView()
            wrap.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 140),
                imageView.heightAnchor.constraint(equalToConstant: 140),
                imageView.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 4),
                imageView.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -4),
                imageView.centerXAnchor.constraint(equalTo: wrap.centerXAnchor)
            ])
            stack.addArrangedSubview(wrap)
            wrap.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            let scanHint = createLabel(String(localized: "settings.homekit_bridge.instructions.scan_hint", defaultValue: "Scan with the iPhone camera or the Home app, or add manually:", bundle: .macOSBridge), style: .caption)
            scanHint.lineBreakMode = .byWordWrapping
            scanHint.maximumNumberOfLines = 0
            scanHint.preferredMaxLayoutWidth = 280
            stack.addArrangedSubview(scanHint)
        }

        let steps = [
            String(localized: "settings.homekit_bridge.instructions.step1", defaultValue: "1. Add a device and enable the bridge.", bundle: .macOSBridge),
            String(localized: "settings.homekit_bridge.instructions.step2", defaultValue: "2. In the Home app: Add Accessory, then More options.", bundle: .macOSBridge),
            String(localized: "settings.homekit_bridge.instructions.step3", defaultValue: "3. Pick \u{201C}Itsyhome Bridge\u{201D} and enter the setup code.", bundle: .macOSBridge),
            String(localized: "settings.homekit_bridge.instructions.step4", defaultValue: "4. Assign each device to a room in the Home app.", bundle: .macOSBridge)
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
        container.widthAnchor.constraint(equalToConstant: 320).isActive = true
        pop.contentSize = NSSize(width: 320, height: container.fittingSize.height)
        return pop
    }

    // MARK: - Helpers

    // Type names live on VirtualSensorType.displayName so the bridge and the
    // automations trigger picker share one localized source.
    private func displayName(_ type: VirtualSensorType) -> String { type.displayName }

    private func displayName(_ role: ContactRole) -> String {
        switch role {
        case .generic: return String(localized: "settings.homekit_bridge.role.generic", defaultValue: "Generic", bundle: .macOSBridge)
        case .door: return String(localized: "settings.homekit_bridge.role.door", defaultValue: "Door", bundle: .macOSBridge)
        case .window: return String(localized: "settings.homekit_bridge.role.window", defaultValue: "Window", bundle: .macOSBridge)
        }
    }
}
