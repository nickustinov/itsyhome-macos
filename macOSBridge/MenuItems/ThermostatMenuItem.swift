//
//  ThermostatMenuItem.swift
//  macOSBridge
//
//  Menu item for thermostat controls (Off/Heat/Cool/Auto modes + target temperature)
//

import AppKit

class ThermostatMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentTempId: UUID?
    private var targetTempId: UUID?
    private var currentStateId: UUID?      // What it's doing (0=off, 1=heating, 2=cooling)
    private var targetStateId: UUID?       // User-selected mode (0=off, 1=heat, 2=cool, 3=auto)

    private var currentTemp: Double = 0
    private var targetTemp: Double = 20
    private var currentState: Int = 0      // 0=off, 1=heating, 2=cooling
    private var targetState: Int = 0       // 0=off, 1=heat, 2=cool, 3=auto

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when not off)
    private let controlsRow: NSView
    private let modeButtonHeat: ModeButton
    private let modeButtonCool: ModeButton
    private let modeButtonAuto: ModeButton
    private let minusButton: NSButton
    private let targetLabel: NSTextField
    private let plusButton: NSButton

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let expandedHeight: CGFloat = DS.ControlSize.menuItemHeight + 36

    // Remember last active mode when toggling off/on
    private var lastActiveMode: Int = 1  // Default to heat

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentTempId { ids.append(id) }
        if let id = targetTempId { ids.append(id) }
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentTempId = serviceData.currentTemperatureId.flatMap { UUID(uuidString: $0) }
        self.targetTempId = serviceData.targetTemperatureId.flatMap { UUID(uuidString: $0) }
        self.currentStateId = serviceData.heatingCoolingStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateId = serviceData.targetHeatingCoolingStateId.flatMap { UUID(uuidString: $0) }

        // Create wrapper view - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current temp, power toggle
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
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

        // Controls row (initially hidden)
        controlsRow = NSView(frame: NSRect(x: 0, y: DS.Spacing.sm, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Mode buttons container (pill-shaped dark background) - Heat/Cool/Auto only
        let buttonWidth: CGFloat = 36
        let buttonHeight: CGFloat = 18
        let containerPadding: CGFloat = 2
        let modeContainerWidth = buttonWidth * 3 + containerPadding * 2
        let modeContainerHeight = buttonHeight + containerPadding * 2

        let modeContainer = NSView(frame: NSRect(x: labelX, y: 3, width: modeContainerWidth, height: modeContainerHeight))
        modeContainer.wantsLayer = true
        modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        modeContainer.layer?.cornerRadius = modeContainerHeight / 2

        modeButtonCool = ModeButton(title: "Cool", color: DS.Colors.thermostatCool)
        modeButtonCool.frame = NSRect(x: containerPadding, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonCool.tag = 2
        modeContainer.addSubview(modeButtonCool)

        modeButtonHeat = ModeButton(title: "Heat", color: DS.Colors.thermostatHeat)
        modeButtonHeat.frame = NSRect(x: containerPadding + buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonHeat.tag = 1
        modeContainer.addSubview(modeButtonHeat)

        modeButtonAuto = ModeButton(title: "Auto", color: DS.Colors.success)
        modeButtonAuto.frame = NSRect(x: containerPadding + buttonWidth * 2, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonAuto.tag = 3
        modeContainer.addSubview(modeButtonAuto)

        controlsRow.addSubview(modeContainer)

        // Set initial selection
        modeButtonHeat.isSelected = true

        // Temperature controls: - | temp | +
        let tempControlsX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 78
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let buttonBgAlpha: CGFloat = isDark ? 0.2 : 0.08
        let buttonFont = NSFont.systemFont(ofSize: 12, weight: .bold)

        // Minus button
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
        targetLabel = NSTextField(labelWithString: "20°")
        targetLabel.frame = NSRect(x: tempControlsX + 22, y: 5, width: 32, height: 17)
        targetLabel.font = DS.Typography.labelSmall
        targetLabel.textColor = .secondaryLabelColor
        targetLabel.alignment = .center
        controlsRow.addSubview(targetLabel)

        // Plus button
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
            self.togglePower()
        }

        // Set up actions
        powerToggle.target = self
        powerToggle.action = #selector(powerToggleChanged(_:))

        modeButtonHeat.target = self
        modeButtonHeat.action = #selector(modeChanged(_:))
        modeButtonCool.target = self
        modeButtonCool.action = #selector(modeChanged(_:))
        modeButtonAuto.target = self
        modeButtonAuto.action = #selector(modeChanged(_:))

        minusButton.target = self
        minusButton.action = #selector(decreaseTemp(_:))

        plusButton.target = self
        plusButton.action = #selector(increaseTemp(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentTempId {
            if let temp = ValueConversion.toDouble(value) {
                currentTemp = temp
                tempLabel.stringValue = TemperatureFormatter.format(temp, decimals: 1)
            }
        } else if characteristicId == targetTempId {
            if let temp = ValueConversion.toDouble(value) {
                targetTemp = temp
                targetLabel.stringValue = TemperatureFormatter.format(temp)
            }
        } else if characteristicId == currentStateId {
            if let state = ValueConversion.toInt(value) {
                currentState = state
                updateStateIcon()
            }
        } else if characteristicId == targetStateId {
            if let state = ValueConversion.toInt(value) {
                targetState = state
                if state != 0 {
                    lastActiveMode = state
                }
                updateModeButtons()
                updateUI()
            }
        }
    }

    private func updateUI() {
        let isActive = targetState != 0
        powerToggle.setOn(isActive, animated: false)
        controlsRow.isHidden = !isActive

        // Resize container
        let newHeight = isActive ? expandedHeight : collapsedHeight
        containerView.frame.size.height = newHeight

        // Reposition row 1 elements
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
        // Show icon based on current state (what it's actually doing)
        if targetState == 0 {
            iconView.image = IconResolver.icon(for: serviceData, filled: false)
            return
        }

        // currentState: 0=off, 1=heating, 2=cooling
        let mode: String = switch currentState {
        case 1: "heat"
        case 2: "cool"
        default: targetState == 1 ? "heat" : (targetState == 2 ? "cool" : "auto")
        }
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: true)
            ?? IconResolver.icon(for: serviceData, filled: true)
    }

    private func updateModeButtons() {
        modeButtonHeat.isSelected = (targetState == 1)
        modeButtonCool.isSelected = (targetState == 2)
        modeButtonAuto.isSelected = (targetState == 3)
    }

    private func togglePower() {
        if targetState == 0 {
            // Turn on - restore last active mode
            setMode(lastActiveMode)
        } else {
            // Turn off
            setMode(0)
        }
    }

    private func setMode(_ mode: Int) {
        targetState = mode
        if mode != 0 {
            lastActiveMode = mode
        }
        updateModeButtons()
        updateUI()
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: mode)
            notifyLocalChange(characteristicId: id, value: mode)
        }
    }

    private func setTargetTemp(_ temp: Double) {
        let clamped = min(max(temp, 10), 30)
        targetTemp = clamped
        targetLabel.stringValue = TemperatureFormatter.format(clamped)
        if let id = targetTempId {
            bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
            notifyLocalChange(characteristicId: id, value: Float(clamped))
        }
    }

    @objc private func powerToggleChanged(_ sender: ToggleSwitch) {
        if sender.isOn {
            setMode(lastActiveMode)
        } else {
            setMode(0)
        }
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        setMode(sender.tag)
    }

    @objc private func decreaseTemp(_ sender: NSButton) {
        setTargetTemp(targetTemp - 0.5)
    }

    @objc private func increaseTemp(_ sender: NSButton) {
        setTargetTemp(targetTemp + 0.5)
    }
}
