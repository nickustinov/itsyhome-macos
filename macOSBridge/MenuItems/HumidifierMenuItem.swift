//
//  HumidifierMenuItem.swift
//  macOSBridge
//
//  Menu item for Humidifier/Dehumidifier controls
//

import AppKit

class HumidifierMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var activeId: UUID?
    private var currentStateId: UUID?
    private var targetStateId: UUID?
    private var humidityId: UUID?
    private var humidifierThresholdId: UUID?
    private var dehumidifierThresholdId: UUID?
    private var swingModeId: UUID?

    private var isActive: Bool = false
    private var currentState: Int = 0  // 0=inactive, 1=idle, 2=humidifying, 3=dehumidifying
    private var targetState: Int = 1   // 1=humidifier, 2=dehumidifier (no auto mode)
    private var currentHumidity: Double = 0
    private var humidifierThreshold: Double = 50
    private var dehumidifierThreshold: Double = 50
    private var swingMode: Int = 0     // 0=DISABLED, 1=ENABLED

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let humidityLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Swing button (Row 1, before toggle)
    private var swingButtonGroup: ModeButtonGroup?
    private var swingButton: ModeButton?

    // Controls row (shown when active): mode buttons on left, threshold on right
    private let controlsRow: NSView
    private let modeButtonHumidify: ModeButton
    private let modeButtonDehumidify: ModeButton

    // Threshold controls (on same row as mode buttons, right side)
    private var minusButton: NSButton?
    private var thresholdLabel: NSTextField?
    private var plusButton: NSButton?

    private let hasThresholds: Bool

    // Device capabilities based on available thresholds
    private let canHumidify: Bool
    private let canDehumidify: Bool
    private var isComboDevice: Bool { canHumidify && canDehumidify }

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private var expandedHeight: CGFloat { DS.ControlSize.menuItemHeight + 36 }  // Just one extra row

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        if let id = humidityId { ids.append(id) }
        if let id = humidifierThresholdId { ids.append(id) }
        if let id = dehumidifierThresholdId { ids.append(id) }
        if let id = swingModeId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId?.uuid
        self.currentStateId = serviceData.currentHumidifierDehumidifierStateId?.uuid
        self.targetStateId = serviceData.targetHumidifierDehumidifierStateId?.uuid
        self.humidityId = serviceData.humidityId?.uuid
        self.humidifierThresholdId = serviceData.humidifierThresholdId?.uuid
        self.dehumidifierThresholdId = serviceData.dehumidifierThresholdId?.uuid
        self.swingModeId = serviceData.swingModeId?.uuid
        self.hasThresholds = humidifierThresholdId != nil || dehumidifierThresholdId != nil
        self.canHumidify = humidifierThresholdId != nil
        self.canDehumidify = dehumidifierThresholdId != nil

        // Local variables for use during init (before super.init)
        let localCanHumidify = humidifierThresholdId != nil
        let localCanDehumidify = dehumidifierThresholdId != nil
        let localIsComboDevice = localCanHumidify && localCanDehumidify

        // Create wrapper view (full width for menu sizing) - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current humidity, power toggle (centered vertically)
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Power toggle position (calculate first for alignment)
        let switchX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.switchWidth

        // Swing button group position (right before toggle, only if present)
        let swingGroupWidth = ModeButtonGroup.widthForIconButtons(count: 1)
        let swingGroupX = switchX - (swingModeId != nil ? swingGroupWidth + DS.Spacing.sm : 0)

        // Current humidity position (before swing button or toggle)
        let humidityWidth: CGFloat = 50
        let humidityX = (swingModeId != nil ? swingGroupX : switchX) - humidityWidth - DS.Spacing.sm

        // Name label (fills space up to humidity label)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (collapsedHeight - 17) / 2
        let labelWidth = humidityX - labelX - DS.Spacing.xs
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Current humidity
        humidityLabel = NSTextField(labelWithString: "--%")
        humidityLabel.frame = NSRect(x: humidityX, y: labelY - 2, width: humidityWidth, height: 17)
        humidityLabel.font = DS.Typography.labelSmall
        humidityLabel.textColor = .secondaryLabelColor
        humidityLabel.alignment = .right
        containerView.addSubview(humidityLabel)

        // Swing button group (on Row 1, before toggle)
        if swingModeId != nil {
            let swingY = (collapsedHeight - 18) / 2
            let swingGroup = ModeButtonGroup(frame: NSRect(x: swingGroupX, y: swingY, width: swingGroupWidth, height: 18))
            swingButton = swingGroup.addButton(icon: "angle", color: DS.Colors.sliderFan)
            containerView.addSubview(swingGroup)
            swingButtonGroup = swingGroup
        }

        // Power toggle
        let switchY = (collapsedHeight - DS.ControlSize.switchHeight) / 2
        powerToggle = ToggleSwitch()
        powerToggle.frame = NSRect(x: switchX,
                                   y: switchY,
                                   width: DS.ControlSize.switchWidth,
                                   height: DS.ControlSize.switchHeight)
        containerView.addSubview(powerToggle)

        // Controls row (initially hidden): mode buttons on left (combo only), threshold on right
        controlsRow = NSView(frame: NSRect(x: 0, y: DS.Spacing.sm, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Threshold stepper on right side: [−] 50% [+]
        let thresholdX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 90
        let minusBtn = StepperButton.create(title: "−", size: .regular)
        minusBtn.frame.origin = NSPoint(x: thresholdX, y: 4)
        controlsRow.addSubview(minusBtn)
        minusButton = minusBtn

        let threshLabel = NSTextField(labelWithString: "50%")
        threshLabel.frame = NSRect(x: thresholdX + 22, y: 5, width: 44, height: 17)
        threshLabel.font = DS.Typography.labelSmall
        threshLabel.textColor = .secondaryLabelColor
        threshLabel.alignment = .center
        controlsRow.addSubview(threshLabel)
        thresholdLabel = threshLabel

        let plusBtn = StepperButton.create(title: "+", size: .regular)
        plusBtn.frame.origin = NSPoint(x: thresholdX + 68, y: 4)
        controlsRow.addSubview(plusBtn)
        plusButton = plusBtn

        // Mode buttons - always show both, but disable unsupported mode
        let buttonWidth: CGFloat = 52
        let buttonHeight: CGFloat = 18
        let containerPadding: CGFloat = 2
        let modeContainerWidth = buttonWidth * 2 + containerPadding * 2
        let modeContainerHeight = buttonHeight + containerPadding * 2

        let modeContainer = NSView(frame: NSRect(x: labelX, y: 3, width: modeContainerWidth, height: modeContainerHeight))
        modeContainer.wantsLayer = true
        modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        modeContainer.layer?.cornerRadius = modeContainerHeight / 2

        modeButtonHumidify = ModeButton(title: String(localized: "device.humidifier.humid", defaultValue: "Humid", bundle: .macOSBridge), color: DS.Colors.info)  // Blue - adding moisture
        modeButtonHumidify.frame = NSRect(x: containerPadding, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonHumidify.tag = 1
        modeButtonHumidify.isDisabled = !localCanHumidify
        modeContainer.addSubview(modeButtonHumidify)

        modeButtonDehumidify = ModeButton(title: String(localized: "device.humidifier.dry", defaultValue: "Dry", bundle: .macOSBridge), color: DS.Colors.warning)  // Orange - removing moisture
        modeButtonDehumidify.frame = NSRect(x: containerPadding + buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonDehumidify.tag = 2
        modeButtonDehumidify.isDisabled = !localCanDehumidify
        modeContainer.addSubview(modeButtonDehumidify)

        controlsRow.addSubview(modeContainer)

        // Set initial target state based on device capabilities
        if localCanHumidify {
            modeButtonHumidify.isSelected = true
            targetState = 1
        } else {
            modeButtonDehumidify.isSelected = true
            targetState = 2
        }

        containerView.addSubview(controlsRow)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isActive.toggle()
            self.powerToggle.setOn(self.isActive, animated: true)
            if let id = self.activeId {
                self.bridge?.writeCharacteristic(identifier: id, value: self.isActive ? 1 : 0)
                self.notifyLocalChange(characteristicId: id, value: self.isActive ? 1 : 0)
            }
            self.updateUI()
        }

        // Set up actions
        powerToggle.target = self
        powerToggle.action = #selector(togglePower(_:))

        // Mode button actions
        modeButtonHumidify.target = self
        modeButtonHumidify.action = #selector(modeChanged(_:))
        modeButtonDehumidify.target = self
        modeButtonDehumidify.action = #selector(modeChanged(_:))

        swingButton?.target = self
        swingButton?.action = #selector(swingTapped(_:))

        // Threshold button actions
        minusButton?.target = self
        minusButton?.action = #selector(decreaseThreshold(_:))
        plusButton?.target = self
        plusButton?.action = #selector(increaseThreshold(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == activeId {
            if let active = ValueConversion.toBool(value) {
                isActive = active
                updateUI()
            }
        } else if characteristicId == humidityId {
            if let humidity = ValueConversion.toDouble(value) {
                currentHumidity = humidity
                humidityLabel.stringValue = String(format: "%.0f%%", humidity)
            }
        } else if characteristicId == currentStateId {
            if let state = ValueConversion.toInt(value) {
                currentState = state
                updateStateIcon()
            }
        } else if characteristicId == targetStateId {
            if let state = ValueConversion.toInt(value) {
                targetState = state
                updateModeButtons()
                updateThresholdLabel()
            }
        } else if characteristicId == humidifierThresholdId {
            if let threshold = ValueConversion.toDouble(value) {
                humidifierThreshold = threshold
                updateThresholdLabel()
            }
        } else if characteristicId == dehumidifierThresholdId {
            if let threshold = ValueConversion.toDouble(value) {
                dehumidifierThreshold = threshold
                updateThresholdLabel()
            }
        } else if characteristicId == swingModeId {
            if let mode = ValueConversion.toInt(value) {
                swingMode = mode
                updateSwingButton()
            }
        }
    }

    private func updateUI() {
        powerToggle.setOn(isActive, animated: false)
        controlsRow.isHidden = !isActive

        // Resize container
        let newHeight = isActive ? expandedHeight : collapsedHeight
        containerView.frame.size.height = newHeight

        // Reposition row 1 elements (centered in top collapsedHeight area)
        let topAreaY = newHeight - collapsedHeight
        let iconY = topAreaY + (collapsedHeight - DS.ControlSize.iconMedium) / 2
        let labelY = topAreaY + (collapsedHeight - 17) / 2
        let switchY = topAreaY + (collapsedHeight - DS.ControlSize.switchHeight) / 2
        iconView.frame.origin.y = iconY
        nameLabel.frame.origin.y = labelY
        humidityLabel.frame.origin.y = labelY - 2
        powerToggle.frame.origin.y = switchY
        if let swingGroup = swingButtonGroup {
            swingGroup.frame.origin.y = topAreaY + (collapsedHeight - 18) / 2
        }

        updateStateIcon()
        updateModeButtons()
        updateThresholdLabel()
    }

    private func updateStateIcon() {
        if !isActive {
            iconView.image = IconResolver.icon(for: serviceData, filled: false)
            return
        }
        // currentState: 2 = humidifying, 3 = dehumidifying
        let mode = currentState == 3 ? "dehumidify" : "humidify"
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: true)
            ?? IconResolver.icon(for: serviceData, filled: true)
    }

    private func updateModeButtons() {
        modeButtonHumidify.isSelected = (targetState == 1)
        modeButtonDehumidify.isSelected = (targetState == 2)
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isActive = sender.isOn
        if let id = activeId {
            bridge?.writeCharacteristic(identifier: id, value: isActive ? 1 : 0)
            notifyLocalChange(characteristicId: id, value: isActive ? 1 : 0)
        }
        updateUI()
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        targetState = sender.tag
        updateModeButtons()
        updateThresholdLabel()
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
            notifyLocalChange(characteristicId: id, value: targetState)
        }
    }

    @objc private func swingTapped(_ sender: NSButton) {
        swingMode = swingMode == 0 ? 1 : 0
        if let id = swingModeId {
            bridge?.writeCharacteristic(identifier: id, value: swingMode)
            notifyLocalChange(characteristicId: id, value: swingMode)
        }
        updateSwingButton()
    }

    private func updateSwingButton() {
        swingButton?.isSelected = swingMode == 1
    }

    // MARK: - Threshold controls

    private func updateThresholdLabel() {
        // Show the appropriate threshold based on current mode
        // targetState: 1=humidifier, 2=dehumidifier
        let threshold = targetState == 2 ? dehumidifierThreshold : humidifierThreshold
        thresholdLabel?.stringValue = String(format: "%.0f%%", threshold)
    }

    @objc private func decreaseThreshold(_ sender: NSButton) {
        // targetState: 1=humidifier, 2=dehumidifier
        if targetState == 2 {
            let clamped = min(max(dehumidifierThreshold - 5, 0), 100)
            dehumidifierThreshold = clamped
            updateThresholdLabel()
            if let id = dehumidifierThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
                notifyLocalChange(characteristicId: id, value: Float(clamped))
            }
        } else {
            let clamped = min(max(humidifierThreshold - 5, 0), 100)
            humidifierThreshold = clamped
            updateThresholdLabel()
            if let id = humidifierThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
                notifyLocalChange(characteristicId: id, value: Float(clamped))
            }
        }
    }

    @objc private func increaseThreshold(_ sender: NSButton) {
        if targetState == 2 {
            let clamped = min(max(dehumidifierThreshold + 5, 0), 100)
            dehumidifierThreshold = clamped
            updateThresholdLabel()
            if let id = dehumidifierThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
                notifyLocalChange(characteristicId: id, value: Float(clamped))
            }
        } else {
            let clamped = min(max(humidifierThreshold + 5, 0), 100)
            humidifierThreshold = clamped
            updateThresholdLabel()
            if let id = humidifierThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
                notifyLocalChange(characteristicId: id, value: Float(clamped))
            }
        }
    }
}
