//
//  ClimateMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant climate entities (dynamic HVAC modes + temperature)
//

import AppKit

class ClimateMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentTempId: UUID?
    private var targetTempId: UUID?
    private var currentStateId: UUID?      // What it's doing (0=off, 1=heating, 2=cooling)
    private var targetStateId: UUID?       // User-selected mode (0=off, 1=heat, 2=cool, 3=auto)
    private var coolingThresholdId: UUID?
    private var heatingThresholdId: UUID?
    private var swingModeId: UUID?

    private var currentTemp: Double = 0
    private var targetTemp: Double = 20
    private var currentState: Int = 0      // 0=off, 1=heating, 2=cooling
    private var targetState: Int = 0       // 0=off, 1=heat, 2=cool, 3=auto (HomeKit) or index (HA)
    private var coolingThreshold: Double = 24
    private var heatingThreshold: Double = 18
    private var swingMode: Int = 0         // 0=off, 1=auto

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch
    private var swingButtonGroup: ModeButtonGroup?
    private var swingButton: ModeButton?

    // Controls row (shown when not off)
    private let controlsRow: NSView
    private let modeContainer: ModeButtonGroup

    // Dynamic mode buttons based on available HVAC modes
    private var dynamicModeButtons: [ModeButton] = []
    private var modeOrder: [String] = []  // Maps button index to HA mode string
    private var currentMode: String = "off"  // Current mode string

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
    private let needsThreeRows: Bool  // True if we have 4+ mode buttons
    private let hideModeSelector: Bool  // True if only 1 mode available

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let expandedHeightTwoRows: CGFloat = DS.ControlSize.menuItemHeight + 36
    private let expandedHeightThreeRows: CGFloat = DS.ControlSize.menuItemHeight + 62  // Extra row for temp

    // Remember last active mode when toggling off/on
    private var lastActiveMode: String = "heat"

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentTempId { ids.append(id) }
        if let id = targetTempId { ids.append(id) }
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
        self.currentTempId = serviceData.currentTemperatureId?.uuid
        self.targetTempId = serviceData.targetTemperatureId?.uuid
        self.currentStateId = serviceData.heatingCoolingStateId?.uuid
        self.targetStateId = serviceData.targetHeatingCoolingStateId?.uuid
        self.coolingThresholdId = serviceData.coolingThresholdTemperatureId?.uuid
        self.heatingThresholdId = serviceData.heatingThresholdTemperatureId?.uuid
        self.swingModeId = serviceData.swingModeId?.uuid
        self.hasThresholds = coolingThresholdId != nil && heatingThresholdId != nil

        // Determine if we need 3 rows (4+ mode buttons) or should hide mode selector (1 mode)
        let modes = serviceData.availableHVACModes ?? []
        modeOrder = Self.filterAndOrderModes(modes)
        let modeCount = min(modeOrder.count, 5)
        self.needsThreeRows = modeCount > 3
        self.hideModeSelector = modeCount <= 1

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

        // Current temp
        tempLabel = NSTextField(labelWithString: "--°")
        tempLabel.frame = NSRect(x: tempX, y: labelY - 2, width: tempWidth, height: 17)
        tempLabel.font = DS.Typography.labelSmall
        tempLabel.textColor = .secondaryLabelColor
        tempLabel.alignment = .right
        containerView.addSubview(tempLabel)

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

        // Controls row (initially hidden) - modes row
        // For 3-row mode, this is just for modes; temp controls go in separate row
        let controlsRowY = needsThreeRows ? (DS.Spacing.sm + 26) : DS.Spacing.sm
        controlsRow = NSView(frame: NSRect(x: 0, y: controlsRowY, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Build mode buttons from available HVAC modes
        let buttonCount = max(modeCount, 1)  // At least 1 for layout
        let containerWidth = ModeButtonGroup.widthForButtons(count: buttonCount)
        let modeX = DS.ControlSize.menuItemWidth - DS.Spacing.md - containerWidth
        modeContainer = ModeButtonGroup(frame: NSRect(x: modeX, y: 3, width: containerWidth, height: 22))

        for (index, mode) in modeOrder.prefix(5).enumerated() {
            let (title, color) = Self.titleAndColorForMode(mode)
            let button = modeContainer.addButton(title: title, color: color, tag: index)
            dynamicModeButtons.append(button)
        }

        // Set default last active mode to first non-off mode
        if let firstActive = modeOrder.first(where: { $0 != "off" }) {
            lastActiveMode = firstActive
        }

        controlsRow.addSubview(modeContainer)

        // Hide mode selector if only 1 mode available
        if hideModeSelector {
            modeContainer.isHidden = true
        }

        // Single temperature control: [−] 20° [+]
        let singleTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 78
        // For 3-row mode, temp is at bottom; for 2-row, it's in controlsRow
        let singleTempParentY: CGFloat = needsThreeRows ? DS.Spacing.sm : 0
        singleTempContainer = NSView(frame: NSRect(x: singleTempX, y: singleTempParentY, width: 78, height: 26))

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

        // Range temperature control: -18+ -24+ (for Auto mode with thresholds)
        let smallBtn: CGFloat = 16
        let smallLabel: CGFloat = 28
        let smallStepper = smallBtn + smallLabel + smallBtn  // 60
        let rangeWidth = smallStepper * 2 + 6  // 126
        let rangeTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - rangeWidth
        rangeTempContainer = NSView(frame: NSRect(x: rangeTempX, y: singleTempParentY, width: rangeWidth, height: 26))
        rangeTempContainer.isHidden = true

        // Heat stepper (left): -18+
        heatMinusButton = StepperButton.create(title: "−", size: .small)
        heatMinusButton.frame.origin = NSPoint(x: 0, y: 5)
        rangeTempContainer.addSubview(heatMinusButton)

        heatLabel = NSTextField(labelWithString: "18°")
        heatLabel.frame = NSRect(x: smallBtn, y: 5, width: smallLabel, height: 16)
        heatLabel.font = DS.Typography.labelSmall
        heatLabel.textColor = .secondaryLabelColor
        heatLabel.alignment = .center
        rangeTempContainer.addSubview(heatLabel)

        heatPlusButton = StepperButton.create(title: "+", size: .small)
        heatPlusButton.frame.origin = NSPoint(x: smallBtn + smallLabel, y: 5)
        rangeTempContainer.addSubview(heatPlusButton)

        // Cool stepper (right): -24+
        let coolX = smallStepper + 6
        coolMinusButton = StepperButton.create(title: "−", size: .small)
        coolMinusButton.frame.origin = NSPoint(x: coolX, y: 5)
        rangeTempContainer.addSubview(coolMinusButton)

        coolLabel = NSTextField(labelWithString: "24°")
        coolLabel.frame = NSRect(x: coolX + smallBtn, y: 5, width: smallLabel, height: 16)
        coolLabel.font = DS.Typography.labelSmall
        coolLabel.textColor = .secondaryLabelColor
        coolLabel.alignment = .center
        rangeTempContainer.addSubview(coolLabel)

        coolPlusButton = StepperButton.create(title: "+", size: .small)
        coolPlusButton.frame.origin = NSPoint(x: coolX + smallBtn + smallLabel, y: 5)
        rangeTempContainer.addSubview(coolPlusButton)

        // Add temp controls to correct parent
        if needsThreeRows {
            // Temp controls go directly in containerView (separate row)
            containerView.addSubview(singleTempContainer)
            containerView.addSubview(rangeTempContainer)
        } else {
            // Temp controls go in controlsRow (same row as modes)
            controlsRow.addSubview(singleTempContainer)
            controlsRow.addSubview(rangeTempContainer)
        }

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

        for button in dynamicModeButtons {
            button.target = self
            button.action = #selector(modeButtonPressed(_:))
        }

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

    // MARK: - Mode helpers

    /// Filter and order modes for display (exclude "off", order logically)
    private static func filterAndOrderModes(_ modes: [String]) -> [String] {
        // Define preferred order
        let preferredOrder = ["heat", "cool", "heat_cool", "auto", "dry", "fan_only"]
        var result: [String] = []

        // Add modes in preferred order
        for mode in preferredOrder {
            if modes.contains(mode) {
                result.append(mode)
            }
        }

        // Add any remaining modes we didn't expect
        for mode in modes where mode != "off" && !result.contains(mode) {
            result.append(mode)
        }

        return result
    }

    /// Get display title and color for HA mode
    private static func titleAndColorForMode(_ mode: String) -> (String, NSColor) {
        switch mode {
        case "heat":
            return ("Heat", DS.Colors.thermostatHeat)
        case "cool":
            return ("Cool", DS.Colors.thermostatCool)
        case "heat_cool":
            return ("Heat", DS.Colors.thermostatHeat)  // Dual setpoint, show as Heat
        case "auto":
            return ("Auto", DS.Colors.success)
        case "dry":
            return ("Dry", NSColor.systemTeal)
        case "fan_only":
            return ("Fan", DS.Colors.fanOn)
        default:
            return (mode.capitalized, NSColor.systemGray)
        }
    }

    /// Map HA mode string to HomeKit-style targetState for internal tracking
    private func modeToPseudoState(_ mode: String) -> Int {
        if let index = modeOrder.firstIndex(of: mode) {
            return index + 1  // +1 because 0 is off
        }
        return 0
    }

    /// Check if mode uses range temperature control
    /// Always show range if device has thresholds (HA UI always shows both)
    private func modeUsesRange(_ mode: String) -> Bool {
        if hasThresholds {
            return mode != "off"  // Always show range when on
        }
        return mode == "heat_cool" || mode == "auto"
    }

    // MARK: - Value updates

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
            // Map extended HomeKit values back to mode strings
            // 0=off, 1=heat, 2=cool, 3=heat_cool, 4=dry, 5=fan_only, 6=auto
            if let state = ValueConversion.toInt(value) {
                let mode: String
                switch state {
                case 0: mode = "off"
                case 1: mode = "heat"
                case 2: mode = "cool"
                case 3: mode = "heat_cool"
                case 4: mode = "dry"
                case 5: mode = "fan_only"
                case 6: mode = "auto"
                default: mode = "off"
                }
                currentMode = mode
                if mode != "off" {
                    lastActiveMode = mode
                }
                targetState = modeToPseudoState(mode)
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
        } else if characteristicId == swingModeId {
            if let mode = ValueConversion.toInt(value) {
                swingMode = mode
                updateSwingButton()
            }
        }
    }

    private func updateUI() {
        let isActive = currentMode != "off"
        powerToggle.setOn(isActive, animated: false)
        controlsRow.isHidden = !isActive

        // Show/hide temp controls for 3-row mode (they're in containerView, not controlsRow)
        if needsThreeRows {
            singleTempContainer.isHidden = !isActive
            rangeTempContainer.isHidden = true  // Will be unhidden below if needed
        }

        // Resize container
        let expandedHeight = needsThreeRows ? expandedHeightThreeRows : expandedHeightTwoRows
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
        if let swingGroup = swingButtonGroup {
            swingGroup.frame.origin.y = topAreaY + (collapsedHeight - 18) / 2
        }

        // Show range control when device has thresholds (HA always shows both temps)
        let showRange = modeUsesRange(currentMode) && hasThresholds

        // Handle temp control visibility
        if needsThreeRows {
            // For 3-row mode, temp controls are in containerView
            if isActive {
                singleTempContainer.isHidden = showRange
                rangeTempContainer.isHidden = !showRange
            } else {
                singleTempContainer.isHidden = true
                rangeTempContainer.isHidden = true
            }
        } else {
            // For 2-row mode, temp controls are in controlsRow
            singleTempContainer.isHidden = showRange
            rangeTempContainer.isHidden = !showRange
        }

        updateStateIcon()
    }

    private func updateStateIcon() {
        // Show icon based on selected mode (not HVAC action)
        if currentMode == "off" {
            iconView.image = IconResolver.icon(for: serviceData, filled: false)
            return
        }

        // Use selected mode for icon, except for auto/heat_cool where we show actual action
        let iconMode: String
        switch currentMode {
        case "heat", "heat_cool":
            // For auto modes, show actual action if actively heating/cooling
            if currentMode == "heat_cool" && currentState == 2 {
                iconMode = "cool"
            } else {
                iconMode = "heat"
            }
        case "cool":
            iconMode = "cool"
        case "dry":
            iconMode = "cool"  // Use cool/snow for dry
        case "fan_only":
            iconMode = "fan"
        case "auto":
            // Show actual action for auto mode
            iconMode = currentState == 1 ? "heat" : (currentState == 2 ? "cool" : "auto")
        default:
            iconMode = "auto"
        }

        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: iconMode, filled: true)
            ?? IconResolver.icon(for: serviceData, filled: true)
    }

    private func updateModeButtons() {
        for (index, button) in dynamicModeButtons.enumerated() {
            let mode = modeOrder[index]
            button.isSelected = (mode == currentMode)
        }
    }

    private func togglePower() {
        if currentMode == "off" {
            setMode(lastActiveMode)
        } else {
            setMode("off")
        }
    }

    // MARK: - Mode setting

    private func setMode(_ mode: String) {
        currentMode = mode
        if mode != "off" {
            lastActiveMode = mode
        }
        targetState = modeToPseudoState(mode)
        updateModeButtons()
        updateUI()

        // Write the HA mode - send as string for HA-specific modes, integer for HomeKit-compatible
        if let id = targetStateId {
            // For HA-specific modes, send the string directly
            // For standard modes, map to HomeKit integer
            switch mode {
            case "off":
                bridge?.writeCharacteristic(identifier: id, value: 0)
                notifyLocalChange(characteristicId: id, value: 0)
            case "heat":
                bridge?.writeCharacteristic(identifier: id, value: 1)
                notifyLocalChange(characteristicId: id, value: 1)
            case "cool":
                bridge?.writeCharacteristic(identifier: id, value: 2)
                notifyLocalChange(characteristicId: id, value: 2)
            case "heat_cool":
                bridge?.writeCharacteristic(identifier: id, value: 3)
                notifyLocalChange(characteristicId: id, value: 3)
            default:
                // For auto, dry, fan_only, etc - send as string
                bridge?.writeCharacteristic(identifier: id, value: mode)
                notifyLocalChange(characteristicId: id, value: mode)
            }
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
            setMode("off")
        }
    }

    @objc private func modeButtonPressed(_ sender: ModeButton) {
        let mode = modeOrder[sender.tag]
        setMode(mode)
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

    // MARK: - Swing mode

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
}
