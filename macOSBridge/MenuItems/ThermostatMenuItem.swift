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
    private var targetState: Int = 0       // 0=off, 1=heat, 2=cool, 3=auto (HomeKit) or index (HA)
    private var coolingThreshold: Double = 24
    private var heatingThreshold: Double = 18

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when not off)
    private let controlsRow: NSView
    private let modeContainer: ModeButtonGroup

    // HomeKit mode buttons (used when availableHVACModes is nil)
    private var modeButtonHeat: ModeButton?
    private var modeButtonCool: ModeButton?
    private var modeButtonAuto: ModeButton?

    // HA dynamic mode buttons (used when availableHVACModes is set)
    private var dynamicModeButtons: [ModeButton] = []
    private var haModeOrder: [String] = []  // Maps button index to HA mode string
    private var currentHAMode: String = "off"  // Current HA mode string

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
    private let isHAMode: Bool  // True if using Home Assistant with dynamic modes
    private let needsThreeRows: Bool  // True if we have 4+ mode buttons

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let expandedHeightTwoRows: CGFloat = DS.ControlSize.menuItemHeight + 36
    private let expandedHeightThreeRows: CGFloat = DS.ControlSize.menuItemHeight + 62  // Extra row for temp

    // Remember last active mode when toggling off/on
    private var lastActiveMode: Int = 1  // Default to heat (HomeKit) or first non-off mode (HA)
    private var lastActiveHAMode: String = "heat"

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

        // Check if we're in HA mode with dynamic HVAC modes
        self.isHAMode = serviceData.availableHVACModes != nil && !serviceData.availableHVACModes!.isEmpty

        // Determine if we need 3 rows (4+ mode buttons)
        let modeCount = isHAMode ? min(Self.filterAndOrderHAModes(serviceData.availableHVACModes!).count, 5) : 3
        self.needsThreeRows = modeCount > 3

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

        // Controls row (initially hidden) - modes row
        // For 3-row mode, this is just for modes; temp controls go in separate row
        let controlsRowY = needsThreeRows ? (DS.Spacing.sm + 26) : DS.Spacing.sm
        controlsRow = NSView(frame: NSRect(x: 0, y: controlsRowY, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Build mode buttons based on whether we're in HA or HomeKit mode
        if isHAMode {
            // HA mode: Build buttons from available HVAC modes
            let modes = serviceData.availableHVACModes!
            haModeOrder = Self.filterAndOrderHAModes(modes)
            let buttonCount = min(haModeOrder.count, 5)  // Max 5 buttons
            let containerWidth = ModeButtonGroup.widthForButtons(count: buttonCount)
            // Right-align for HA mode with many buttons
            let modeX = DS.ControlSize.menuItemWidth - DS.Spacing.md - containerWidth
            modeContainer = ModeButtonGroup(frame: NSRect(x: modeX, y: 3, width: containerWidth, height: 22))

            for (index, mode) in haModeOrder.prefix(5).enumerated() {
                let (title, color) = Self.titleAndColorForHAMode(mode)
                let button = modeContainer.addButton(title: title, color: color, tag: index)
                dynamicModeButtons.append(button)
            }

            // Set default last active mode to first non-off mode
            if let firstActive = haModeOrder.first(where: { $0 != "off" }) {
                lastActiveHAMode = firstActive
            }
        } else {
            // HomeKit mode: Use hardcoded Heat/Cool/Auto buttons (left-aligned)
            let containerWidth = ModeButtonGroup.widthForButtons(count: 3)
            modeContainer = ModeButtonGroup(frame: NSRect(x: labelX, y: 3, width: containerWidth, height: 22))

            modeButtonCool = modeContainer.addButton(title: "Cool", color: DS.Colors.thermostatCool, tag: 2)
            modeButtonHeat = modeContainer.addButton(title: "Heat", color: DS.Colors.thermostatHeat, tag: 1)
            modeButtonAuto = modeContainer.addButton(title: "Auto", color: DS.Colors.success, tag: 3)

            // Set initial selection
            modeButtonHeat?.isSelected = true
        }

        controlsRow.addSubview(modeContainer)

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
        let miniBtn: CGFloat = 11
        let miniLabel: CGFloat = 24
        let miniStepper = miniBtn + miniLabel + miniBtn  // 44
        let rangeWidth = miniStepper * 2 + 6  // 94
        let rangeTempX = DS.ControlSize.menuItemWidth - DS.Spacing.md - rangeWidth
        rangeTempContainer = NSView(frame: NSRect(x: rangeTempX, y: singleTempParentY, width: rangeWidth, height: 26))
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

        if isHAMode {
            for button in dynamicModeButtons {
                button.target = self
                button.action = #selector(haModeChanged(_:))
            }
        } else {
            modeButtonHeat?.target = self
            modeButtonHeat?.action = #selector(modeChanged(_:))
            modeButtonCool?.target = self
            modeButtonCool?.action = #selector(modeChanged(_:))
            modeButtonAuto?.target = self
            modeButtonAuto?.action = #selector(modeChanged(_:))
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
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - HA Mode helpers

    /// Filter and order HA modes for display (exclude "off", order logically)
    private static func filterAndOrderHAModes(_ modes: [String]) -> [String] {
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
    private static func titleAndColorForHAMode(_ mode: String) -> (String, NSColor) {
        switch mode {
        case "heat":
            return ("Heat", DS.Colors.thermostatHeat)
        case "cool":
            return ("Cool", DS.Colors.thermostatCool)
        case "heat_cool":
            return ("Heat", DS.Colors.thermostatHeat)  // Dual setpoint, show as Heat
        case "auto":
            return ("Auto", NSColor.systemPurple)
        case "dry":
            return ("Dry", NSColor.systemTeal)
        case "fan_only":
            return ("Fan", DS.Colors.fanOn)
        default:
            return (mode.capitalized, NSColor.systemGray)
        }
    }

    /// Map HA mode string to HomeKit-style targetState for internal tracking
    private func haModeToPseudoState(_ mode: String) -> Int {
        if let index = haModeOrder.firstIndex(of: mode) {
            return index + 1  // +1 because 0 is off
        }
        return 0
    }

    /// Check if HA mode uses range temperature control
    /// For HA, always show range if device has thresholds (HA UI always shows both)
    private func haModeUsesRange(_ mode: String) -> Bool {
        if isHAMode && hasThresholds {
            return mode != "off"  // Always show range for HA when on (except off)
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
            if isHAMode {
                // For HA, map extended HomeKit values back to HA mode strings
                // 0=off, 1=heat, 2=cool, 3=heat_cool, 4=dry, 5=fan_only, 6=auto
                if let state = ValueConversion.toInt(value) {
                    let haMode: String
                    switch state {
                    case 0: haMode = "off"
                    case 1: haMode = "heat"
                    case 2: haMode = "cool"
                    case 3: haMode = "heat_cool"
                    case 4: haMode = "dry"
                    case 5: haMode = "fan_only"
                    case 6: haMode = "auto"
                    default: haMode = "off"
                    }
                    currentHAMode = haMode
                    if haMode != "off" {
                        lastActiveHAMode = haMode
                    }
                    targetState = haModeToPseudoState(haMode)
                    updateHAModeButtons()
                    updateUI()
                }
            } else {
                if let state = ValueConversion.toInt(value) {
                    targetState = state
                    if state != 0 {
                        lastActiveMode = state
                    }
                    updateModeButtons()
                    updateUI()
                }
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
        let isActive = isHAMode ? (currentHAMode != "off") : (targetState != 0)
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

        // Show range control in Auto/heat_cool mode with thresholds, single control otherwise
        let showRange: Bool
        if isHAMode {
            showRange = haModeUsesRange(currentHAMode) && hasThresholds
        } else {
            showRange = targetState == 3 && hasThresholds
        }

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
        // Show icon based on current state (what it's actually doing)
        let isOff = isHAMode ? (currentHAMode == "off") : (targetState == 0)
        if isOff {
            iconView.image = IconResolver.icon(for: serviceData, filled: false)
            return
        }

        // currentState: 0=off, 1=heating, 2=cooling
        let mode: String
        if isHAMode {
            mode = switch currentState {
            case 1: "heat"
            case 2: "cool"
            default: (currentHAMode == "heat" || currentHAMode == "heat_cool") ? "heat" : (currentHAMode == "cool" ? "cool" : "auto")
            }
        } else {
            mode = switch currentState {
            case 1: "heat"
            case 2: "cool"
            default: targetState == 1 ? "heat" : (targetState == 2 ? "cool" : "auto")
            }
        }
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: true)
            ?? IconResolver.icon(for: serviceData, filled: true)
    }

    private func updateModeButtons() {
        modeButtonHeat?.isSelected = (targetState == 1)
        modeButtonCool?.isSelected = (targetState == 2)
        modeButtonAuto?.isSelected = (targetState == 3)
    }

    private func updateHAModeButtons() {
        for (index, button) in dynamicModeButtons.enumerated() {
            let mode = haModeOrder[index]
            button.isSelected = (mode == currentHAMode)
        }
    }

    private func togglePower() {
        if isHAMode {
            if currentHAMode == "off" {
                setHAMode(lastActiveHAMode)
            } else {
                setHAMode("off")
            }
        } else {
            if targetState == 0 {
                setMode(lastActiveMode)
            } else {
                setMode(0)
            }
        }
    }

    // MARK: - HomeKit mode setting

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

    // MARK: - HA mode setting

    private func setHAMode(_ mode: String) {
        currentHAMode = mode
        if mode != "off" {
            lastActiveHAMode = mode
        }
        targetState = haModeToPseudoState(mode)
        updateHAModeButtons()
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
        if isHAMode {
            if sender.isOn {
                setHAMode(lastActiveHAMode)
            } else {
                setHAMode("off")
            }
        } else {
            if sender.isOn {
                setMode(lastActiveMode)
            } else {
                setMode(0)
            }
        }
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        setMode(sender.tag)
    }

    @objc private func haModeChanged(_ sender: ModeButton) {
        let mode = haModeOrder[sender.tag]
        setHAMode(mode)
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
