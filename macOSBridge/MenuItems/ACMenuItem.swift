//
//  ACMenuItem.swift
//  macOSBridge
//
//  Menu item for AC / HeaterCooler controls
//

import AppKit

class ACMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var activeId: UUID?
    private var currentTempId: UUID?
    private var currentStateId: UUID?
    private var targetStateId: UUID?
    private var coolingThresholdId: UUID?
    private var heatingThresholdId: UUID?

    private var isActive: Bool = false
    private var currentTemp: Double = 0
    private var currentState: Int = 0  // 0=inactive, 1=idle, 2=heating, 3=cooling
    private var targetState: Int = 0   // 0=auto, 1=heat, 2=cool
    private var coolingThreshold: Double = 24
    private var heatingThreshold: Double = 20

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when active)
    private let controlsRow: NSView
    private let modeButtonAuto: ModeButton
    private let modeButtonHeat: ModeButton
    private let modeButtonCool: ModeButton
    private let minusButton: NSButton
    private let targetLabel: NSTextField
    private let plusButton: NSButton

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let expandedHeight: CGFloat = DS.ControlSize.menuItemHeight + 36

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = currentTempId { ids.append(id) }
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        if let id = coolingThresholdId { ids.append(id) }
        if let id = heatingThresholdId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId.flatMap { UUID(uuidString: $0) }
        self.currentTempId = serviceData.currentTemperatureId.flatMap { UUID(uuidString: $0) }
        self.currentStateId = serviceData.currentHeaterCoolerStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateId = serviceData.targetHeaterCoolerStateId.flatMap { UUID(uuidString: $0) }
        self.coolingThresholdId = serviceData.coolingThresholdTemperatureId.flatMap { UUID(uuidString: $0) }
        self.heatingThresholdId = serviceData.heatingThresholdTemperatureId.flatMap { UUID(uuidString: $0) }

        // Create wrapper view (full width for menu sizing) - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current temp, power toggle (centered vertically)
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = PhosphorIcon.regular("thermometer")
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Power toggle position (calculate first for alignment)
        let switchX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.switchWidth

        // Current temp position (right-aligned before toggle)
        let tempWidth: CGFloat = 50
        let tempX = switchX - tempWidth - DS.Spacing.sm

        // Name label (fills space up to temp label)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (collapsedHeight - 17) / 2
        let labelWidth = tempX - labelX - DS.Spacing.xs
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Current temp
        tempLabel = NSTextField(labelWithString: "--°")
        tempLabel.frame = NSRect(x: tempX, y: labelY, width: tempWidth, height: 17)
        tempLabel.font = DS.Typography.labelSmall
        tempLabel.textColor = .secondaryLabelColor
        tempLabel.alignment = .right
        containerView.addSubview(tempLabel)

        // Power toggle
        let switchY = (collapsedHeight - DS.ControlSize.switchHeight) / 2
        powerToggle = ToggleSwitch()
        powerToggle.frame = NSRect(x: switchX,
                                   y: switchY,
                                   width: DS.ControlSize.switchWidth,
                                   height: DS.ControlSize.switchHeight)
        containerView.addSubview(powerToggle)

        // Controls row (initially hidden, with bottom padding)
        controlsRow = NSView(frame: NSRect(x: 0, y: DS.Spacing.sm, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Mode buttons container (pill-shaped dark background)
        let buttonWidth: CGFloat = 36
        let buttonHeight: CGFloat = 18
        let containerPadding: CGFloat = 2
        let modeContainerWidth = buttonWidth * 3 + containerPadding * 2
        let modeContainerHeight = buttonHeight + containerPadding * 2

        let modeContainer = NSView(frame: NSRect(x: labelX, y: 3, width: modeContainerWidth, height: modeContainerHeight))
        modeContainer.wantsLayer = true
        modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        modeContainer.layer?.cornerRadius = modeContainerHeight / 2

        modeButtonAuto = ModeButton(title: "Auto", color: DS.Colors.success)  // Green
        modeButtonAuto.frame = NSRect(x: containerPadding, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonAuto.tag = 0
        modeContainer.addSubview(modeButtonAuto)

        modeButtonHeat = ModeButton(title: "Heat", color: DS.Colors.thermostatHeat)  // Orange
        modeButtonHeat.frame = NSRect(x: containerPadding + buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonHeat.tag = 1
        modeContainer.addSubview(modeButtonHeat)

        modeButtonCool = ModeButton(title: "Cool", color: DS.Colors.thermostatCool)  // Blue
        modeButtonCool.frame = NSRect(x: containerPadding + buttonWidth * 2, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonCool.tag = 2
        modeContainer.addSubview(modeButtonCool)

        controlsRow.addSubview(modeContainer)

        // Set initial selection
        modeButtonAuto.isSelected = true

        // Temperature controls: - | temp | +
        let tempControlsX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 78
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let buttonBgAlpha: CGFloat = isDark ? 0.2 : 0.08
        let buttonFont = NSFont.systemFont(ofSize: 12, weight: .bold)

        // Minus button (small rounded square)
        minusButton = NSButton(frame: NSRect(x: tempControlsX, y: 4, width: 20, height: 20))
        minusButton.isBordered = false
        minusButton.wantsLayer = true
        minusButton.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(buttonBgAlpha).cgColor
        minusButton.layer?.cornerRadius = 4
        if isDark {
            minusButton.attributedTitle = NSAttributedString(string: "−", attributes: [.foregroundColor: NSColor.white, .font: buttonFont])
        } else {
            minusButton.title = "−"
            minusButton.font = buttonFont
            minusButton.contentTintColor = .secondaryLabelColor
        }
        controlsRow.addSubview(minusButton)

        // Target temp label
        targetLabel = NSTextField(labelWithString: "24°")
        targetLabel.frame = NSRect(x: tempControlsX + 22, y: 5, width: 32, height: 17)
        targetLabel.font = DS.Typography.labelSmall
        targetLabel.textColor = .secondaryLabelColor
        targetLabel.alignment = .center
        controlsRow.addSubview(targetLabel)

        // Plus button (small rounded square)
        plusButton = NSButton(frame: NSRect(x: tempControlsX + 56, y: 4, width: 20, height: 20))
        plusButton.isBordered = false
        plusButton.wantsLayer = true
        plusButton.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(buttonBgAlpha).cgColor
        plusButton.layer?.cornerRadius = 4
        if isDark {
            plusButton.attributedTitle = NSAttributedString(string: "+", attributes: [.foregroundColor: NSColor.white, .font: buttonFont])
        } else {
            plusButton.title = "+"
            plusButton.font = buttonFont
            plusButton.contentTintColor = .secondaryLabelColor
        }
        controlsRow.addSubview(plusButton)

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

        modeButtonAuto.target = self
        modeButtonAuto.action = #selector(modeChanged(_:))
        modeButtonHeat.target = self
        modeButtonHeat.action = #selector(modeChanged(_:))
        modeButtonCool.target = self
        modeButtonCool.action = #selector(modeChanged(_:))

        minusButton.target = self
        minusButton.action = #selector(decreaseTemp(_:))

        plusButton.target = self
        plusButton.action = #selector(increaseTemp(_:))
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
        } else if characteristicId == currentTempId {
            if let temp = ValueConversion.toDouble(value) {
                currentTemp = temp
                tempLabel.stringValue = TemperatureFormatter.format(temp, decimals: 1)
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
                updateTargetDisplay()
            }
        } else if characteristicId == coolingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                coolingThreshold = temp
                updateTargetDisplay()
            }
        } else if characteristicId == heatingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                heatingThreshold = temp
                updateTargetDisplay()
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
        tempLabel.frame.origin.y = labelY
        powerToggle.frame.origin.y = switchY

        updateStateIcon()
    }

    private func updateStateIcon() {
        // Show icon based on target mode (what user selected), not current operation state
        let (iconName, color): (String, NSColor) = {
            if !isActive {
                return ("thermometer", DS.Colors.mutedForeground)
            }
            // targetState: 0 = auto, 1 = heat, 2 = cool
            switch targetState {
            case 1: return ("fire", DS.Colors.thermostatHeat)
            case 2: return ("snowflake", DS.Colors.thermostatCool)
            default: return ("arrows-left-right", DS.Colors.success)  // auto mode
            }
        }()
        iconView.image = PhosphorIcon.icon(iconName, filled: isActive)
    }

    private func updateModeButtons() {
        modeButtonAuto.isSelected = (targetState == 0)
        modeButtonHeat.isSelected = (targetState == 1)
        modeButtonCool.isSelected = (targetState == 2)
    }

    private func updateTargetDisplay() {
        let targetTemp: Double
        switch targetState {
        case 1: targetTemp = heatingThreshold  // heat mode
        case 2: targetTemp = coolingThreshold  // cool mode
        default: targetTemp = coolingThreshold // auto - show cooling threshold
        }
        targetLabel.stringValue = TemperatureFormatter.format(targetTemp)
    }

    private func currentTargetTemp() -> Double {
        switch targetState {
        case 1: return heatingThreshold
        case 2: return coolingThreshold
        default: return coolingThreshold
        }
    }

    private func setTargetTemp(_ temp: Double) {
        let clamped = min(max(temp, 16), 30)

        switch targetState {
        case 1: // heat mode
            heatingThreshold = clamped
            if let id = heatingThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
                notifyLocalChange(characteristicId: id, value: Float(clamped))
            }
        default: // cool or auto
            coolingThreshold = clamped
            if let id = coolingThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
                notifyLocalChange(characteristicId: id, value: Float(clamped))
            }
        }
        updateTargetDisplay()
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
        updateStateIcon()
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
            notifyLocalChange(characteristicId: id, value: targetState)
        }
        updateTargetDisplay()
    }

    @objc private func decreaseTemp(_ sender: NSButton) {
        setTargetTemp(currentTargetTemp() - 1)
    }

    @objc private func increaseTemp(_ sender: NSButton) {
        setTargetTemp(currentTargetTemp() + 1)
    }
}
