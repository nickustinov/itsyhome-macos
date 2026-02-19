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
    private var coolingThresholdId: UUID?
    private var heatingThresholdId: UUID?

    private var currentTemp: Double = 0
    private var targetTemp: Double = 20
    private var currentState: Int = 0      // 0=off, 1=heating, 2=cooling
    private var targetState: Int = 0       // 0=off, 1=heat, 2=cool, 3=auto
    private var coolingThreshold: Double = 24
    private var heatingThreshold: Double = 18

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when not off)
    private let controlsRow: NSView
    private var modeButtonHeat: ModeButton?
    private var modeButtonCool: ModeButton?
    private var modeButtonAuto: ModeButton?

    // Single temp control (Heat/Cool modes)
    private let singleTempContainer: NSView
    private let minusButton: NSButton
    private let targetLabel: NSTextField
    private let plusButton: NSButton

    // Range control (Auto mode): -18+ -24+
    private let rangeTempContainer: NSView
    private let heatMinusButton: NSButton
    private let heatLabel: NSTextField
    private let heatPlusButton: NSButton
    private let coolMinusButton: NSButton
    private let coolLabel: NSTextField
    private let coolPlusButton: NSButton

    private let hasThresholds: Bool
    private let hideModeSelector: Bool
    private let activeModes: [Int]  // Valid non-off target states (1=heat, 2=cool, 3=auto)

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
        if let id = coolingThresholdId { ids.append(id) }
        if let id = heatingThresholdId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentTempId = serviceData.currentTemperatureId?.uuid
        self.targetTempId = serviceData.targetTemperatureId?.uuid
        self.currentStateId = serviceData.heatingCoolingStateId?.uuid
        self.targetStateId = serviceData.targetHeatingCoolingStateId?.uuid
        self.coolingThresholdId = serviceData.coolingThresholdTemperatureId?.uuid
        self.heatingThresholdId = serviceData.heatingThresholdTemperatureId?.uuid
        self.hasThresholds = coolingThresholdId != nil && heatingThresholdId != nil

        // Determine valid active modes: filter out off (0), default to all 3
        let allStates = serviceData.validTargetHeatingCoolingStates ?? [0, 1, 2, 3]
        self.activeModes = allStates.filter { $0 != 0 }
        self.hideModeSelector = activeModes.count <= 1

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
        let tempWidth: CGFloat = 31
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

        // Controls row (initially hidden)
        controlsRow = NSView(frame: NSRect(x: 0, y: DS.Spacing.sm, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Mode buttons container
        let modeCount = activeModes.count
        let containerWidth = ModeButtonGroup.widthForButtons(count: max(modeCount, 1))
        let modeContainer = ModeButtonGroup(frame: NSRect(x: labelX, y: 3, width: containerWidth, height: 22))

        if activeModes.contains(2) {
            modeButtonCool = modeContainer.addButton(title: String(localized: "device.climate.cool", defaultValue: "Cool", bundle: .macOSBridge), color: DS.Colors.thermostatCool, tag: 2)
        }
        if activeModes.contains(1) {
            modeButtonHeat = modeContainer.addButton(title: String(localized: "device.climate.heat", defaultValue: "Heat", bundle: .macOSBridge), color: DS.Colors.thermostatHeat, tag: 1)
        }
        if activeModes.contains(3) {
            modeButtonAuto = modeContainer.addButton(title: String(localized: "device.climate.auto", defaultValue: "Auto", bundle: .macOSBridge), color: DS.Colors.success, tag: 3)
        }

        controlsRow.addSubview(modeContainer)

        if hideModeSelector {
            modeContainer.isHidden = true
        }

        // Set initial last active mode to first valid active mode
        if let firstActive = activeModes.first {
            lastActiveMode = firstActive
        }

        // Single temperature control: [−] 20° [+]
        let singleTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 78
        singleTempContainer = NSView(frame: NSRect(x: singleTempX, y: 0, width: 78, height: 26))

        minusButton = StepperButton.create(title: "−", size: .regular)
        minusButton.frame.origin = NSPoint(x: 0, y: 4)
        singleTempContainer.addSubview(minusButton)

        targetLabel = NSTextField(labelWithString: "20°")
        targetLabel.frame = NSRect(x: 22, y: 5, width: 32, height: 17)
        targetLabel.font = DS.Typography.labelSmall
        targetLabel.textColor = .secondaryLabelColor
        targetLabel.alignment = .center
        singleTempContainer.addSubview(targetLabel)

        plusButton = StepperButton.create(title: "+", size: .regular)
        plusButton.frame.origin = NSPoint(x: 56, y: 4)
        singleTempContainer.addSubview(plusButton)

        controlsRow.addSubview(singleTempContainer)

        // Range temperature control: -18+ -24+ (for Auto mode with thresholds)
        let miniBtn: CGFloat = 11
        let miniLabel: CGFloat = 24
        let miniStepper = miniBtn + miniLabel + miniBtn  // 44
        let rangeWidth = miniStepper * 2 + 6  // 94
        let rangeTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - rangeWidth
        rangeTempContainer = NSView(frame: NSRect(x: rangeTempX, y: 1, width: rangeWidth, height: 26))
        rangeTempContainer.isHidden = true

        // Heat stepper (left): -18+
        heatMinusButton = StepperButton.create(title: "−", size: .mini)
        heatMinusButton.frame.origin = NSPoint(x: 0, y: 8)
        rangeTempContainer.addSubview(heatMinusButton)

        heatLabel = NSTextField(labelWithString: "18°")
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
            self.togglePower()
        }

        // Set up actions
        powerToggle.target = self
        powerToggle.action = #selector(powerToggleChanged(_:))

        modeButtonHeat?.target = self
        modeButtonHeat?.action = #selector(modeChanged(_:))
        modeButtonCool?.target = self
        modeButtonCool?.action = #selector(modeChanged(_:))
        modeButtonAuto?.target = self
        modeButtonAuto?.action = #selector(modeChanged(_:))

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
        } else if characteristicId == coolingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                coolingThreshold = temp
                coolLabel.stringValue = TemperatureFormatter.format(temp)
            }
        } else if characteristicId == heatingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                heatingThreshold = temp
                heatLabel.stringValue = TemperatureFormatter.format(temp)
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
        tempLabel.frame.origin.y = labelY - 2
        powerToggle.frame.origin.y = switchY

        // Show range control in Auto mode with thresholds, single control otherwise
        let showRange = targetState == 3 && hasThresholds
        singleTempContainer.isHidden = showRange
        rangeTempContainer.isHidden = !showRange

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
        modeButtonHeat?.isSelected = (targetState == 1)
        modeButtonCool?.isSelected = (targetState == 2)
        modeButtonAuto?.isSelected = (targetState == 3)
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
        setTargetTemp(targetTemp - 1)
    }

    @objc private func increaseTemp(_ sender: NSButton) {
        setTargetTemp(targetTemp + 1)
    }

    // MARK: - Threshold controls (Auto mode)

    private func setHeatingThreshold(_ temp: Double) {
        let maxHeat = coolingThreshold - 1
        let clamped = min(max(temp, 10), maxHeat)
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
