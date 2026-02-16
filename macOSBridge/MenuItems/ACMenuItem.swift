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
    private var swingModeId: UUID?

    private var isActive: Bool = false
    private var currentTemp: Double = 0
    private var currentState: Int = 0  // 0=inactive, 1=idle, 2=heating, 3=cooling
    private var targetState: Int = 0   // 0=auto, 1=heat, 2=cool
    private var coolingThreshold: Double = 24
    private var heatingThreshold: Double = 20
    private var swingMode: Int = 0     // 0=DISABLED, 1=ENABLED

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when active)
    private let controlsRow: NSView
    private var modeButtonAuto: ModeButton?
    private var modeButtonHeat: ModeButton?
    private var modeButtonCool: ModeButton?
    private var swingButtonGroup: ModeButtonGroup?
    private var swingButton: ModeButton?

    // Single temp control (Heat/Cool modes)
    private let singleTempContainer: NSView
    private let minusButton: NSButton
    private let targetLabel: NSTextField
    private let plusButton: NSButton

    // Range control (Auto mode): -20+ -24+
    private let rangeTempContainer: NSView
    private let heatMinusButton: NSButton
    private let heatLabel: NSTextField
    private let heatPlusButton: NSButton
    private let coolMinusButton: NSButton
    private let coolLabel: NSTextField
    private let coolPlusButton: NSButton

    private let hasThresholds: Bool
    private let hideModeSelector: Bool
    private let validModes: [Int]  // Valid target states (0=auto, 1=heat, 2=cool)

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
        if let id = swingModeId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId?.uuid
        self.currentTempId = serviceData.currentTemperatureId?.uuid
        self.currentStateId = serviceData.currentHeaterCoolerStateId?.uuid
        self.targetStateId = serviceData.targetHeaterCoolerStateId?.uuid
        self.coolingThresholdId = serviceData.coolingThresholdTemperatureId?.uuid
        self.heatingThresholdId = serviceData.heatingThresholdTemperatureId?.uuid
        self.swingModeId = serviceData.swingModeId?.uuid
        self.hasThresholds = coolingThresholdId != nil && heatingThresholdId != nil

        // Determine valid modes: all 3 by default, or filtered by validValues
        let allModes = serviceData.validTargetHeaterCoolerStates ?? [0, 1, 2]
        self.validModes = allModes
        self.hideModeSelector = allModes.count <= 1

        // Create wrapper view (full width for menu sizing) - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current temp, power toggle (centered vertically)
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

        // Current temp position (before swing button or toggle)
        let tempWidth: CGFloat = 31
        let tempX = (swingModeId != nil ? swingGroupX : switchX) - tempWidth - DS.Spacing.sm

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

        // Swing button group (on Row 1, before temp)
        if swingModeId != nil {
            let swingY = (collapsedHeight - 18) / 2
            let swingGroup = ModeButtonGroup(frame: NSRect(x: swingGroupX, y: swingY, width: swingGroupWidth, height: 18))
            swingButton = swingGroup.addButton(icon: "angle", color: DS.Colors.sliderFan)
            containerView.addSubview(swingGroup)
            swingButtonGroup = swingGroup
        }

        // Current temp
        tempLabel = NSTextField(labelWithString: "--°")
        tempLabel.frame = NSRect(x: tempX, y: labelY - 2, width: tempWidth, height: 17)
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

        // Mode buttons container
        let modeCount = validModes.count
        let containerWidth = ModeButtonGroup.widthForButtons(count: max(modeCount, 1))
        let modeContainer = ModeButtonGroup(frame: NSRect(x: labelX, y: 3, width: containerWidth, height: 22))

        if validModes.contains(2) {
            modeButtonCool = modeContainer.addButton(title: "Cool", color: DS.Colors.thermostatCool, tag: 2)
        }
        if validModes.contains(1) {
            modeButtonHeat = modeContainer.addButton(title: "Heat", color: DS.Colors.thermostatHeat, tag: 1)
        }
        if validModes.contains(0) {
            modeButtonAuto = modeContainer.addButton(title: "Auto", color: DS.Colors.success, tag: 0)
        }

        controlsRow.addSubview(modeContainer)

        if hideModeSelector {
            modeContainer.isHidden = true
        }

        // Set initial target state to first valid mode
        if let firstMode = validModes.first {
            targetState = firstMode
        }

        // Single temperature control: [−] 24° [+]
        let singleTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 78
        singleTempContainer = NSView(frame: NSRect(x: singleTempX, y: 0, width: 78, height: 26))

        minusButton = StepperButton.create(title: "−", size: .regular)
        minusButton.frame.origin = NSPoint(x: 0, y: 4)
        singleTempContainer.addSubview(minusButton)

        targetLabel = NSTextField(labelWithString: "24°")
        targetLabel.frame = NSRect(x: 22, y: 5, width: 32, height: 17)
        targetLabel.font = DS.Typography.labelSmall
        targetLabel.textColor = .secondaryLabelColor
        targetLabel.alignment = .center
        singleTempContainer.addSubview(targetLabel)

        plusButton = StepperButton.create(title: "+", size: .regular)
        plusButton.frame.origin = NSPoint(x: 56, y: 4)
        singleTempContainer.addSubview(plusButton)

        controlsRow.addSubview(singleTempContainer)

        // Range temperature control: -20+ -24+ (for Auto mode with thresholds)
        let miniBtn: CGFloat = 11
        let miniLabel: CGFloat = 24
        let miniStepper = miniBtn + miniLabel + miniBtn  // 46
        let rangeWidth = miniStepper * 2 + 6  // 98
        let rangeTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - rangeWidth
        rangeTempContainer = NSView(frame: NSRect(x: rangeTempX, y: 1, width: rangeWidth, height: 26))
        rangeTempContainer.isHidden = true

        // Heat stepper (left): -20+
        heatMinusButton = StepperButton.create(title: "−", size: .mini)
        heatMinusButton.frame.origin = NSPoint(x: 0, y: 8)
        rangeTempContainer.addSubview(heatMinusButton)

        heatLabel = NSTextField(labelWithString: "20°")
        heatLabel.frame = NSRect(x: miniBtn, y: 6, width: miniLabel, height: 14)
        heatLabel.font = DS.Typography.labelSmall
        heatLabel.textColor = .secondaryLabelColor
        heatLabel.alignment = .center
        rangeTempContainer.addSubview(heatLabel)

        heatPlusButton = StepperButton.create(title: "+", size: .mini)
        heatPlusButton.frame.origin = NSPoint(x: miniBtn + miniLabel, y: 8)
        rangeTempContainer.addSubview(heatPlusButton)

        // Cool stepper (right): -24+
        let coolX = miniStepper + 6
        coolMinusButton = StepperButton.create(title: "−", size: .mini)
        coolMinusButton.frame.origin = NSPoint(x: coolX, y: 8)
        rangeTempContainer.addSubview(coolMinusButton)

        coolLabel = NSTextField(labelWithString: "24°")
        coolLabel.frame = NSRect(x: coolX + miniBtn, y: 6, width: miniLabel, height: 14)
        coolLabel.font = DS.Typography.labelSmall
        coolLabel.textColor = .secondaryLabelColor
        coolLabel.alignment = .center
        rangeTempContainer.addSubview(coolLabel)

        coolPlusButton = StepperButton.create(title: "+", size: .mini)
        coolPlusButton.frame.origin = NSPoint(x: coolX + miniBtn + miniLabel, y: 8)
        rangeTempContainer.addSubview(coolPlusButton)

        controlsRow.addSubview(rangeTempContainer)

        containerView.addSubview(controlsRow)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView
        updateModeButtons()

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

        modeButtonAuto?.target = self
        modeButtonAuto?.action = #selector(modeChanged(_:))
        modeButtonHeat?.target = self
        modeButtonHeat?.action = #selector(modeChanged(_:))
        modeButtonCool?.target = self
        modeButtonCool?.action = #selector(modeChanged(_:))

        minusButton.target = self
        minusButton.action = #selector(decreaseTemp(_:))

        plusButton.target = self
        plusButton.action = #selector(increaseTemp(_:))

        heatMinusButton.target = self
        heatMinusButton.action = #selector(decreaseHeatThreshold(_:))
        heatPlusButton.target = self
        heatPlusButton.action = #selector(increaseHeatThreshold(_:))

        coolMinusButton.target = self
        coolMinusButton.action = #selector(decreaseCoolThreshold(_:))
        coolPlusButton.target = self
        coolPlusButton.action = #selector(increaseCoolThreshold(_:))

        swingButton?.target = self
        swingButton?.action = #selector(swingTapped(_:))
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
                coolLabel.stringValue = TemperatureFormatter.format(temp)
                updateTargetDisplay()
            }
        } else if characteristicId == heatingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                heatingThreshold = temp
                heatLabel.stringValue = TemperatureFormatter.format(temp)
                updateTargetDisplay()
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
        tempLabel.frame.origin.y = labelY - 2
        powerToggle.frame.origin.y = switchY
        if let swingGroup = swingButtonGroup {
            swingGroup.frame.origin.y = topAreaY + (collapsedHeight - 18) / 2
        }

        // Show range control in Auto mode with thresholds, single control otherwise
        let showRange = targetState == 0 && hasThresholds
        singleTempContainer.isHidden = showRange
        rangeTempContainer.isHidden = !showRange

        updateStateIcon()
    }

    private func updateStateIcon() {
        // Show icon based on target mode (what user selected), not current operation state
        if !isActive {
            // Off - use custom/default icon
            iconView.image = IconResolver.icon(for: serviceData, filled: false)
            return
        }
        // Get mode icon from centralized config (mode icons don't use custom icons)
        // targetState: 0 = auto, 1 = heat, 2 = cool
        let mode: String = switch targetState {
        case 1: "heat"
        case 2: "cool"
        default: "auto"
        }
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: true)
            ?? IconResolver.icon(for: serviceData, filled: true)
    }

    private func updateModeButtons() {
        modeButtonAuto?.isSelected = (targetState == 0)
        modeButtonHeat?.isSelected = (targetState == 1)
        modeButtonCool?.isSelected = (targetState == 2)
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
        // Toggle between single/range controls based on mode
        let showRange = targetState == 0 && hasThresholds
        singleTempContainer.isHidden = showRange
        rangeTempContainer.isHidden = !showRange
        updateTargetDisplay()
    }

    @objc private func decreaseTemp(_ sender: NSButton) {
        setTargetTemp(currentTargetTemp() - 1)
    }

    @objc private func increaseTemp(_ sender: NSButton) {
        setTargetTemp(currentTargetTemp() + 1)
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

    // MARK: - Threshold controls (Auto mode)

    private func setHeatingThreshold(_ temp: Double) {
        let maxHeat = coolingThreshold - 1
        let clamped = min(max(temp, 16), maxHeat)
        heatingThreshold = clamped
        heatLabel.stringValue = TemperatureFormatter.format(clamped)
        if let id = heatingThresholdId {
            bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
            notifyLocalChange(characteristicId: id, value: Float(clamped))
        }
    }

    private func setCoolingThreshold(_ temp: Double) {
        let minCool = heatingThreshold + 1
        let clamped = min(max(temp, minCool), 30)
        coolingThreshold = clamped
        coolLabel.stringValue = TemperatureFormatter.format(clamped)
        if let id = coolingThresholdId {
            bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
            notifyLocalChange(characteristicId: id, value: Float(clamped))
        }
    }

    @objc private func decreaseHeatThreshold(_ sender: NSButton) {
        setHeatingThreshold(heatingThreshold - 1)
    }

    @objc private func increaseHeatThreshold(_ sender: NSButton) {
        setHeatingThreshold(heatingThreshold + 1)
    }

    @objc private func decreaseCoolThreshold(_ sender: NSButton) {
        setCoolingThreshold(coolingThreshold - 1)
    }

    @objc private func increaseCoolThreshold(_ sender: NSButton) {
        setCoolingThreshold(coolingThreshold + 1)
    }
}
