//
//  HASecuritySystemMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant alarm control panels with code entry support
//  Supports HA modes: home, away, night, vacation, custom, disarmed
//

import AppKit

class HASecuritySystemMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentStateId: UUID?
    private var targetStateId: UUID?

    // HA alarm states: armed_home, armed_away, armed_night, armed_vacation, armed_custom_bypass, disarmed, pending, arming, triggered
    private var currentState: String = "disarmed"
    private var pendingMode: String?  // Mode waiting for code entry

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let triggeredIcon: NSImageView

    // Mode buttons (icons only)
    private var modeButtons: [String: ModeButton] = [:]
    private let modeContainer: ModeButtonGroup

    // Code entry views
    private let codeEntryContainer: NSView
    private let codeField: NSTextField
    private let confirmButton: NSButton
    private let cancelButton: NSButton
    private var isCodeEntryVisible = false

    // Available modes for this alarm (from HA)
    private var availableModes: [String] = ["disarmed", "armed_home", "armed_away", "armed_night", "armed_vacation", "armed_custom_bypass"]
    private var requiresCode: Bool = true

    // Optimistic update suppression - ignore HA state updates for 10 seconds after local change
    private var suppressStateUpdatesUntil: Date?
    private let suppressionDuration: TimeInterval = 10.0

    // Layout constants - title row is at top, expands downward
    private let topRowHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let modeRowHeight: CGFloat = 30
    private let codeRowHeight: CGFloat = 32
    private var normalRowHeight: CGFloat { topRowHeight + modeRowHeight }
    private var expandedRowHeight: CGFloat { topRowHeight + modeRowHeight + codeRowHeight }

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Use modes from HA entity or fall back to defaults
        if let modes = serviceData.alarmSupportedModes, !modes.isEmpty {
            self.availableModes = modes
        }
        self.requiresCode = serviceData.alarmRequiresCode ?? true

        // Extract characteristic UUIDs
        self.currentStateId = serviceData.securitySystemCurrentStateId?.uuid
        self.targetStateId = serviceData.securitySystemTargetStateId?.uuid

        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm

        // Create wrapper view (2 rows: title + mode buttons)
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: topRowHeight + modeRowHeight))

        // Row 1 (top): Icon, name, triggered indicator - use autoresizing to stay at top
        let iconY = modeRowHeight + (topRowHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.autoresizingMask = [.minYMargin]  // Stay at top when view expands
        containerView.addSubview(iconView)

        // Triggered icon
        let triggeredX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.iconMedium
        triggeredIcon = NSImageView(frame: NSRect(x: triggeredX, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        triggeredIcon.image = PhosphorIcon.fill("shield-warning")
        triggeredIcon.contentTintColor = DS.Colors.destructive
        triggeredIcon.imageScaling = .scaleProportionallyUpOrDown
        triggeredIcon.isHidden = true
        triggeredIcon.autoresizingMask = [.minYMargin]  // Stay at top
        containerView.addSubview(triggeredIcon)

        // Name label
        let labelY = modeRowHeight + (topRowHeight - 17) / 2
        let labelWidth = triggeredX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.autoresizingMask = [.minYMargin]  // Stay at top
        containerView.addSubview(nameLabel)

        // Row 2: Mode buttons - stay at fixed position from top
        let buttonCount = min(self.availableModes.count, 6)
        let containerWidth = ModeButtonGroup.widthForIconButtons(count: buttonCount, buttonWidth: 32)
        let modeButtonsY = modeRowHeight - 22 - 4  // 22 = button height, 4 = padding from bottom of row
        modeContainer = ModeButtonGroup(frame: NSRect(x: labelX, y: modeButtonsY, width: containerWidth, height: 22))
        modeContainer.autoresizingMask = [.minYMargin]  // Stay at top when view expands
        containerView.addSubview(modeContainer)

        // Row 3: Code entry container (initially hidden, appears at bottom when expanded)
        let codeEntryWidth = DS.ControlSize.menuItemWidth - labelX - DS.Spacing.md
        codeEntryContainer = NSView(frame: NSRect(x: labelX, y: 4, width: codeEntryWidth, height: 26))
        codeEntryContainer.wantsLayer = true
        codeEntryContainer.isHidden = true
        codeEntryContainer.alphaValue = 0
        containerView.addSubview(codeEntryContainer)

        // Code text field - fully transparent, blends with capsule
        let fieldWidth = codeEntryWidth - 56
        codeField = BorderlessTextField(frame: NSRect(x: 10, y: 3, width: fieldWidth, height: 20))
        codeField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        codeField.placeholderString = String(localized: "device.security.code", defaultValue: "Code", bundle: .macOSBridge)
        codeField.textColor = DS.Colors.foreground
        codeEntryContainer.addSubview(codeField)

        // Confirm button (checkmark)
        let buttonSize: CGFloat = 22
        let buttonY: CGFloat = 2
        confirmButton = NSButton(frame: NSRect(x: codeEntryWidth - buttonSize * 2 - 6, y: buttonY, width: buttonSize, height: buttonSize))
        confirmButton.isBordered = false
        confirmButton.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Confirm")
        confirmButton.contentTintColor = DS.Colors.success
        confirmButton.imageScaling = .scaleProportionallyUpOrDown
        codeEntryContainer.addSubview(confirmButton)

        // Cancel button (X)
        cancelButton = NSButton(frame: NSRect(x: codeEntryWidth - buttonSize - 2, y: buttonY, width: buttonSize, height: buttonSize))
        cancelButton.isBordered = false
        cancelButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel")
        cancelButton.contentTintColor = DS.Colors.mutedForeground
        cancelButton.imageScaling = .scaleProportionallyUpOrDown
        codeEntryContainer.addSubview(cancelButton)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView
        containerView.closesMenuOnAction = false

        // Setup code entry container appearance
        setupCodeEntryAppearance()

        // Create mode buttons
        setupModeButtons()

        // Setup button actions
        confirmButton.target = self
        confirmButton.action = #selector(confirmCodeEntry)
        cancelButton.target = self
        cancelButton.action = #selector(cancelCodeEntry)

        // Setup enter key handling for code field
        codeField.target = self
        codeField.action = #selector(confirmCodeEntry)

        // Set initial state
        updateModeButtons()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCodeEntryAppearance() {
        codeEntryContainer.wantsLayer = true
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bgAlpha: CGFloat = isDark ? 0.2 : 0.08
        codeEntryContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(bgAlpha).cgColor
        codeEntryContainer.layer?.cornerRadius = 13
    }

    private func setupModeButtons() {
        // Map HA modes to custom security icons and colors
        let modeConfig: [(mode: String, iconName: String, color: NSColor)] = [
            ("disarmed", "disarmed", DS.Colors.mutedForeground),
            ("armed_home", "home", DS.Colors.success),
            ("armed_away", "away", DS.Colors.warning),
            ("armed_night", "night", DS.Colors.info),
            ("armed_vacation", "vacation", DS.Colors.info),
            ("armed_custom_bypass", "custom", DS.Colors.info)
        ]

        let bundle = Bundle(for: type(of: self))

        for config in modeConfig where availableModes.contains(config.mode) {
            // Load icon from SecurityIcons folder
            if let iconURL = bundle.url(forResource: config.iconName, withExtension: "png", subdirectory: "SecurityIcons"),
               let iconImage = NSImage(contentsOf: iconURL) {
                iconImage.isTemplate = true  // Enable tinting
                let button = modeContainer.addButton(image: iconImage, color: config.color, tag: 0)
                button.target = self
                button.action = #selector(modeButtonTapped(_:))
                modeButtons[config.mode] = button
            }
        }
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        // Ignore state updates during suppression period (optimistic UI)
        if let suppressUntil = suppressStateUpdatesUntil, Date() < suppressUntil {
            return
        }

        if characteristicId == currentStateId || characteristicId == targetStateId {
            if let stateInt = ValueConversion.toInt(value) {
                // Convert HomeKit-style int to HA state string
                currentState = intToHAState(stateInt)
                updateUI()
            } else if let stateString = value as? String {
                currentState = stateString
                updateUI()
            }
        }
    }

    private func intToHAState(_ value: Int) -> String {
        switch value {
        case 0: return "armed_home"
        case 1: return "armed_away"
        case 2: return "armed_night"
        case 3: return "disarmed"
        case 4: return "triggered"
        default: return "disarmed"
        }
    }

    private func haStateToInt(_ state: String) -> Int {
        switch state {
        case "armed_home": return 0
        case "armed_away", "armed_vacation": return 1
        case "armed_night": return 2
        case "disarmed", "arming", "pending": return 3
        case "triggered": return 4
        default: return 3
        }
    }

    private func updateUI() {
        updateStateIcon()
        updateModeButtons()
    }

    private func updateStateIcon() {
        let isArmed = currentState.hasPrefix("armed_")
        let isTriggered = currentState == "triggered"

        let mode: String
        let filled: Bool
        if isTriggered {
            mode = "triggered"
            filled = true
        } else if isArmed {
            mode = "armed"
            filled = true
        } else {
            mode = "disarmed"
            filled = false
        }

        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: filled)
            ?? IconResolver.icon(for: serviceData, filled: filled)

        triggeredIcon.isHidden = !isTriggered
    }

    private func updateModeButtons() {
        for (mode, button) in modeButtons {
            button.isSelected = (currentState == mode)
        }
    }

    @objc private func modeButtonTapped(_ sender: ModeButton) {
        // Find which mode was tapped
        guard let mode = modeButtons.first(where: { $0.value === sender })?.key else { return }

        // If disarming or code not required, execute immediately
        if mode == "disarmed" || !requiresCode {
            executeAlarmCommand(mode: mode, code: nil)
            return
        }

        // Show code entry for arming
        pendingMode = mode
        showCodeEntry()
    }

    private func showCodeEntry() {
        guard !isCodeEntryVisible else { return }
        isCodeEntryVisible = true

        // Show code entry row, expand downward (autoresizing keeps title at top)
        codeEntryContainer.isHidden = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            containerView.animator().frame.size.height = expandedRowHeight
            codeEntryContainer.animator().alphaValue = 1
        }

        // Focus the code field
        DispatchQueue.main.async {
            self.codeField.window?.makeFirstResponder(self.codeField)
        }
    }

    private func hideCodeEntry() {
        guard isCodeEntryVisible else { return }
        isCodeEntryVisible = false
        pendingMode = nil
        codeField.stringValue = ""

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            containerView.animator().frame.size.height = normalRowHeight
            codeEntryContainer.animator().alphaValue = 0
        } completionHandler: {
            self.codeEntryContainer.isHidden = true
        }
    }

    @objc private func confirmCodeEntry() {
        guard let mode = pendingMode else {
            hideCodeEntry()
            return
        }

        let code = codeField.stringValue
        if code.isEmpty {
            // Shake the field to indicate error
            shakeCodeField()
            return
        }

        executeAlarmCommand(mode: mode, code: code)
        hideCodeEntry()
    }

    @objc private func cancelCodeEntry() {
        hideCodeEntry()
    }

    private func shakeCodeField() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.values = [-5, 5, -4, 4, -2, 2, 0]
        animation.duration = 0.3
        codeEntryContainer.layer?.add(animation, forKey: "shake")
    }

    private func executeAlarmCommand(mode: String, code: String?) {
        // Store pending mode for error recovery
        let attemptedMode = mode

        // Update UI optimistically
        currentState = mode
        updateUI()

        // Suppress incoming state updates for 10 seconds (HA blinks during arming)
        suppressStateUpdatesUntil = Date().addingTimeInterval(suppressionDuration)

        // Send command via bridge
        // The bridge will handle converting this to the appropriate HA service call
        if let id = targetStateId {
            // For HA, we pass the mode string directly with optional code
            // The platform will handle the service call
            let value: Any = code != nil ? ["mode": mode, "code": code!] : mode

            // Register for error notification (will be triggered if code is wrong)
            if code != nil {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleAlarmError(_:)),
                    name: .alarmCommandFailed,
                    object: nil
                )
                // Store attempted mode for potential revert
                pendingMode = attemptedMode
            }

            bridge?.writeCharacteristic(identifier: id, value: value)
            notifyLocalChange(characteristicId: id, value: haStateToInt(mode))
        }
    }

    @objc private func handleAlarmError(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: .alarmCommandFailed, object: nil)

        // Revert to previous state and show code entry again
        DispatchQueue.main.async {
            self.currentState = "disarmed"  // Revert to disarmed on error
            self.updateUI()

            if self.pendingMode != nil {
                self.showCodeEntry()
                self.shakeCodeField()
                self.codeField.stringValue = ""
            }
        }
    }

    /// Update available modes (called from platform after fetching entity attributes)
    func setAvailableModes(_ modes: [String]) {
        self.availableModes = modes
        // Rebuild mode buttons
        for button in modeButtons.values {
            button.removeFromSuperview()
        }
        modeButtons.removeAll()
        setupModeButtons()
        updateModeButtons()
    }

    /// Update whether code is required
    func setRequiresCode(_ required: Bool) {
        self.requiresCode = required
    }
}

// MARK: - Notification name for alarm errors

extension Notification.Name {
    static let alarmCommandFailed = Notification.Name("alarmCommandFailed")
}
