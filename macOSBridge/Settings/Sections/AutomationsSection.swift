//
//  AutomationsSection.swift
//  macOSBridge
//
//  Settings pane for automations: a list of automations each showing a live
//  status (idle / waiting / active), with an inline WHEN / FOR / THEN builder
//  that replaces the list. v1 builds "WHEN <accessory> reaches a state FOR
//  <duration> THEN set a virtual sensor (re-pulsing it)". Mirrors the
//  HomeKitBridgeSection idiom. The engine runs whenever Pro is active; each
//  automation has its own enabled toggle (no master switch).
//
import AppKit

class AutomationsSection: SettingsCard {

    private var automationsHeader: NSView!
    private let automationsStack = NSStackView()

    // Inline builder
    private let formContainer = NSView()
    private var formTitleLabel: NSTextField!
    private let nameField = NSTextField()
    private let triggerPopUp = NSPopUpButton()
    private let statePopUp = NSPopUpButton()
    private let durationField = NSTextField()
    private let durationUnitPopUp = NSPopUpButton()
    private let devicePopUp = NSPopUpButton()
    private var actionNote: NSTextField!
    private let rePulseSwitch = NSSwitch()
    private let rePulseField = NSTextField()
    private let rePulseUnitPopUp = NSPopUpButton()
    private var errorLabel: NSTextField!
    private var editingAutomationId: UUID?

    private var menuData: MenuData?
    private var triggerOptions: [TriggerOption] = []
    private var deviceOptions: [VirtualDevice] = []

    private var automationStatusLabels: [UUID: NSTextField] = [:]
    private var statusTimer: Timer?

    private struct TriggerOption {
        let accessoryName: String
        let characteristicId: UUID
        let label: String        // sensor type display, e.g. "Contact"
        let title: String        // "Front Door - Contact"
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        observeNotifications()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatuses()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self); statusTimer?.invalidate() }

    func configure(with data: MenuData) {
        menuData = data
        rebuildTriggerOptions()
        rebuildAutomationsList()
    }

    // MARK: - Layout

    private func setupContent() {
        if !ProStatusCache.shared.isPro {
            stackView.addArrangedSubview(Self.createProBanner())
            stackView.addArrangedSubview(createSpacer(height: 8))
        }

        let desc = wrappingLabel(
            "Automations watch a HomeKit accessory and, when it holds a state for a duration, set a virtual sensor (re-pulsing it) - so Apple Home can automate on conditions HomeKit can't compute itself, like \"open for 15 minutes\".")
        stackView.addArrangedSubview(desc)
        stackView.addArrangedSubview(createSpacer(height: 12))

        automationsHeader = createAutomationsHeader()
        stackView.addArrangedSubview(automationsHeader)
        automationsHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        automationsStack.orientation = .vertical
        automationsStack.spacing = 6
        automationsStack.alignment = .leading
        automationsStack.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(automationsStack)
        automationsStack.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        setupForm()
        stackView.addArrangedSubview(formContainer)
        formContainer.isHidden = true
        formContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        rebuildAutomationsList()
    }

    private func createAutomationsHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(createLabel("Automations", style: .sectionHeader))
        row.addArrangedSubview(NSView())
        let add = NSButton(title: "Add Automation", target: self, action: #selector(showAddForm))
        add.bezelStyle = .rounded; add.controlSize = .small
        row.addArrangedSubview(add)
        return row
    }

    // MARK: - Builder form

    private func setupForm() {
        let panel = NSStackView()
        panel.orientation = .vertical; panel.spacing = 8; panel.alignment = .leading
        panel.translatesAutoresizingMaskIntoConstraints = false

        let sep = createSeparator()
        panel.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        formTitleLabel = createLabel("New automation", style: .sectionHeader)
        panel.addArrangedSubview(formTitleLabel)

        nameField.placeholderString = "Name (e.g. Front Door left open)"
        nameField.controlSize = .regular
        panel.addArrangedSubview(labeledRow("Name", nameField))

        // WHEN
        panel.addArrangedSubview(createLabel("WHEN", style: .caption))
        triggerPopUp.controlSize = .regular
        triggerPopUp.target = self
        triggerPopUp.action = #selector(triggerChanged)
        panel.addArrangedSubview(labeledRow("Accessory", triggerPopUp))
        statePopUp.controlSize = .regular
        panel.addArrangedSubview(labeledRow("Is", statePopUp))

        // FOR
        panel.addArrangedSubview(createLabel("FOR", style: .caption))
        durationField.placeholderString = "0"
        durationField.controlSize = .regular
        durationField.translatesAutoresizingMaskIntoConstraints = false
        durationField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        durationUnitPopUp.addItems(withTitles: ["Seconds", "Minutes"])
        durationUnitPopUp.selectItem(at: 1)
        durationUnitPopUp.controlSize = .regular
        panel.addArrangedSubview(fieldUnitRow("Duration", durationField, durationUnitPopUp))
        let durNote = wrappingLabel("0 = fire immediately. Time-of-day and presence conditions stay in Apple Home.")
        durNote.textColor = .tertiaryLabelColor
        panel.addArrangedSubview(durNote)

        // THEN
        panel.addArrangedSubview(createLabel("THEN set a virtual sensor", style: .caption))
        devicePopUp.controlSize = .regular
        devicePopUp.target = self
        devicePopUp.action = #selector(deviceChanged)
        panel.addArrangedSubview(labeledRow("Sensor", devicePopUp))
        actionNote = wrappingLabel("")
        actionNote.textColor = .secondaryLabelColor
        panel.addArrangedSubview(actionNote)

        // Re-pulse
        rePulseSwitch.controlSize = .mini
        rePulseSwitch.state = .on
        rePulseField.stringValue = "5"
        rePulseField.controlSize = .regular
        rePulseField.translatesAutoresizingMaskIntoConstraints = false
        rePulseField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        rePulseUnitPopUp.addItems(withTitles: ["Seconds", "Minutes"])
        rePulseUnitPopUp.selectItem(at: 1)
        rePulseUnitPopUp.controlSize = .regular
        let pulseRow = NSStackView()
        pulseRow.orientation = .horizontal; pulseRow.spacing = 8; pulseRow.alignment = .centerY
        pulseRow.translatesAutoresizingMaskIntoConstraints = false
        let pulseLabel = createLabel("Re-pulse", style: .body)
        pulseLabel.translatesAutoresizingMaskIntoConstraints = false
        pulseLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
        pulseRow.addArrangedSubview(pulseLabel)
        pulseRow.addArrangedSubview(rePulseSwitch)
        pulseRow.addArrangedSubview(createLabel("every", style: .caption))
        pulseRow.addArrangedSubview(rePulseField)
        pulseRow.addArrangedSubview(rePulseUnitPopUp)
        panel.addArrangedSubview(pulseRow)
        let pulseNote = wrappingLabel("Apple Home automations fire on a change, not a held state. Re-pulse re-fires the sensor on this interval while it's active, so a time- or presence-gated automation can still catch it.")
        pulseNote.textColor = .tertiaryLabelColor
        panel.addArrangedSubview(pulseNote)

        errorLabel = createLabel("", style: .caption)
        errorLabel.textColor = .systemRed
        panel.addArrangedSubview(errorLabel)

        let buttons = NSStackView()
        buttons.orientation = .horizontal; buttons.spacing = 8; buttons.alignment = .centerY
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.addArrangedSubview(NSView())
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelForm))
        cancel.bezelStyle = .rounded; cancel.controlSize = .small; cancel.keyEquivalent = "\u{1b}"
        buttons.addArrangedSubview(cancel)
        let save = NSButton(title: "Save", target: self, action: #selector(saveAutomation))
        save.bezelStyle = .rounded; save.controlSize = .small; save.keyEquivalent = "\r"
        buttons.addArrangedSubview(save)
        panel.addArrangedSubview(buttons)
        buttons.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        formContainer.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: formContainer.topAnchor),
            panel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor)
        ])
    }

    private func labeledRow(_ label: String, _ control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        let l = createLabel(label, style: .body)
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: 110).isActive = true
        control.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(l)
        row.addArrangedSubview(control)
        return row
    }

    private func fieldUnitRow(_ label: String, _ field: NSTextField, _ unit: NSPopUpButton) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        let l = createLabel(label, style: .body)
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: 110).isActive = true
        row.addArrangedSubview(l)
        row.addArrangedSubview(field)
        row.addArrangedSubview(unit)
        return row
    }

    private func setFormVisible(_ visible: Bool) {
        automationsHeader.isHidden = visible
        automationsStack.isHidden = visible
        formContainer.isHidden = !visible
    }

    // MARK: - Options

    private func rebuildTriggerOptions() {
        var opts: [TriggerOption] = []
        for acc in menuData?.accessories ?? [] {
            for svc in acc.services {
                let pairs: [(String?, String)] = [
                    (svc.contactSensorStateId, "Contact"),
                    (svc.motionDetectedId, "Motion"),
                    (svc.occupancyDetectedId, "Occupancy"),
                    (svc.leakDetectedId, "Leak"),
                    (svc.smokeDetectedId, "Smoke"),
                    (svc.carbonMonoxideDetectedId, "Carbon Monoxide"),
                    (svc.carbonDioxideDetectedId, "Carbon Dioxide")
                ]
                for (idStr, label) in pairs {
                    if let idStr, let id = UUID(uuidString: idStr) {
                        opts.append(TriggerOption(accessoryName: acc.name, characteristicId: id,
                            label: label, title: "\(acc.name) - \(label)"))
                    }
                }
            }
        }
        triggerOptions = opts
        triggerPopUp.removeAllItems()
        triggerPopUp.addItems(withTitles: opts.isEmpty ? ["No sensors found"] : opts.map(\.title))
        triggerChanged()
    }

    private func rebuildDeviceOptions() {
        deviceOptions = VirtualDeviceStore.shared.devices
        devicePopUp.removeAllItems()
        devicePopUp.addItems(withTitles: deviceOptions.isEmpty ? ["No virtual sensors"] : deviceOptions.map(\.name))
        deviceChanged()
    }

    private func words(forLabel label: String) -> (on: String, off: String) {
        switch label {
        case "Contact": return ("Open", "Closed")
        case "Motion": return ("Motion", "Clear")
        case "Occupancy": return ("Occupied", "Clear")
        case "Leak": return ("Leak", "Dry")
        case "Smoke": return ("Smoke", "Clear")
        case "Carbon Monoxide": return ("CO", "Clear")
        case "Carbon Dioxide": return ("CO2", "Clear")
        default: return ("On", "Off")
        }
    }

    @objc private func triggerChanged() {
        let idx = triggerPopUp.indexOfSelectedItem
        guard idx >= 0, idx < triggerOptions.count else { statePopUp.removeAllItems(); return }
        let w = words(forLabel: triggerOptions[idx].label)
        statePopUp.removeAllItems()
        statePopUp.addItems(withTitles: [w.on, w.off])  // index 0 = active (value 1)
    }

    @objc private func deviceChanged() {
        let idx = devicePopUp.indexOfSelectedItem
        guard idx >= 0, idx < deviceOptions.count else { actionNote.stringValue = ""; return }
        let d = deviceOptions[idx]
        actionNote.stringValue = "Sets \(d.name) to \(d.type.stateWord(on: true)) while the trigger holds, then back to \(d.type.stateWord(on: false)) when it clears."
    }

    // MARK: - Automations list

    private func rebuildAutomationsList() {
        automationStatusLabels.removeAll()
        for v in automationsStack.arrangedSubviews { automationsStack.removeArrangedSubview(v); v.removeFromSuperview() }
        let automations = AutomationStore.shared.automations
        if automations.isEmpty {
            automationsStack.addArrangedSubview(createLabel("No automations yet.", style: .caption))
            return
        }
        for automation in automations {
            let row = createAutomationRow(automation)
            automationsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: automationsStack.widthAnchor).isActive = true
        }
        updateStatuses()
    }

    private func createAutomationRow(_ automation: Automation) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let textCol = NSStackView()
        textCol.orientation = .vertical; textCol.spacing = 1; textCol.alignment = .leading
        textCol.addArrangedSubview(createLabel(automation.name, style: .body))
        let summary = createLabel(automationSummary(automation), style: .caption)
        summary.textColor = automationTargetMissing(automation) ? .systemRed : .secondaryLabelColor
        textCol.addArrangedSubview(summary)
        row.addArrangedSubview(textCol)

        row.addArrangedSubview(NSView())

        let status = createLabel("", style: .caption)
        automationStatusLabels[automation.id] = status
        row.addArrangedSubview(status)

        let toggle = NSSwitch()
        toggle.controlSize = .mini
        toggle.state = automation.enabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(automationEnabledChanged(_:))
        toggle.identifier = NSUserInterfaceItemIdentifier(automation.id.uuidString)
        row.addArrangedSubview(toggle)

        row.addArrangedSubview(iconButton("pencil", action: #selector(editAutomation(_:)), id: automation.id))
        row.addArrangedSubview(iconButton("xmark.circle.fill", action: #selector(removeAutomation(_:)), id: automation.id))

        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        return row
    }

    private func automationSummary(_ automation: Automation) -> String {
        guard case .accessoryState(let t) = automation.trigger,
              case .setVirtualSensor(let a)? = automation.actions.first else { return automation.name }
        let w = words(forLabel: t.characteristicLabel)
        let stateWord = t.value != 0 ? w.on : w.off
        let dur: String
        if let s = automation.durationSeconds, s > 0 {
            dur = s % 60 == 0 ? " for \(s / 60)m" : " for \(s)s"
        } else { dur = "" }
        let target = VirtualDeviceStore.shared.device(id: a.deviceId)?.name ?? "(missing sensor)"
        return "\(t.accessoryName) \(stateWord)\(dur) -> \(target)"
    }

    private func iconButton(_ symbol: String, action: Selector, id: UUID) -> NSButton {
        let b = NSButton(title: "", target: self, action: action)
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        b.imagePosition = .imageOnly
        b.isBordered = false
        b.contentTintColor = .secondaryLabelColor
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 20).isActive = true
        b.heightAnchor.constraint(equalToConstant: 20).isActive = true
        b.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        return b
    }

    // MARK: - Live status

    private func updateStatuses() {
        for (id, label) in automationStatusLabels {
            let (text, color) = statusText(id)
            label.stringValue = text
            label.textColor = color
        }
    }

    private func statusText(_ id: UUID) -> (String, NSColor) {
        guard let automation = AutomationStore.shared.automation(id: id) else { return ("", .secondaryLabelColor) }
        if automationTargetMissing(automation) { return ("Sensor deleted", .systemRed) }
        if !automation.enabled { return ("Disabled", .tertiaryLabelColor) }
        switch AutomationEngine.shared.runtimeState(automationId: id) {
        case .active:
            return ("Active", .systemGreen)
        case .armed:
            if let r = AutomationEngine.shared.armedRemaining(automationId: id) { return ("Waiting \(r)s", .systemOrange) }
            return ("Waiting", .systemOrange)
        case .idle:
            return ("Idle", .secondaryLabelColor)
        }
    }

    /// True if the automation's target virtual sensor no longer exists.
    private func automationTargetMissing(_ automation: Automation) -> Bool {
        guard case .setVirtualSensor(let a)? = automation.actions.first else { return false }
        return VirtualDeviceStore.shared.device(id: a.deviceId) == nil
    }

    // MARK: - Actions

    @objc private func showAddForm() {
        editingAutomationId = nil
        formTitleLabel.stringValue = "New automation"
        nameField.stringValue = ""
        rebuildTriggerOptions()
        rebuildDeviceOptions()
        durationField.stringValue = ""
        durationUnitPopUp.selectItem(at: 1)
        rePulseSwitch.state = .on
        rePulseField.stringValue = "5"
        rePulseUnitPopUp.selectItem(at: 1)
        errorLabel.stringValue = ""
        setFormVisible(true)
    }

    private func showEditForm(_ automation: Automation) {
        editingAutomationId = automation.id
        formTitleLabel.stringValue = "Edit automation"
        nameField.stringValue = automation.name
        rebuildTriggerOptions()
        rebuildDeviceOptions()
        if case .accessoryState(let t) = automation.trigger,
           let idx = triggerOptions.firstIndex(where: { $0.characteristicId == t.characteristicId }) {
            triggerPopUp.selectItem(at: idx)
            triggerChanged()
            statePopUp.selectItem(at: t.value != 0 ? 0 : 1)
        }
        if let s = automation.durationSeconds, s > 0 {
            if s % 60 == 0 { durationField.stringValue = "\(s / 60)"; durationUnitPopUp.selectItem(at: 1) }
            else { durationField.stringValue = "\(s)"; durationUnitPopUp.selectItem(at: 0) }
        } else { durationField.stringValue = "" }
        if case .setVirtualSensor(let a)? = automation.actions.first {
            if let idx = deviceOptions.firstIndex(where: { $0.id == a.deviceId }) {
                devicePopUp.selectItem(at: idx); deviceChanged()
            }
            rePulseSwitch.state = a.rePulse.enabled ? .on : .off
            let i = a.rePulse.intervalSeconds
            if i % 60 == 0 { rePulseField.stringValue = "\(i / 60)"; rePulseUnitPopUp.selectItem(at: 1) }
            else { rePulseField.stringValue = "\(i)"; rePulseUnitPopUp.selectItem(at: 0) }
        }
        errorLabel.stringValue = ""
        setFormVisible(true)
    }

    @objc private func cancelForm() { editingAutomationId = nil; setFormVisible(false) }

    @objc private func saveAutomation() {
        let durUnit = durationUnitPopUp.indexOfSelectedItem == 1 ? 60 : 1
        let durationSeconds = max(0, Int(durationField.stringValue) ?? 0) * durUnit
        let triggerIdx = triggerPopUp.indexOfSelectedItem
        let trigger: AccessoryStateTrigger? = (triggerIdx >= 0 && triggerIdx < triggerOptions.count) ? {
            let o = triggerOptions[triggerIdx]
            return AccessoryStateTrigger(characteristicId: o.characteristicId, accessoryName: o.accessoryName,
                characteristicLabel: o.label, comparator: .equal, value: statePopUp.indexOfSelectedItem == 0 ? 1 : 0)
        }() : nil
        let deviceIdx = devicePopUp.indexOfSelectedItem
        let deviceId: UUID? = (deviceIdx >= 0 && deviceIdx < deviceOptions.count) ? deviceOptions[deviceIdx].id : nil
        let pulseUnit = rePulseUnitPopUp.indexOfSelectedItem == 1 ? 60 : 1
        let pulseInterval = max(1, (Int(rePulseField.stringValue) ?? 5) * pulseUnit)

        let draft = AutomationDraft(id: editingAutomationId, name: nameField.stringValue, trigger: trigger,
            durationSeconds: durationSeconds, actionDeviceId: deviceId,
            rePulseEnabled: rePulseSwitch.state == .on, rePulseInterval: pulseInterval)

        if let err = draft.validationError() { errorLabel.stringValue = err; return }
        AutomationStore.shared.upsert(draft.build())
        AutomationEngine.shared.reload()
        editingAutomationId = nil
        setFormVisible(false)
        rebuildAutomationsList()
    }

    @objc private func automationEnabledChanged(_ sender: NSSwitch) {
        guard let s = sender.identifier?.rawValue, let id = UUID(uuidString: s) else { return }
        AutomationStore.shared.setEnabled(sender.state == .on, id: id)
        AutomationEngine.shared.reload()
    }

    @objc private func editAutomation(_ sender: NSButton) {
        guard let s = sender.identifier?.rawValue, let id = UUID(uuidString: s),
              let automation = AutomationStore.shared.automation(id: id) else { return }
        showEditForm(automation)
    }

    @objc private func removeAutomation(_ sender: NSButton) {
        guard let s = sender.identifier?.rawValue, let id = UUID(uuidString: s),
              let automation = AutomationStore.shared.automation(id: id) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \"\(automation.name)\"?"
        alert.informativeText = "This automation will be removed."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        AutomationStore.shared.remove(id: id)
        AutomationEngine.shared.reload()
        rebuildAutomationsList()
    }

    // MARK: - Observers

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged),
            name: AutomationStore.didChangeNotification, object: nil)
        // Also rebuild when virtual devices change, so a deleted sensor a automation
        // depends on shows as unresolved immediately (no restart).
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged),
            name: VirtualDeviceStore.didChangeNotification, object: nil)
    }
    @objc private func storeChanged() {
        DispatchQueue.main.async { [weak self] in self?.rebuildAutomationsList() }
    }

    // MARK: - Helpers

    private func wrappingLabel(_ text: String) -> NSTextField {
        let l = createLabel(text, style: .caption)
        l.lineBreakMode = .byWordWrapping
        l.maximumNumberOfLines = 0
        l.preferredMaxLayoutWidth = 460
        return l
    }

    private func createSpacer(height: CGFloat) -> NSView {
        let s = NSView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.heightAnchor.constraint(equalToConstant: height).isActive = true
        return s
    }
}
