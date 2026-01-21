//
//  ACMenuItem.swift
//  macOSBridge
//
//  Menu item for AC / HeaterCooler controls
//

import AppKit

class ACMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

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

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when active)
    private let controlsRow: NSView
    private let modeSegment: NSSegmentedControl
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
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current temp, power toggle (centered vertically)
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "air.conditioner.horizontal", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
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
        tempLabel = NSTextField(labelWithString: "--°C")
        tempLabel.frame = NSRect(x: tempX, y: labelY, width: tempWidth, height: 17)
        tempLabel.font = DS.Typography.labelSmall
        tempLabel.textColor = DS.Colors.mutedForeground
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

        // Mode segment
        modeSegment = NSSegmentedControl(labels: ["Auto", "Heat", "Cool"], trackingMode: .selectOne, target: nil, action: nil)
        modeSegment.frame = NSRect(x: labelX, y: 4, width: 110, height: 20)
        modeSegment.font = NSFont.systemFont(ofSize: 10)
        modeSegment.selectedSegment = 0
        modeSegment.segmentStyle = .capsule
        modeSegment.selectedSegmentBezelColor = DS.Colors.success
        // Force active appearance so it doesn't gray out when submenu opens
        if let cell = modeSegment.cell as? NSSegmentedCell {
            cell.controlView?.appearance = NSAppearance(named: .vibrantLight)
        }
        controlsRow.addSubview(modeSegment)

        // Temperature controls: - | temp | +
        let tempControlsX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 90

        // Minus button
        minusButton = NSButton(frame: NSRect(x: tempControlsX, y: 4, width: 22, height: 20))
        minusButton.bezelStyle = .inline
        minusButton.title = "−"
        minusButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        controlsRow.addSubview(minusButton)

        // Target temp label
        targetLabel = NSTextField(labelWithString: "24°C")
        targetLabel.frame = NSRect(x: tempControlsX + 24, y: 5, width: 42, height: 17)
        targetLabel.font = DS.Typography.labelSmall
        targetLabel.textColor = DS.Colors.foreground
        targetLabel.alignment = .center
        controlsRow.addSubview(targetLabel)

        // Plus button
        plusButton = NSButton(frame: NSRect(x: tempControlsX + 68, y: 4, width: 22, height: 20))
        plusButton.bezelStyle = .inline
        plusButton.title = "+"
        plusButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        controlsRow.addSubview(plusButton)

        containerView.addSubview(controlsRow)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up actions
        powerToggle.target = self
        powerToggle.action = #selector(togglePower(_:))

        modeSegment.target = self
        modeSegment.action = #selector(modeChanged(_:))

        minusButton.target = self
        minusButton.action = #selector(decreaseTemp(_:))

        plusButton.target = self
        plusButton.action = #selector(increaseTemp(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == activeId {
            if let active = value as? Int {
                isActive = active == 1
                updateUI()
            } else if let active = value as? Bool {
                isActive = active
                updateUI()
            }
        } else if characteristicId == currentTempId {
            if let temp = value as? Double {
                currentTemp = temp
                tempLabel.stringValue = String(format: "%.1f°C", temp)
            } else if let temp = value as? Int {
                currentTemp = Double(temp)
                tempLabel.stringValue = String(format: "%.1f°C", currentTemp)
            }
        } else if characteristicId == currentStateId {
            if let state = value as? Int {
                currentState = state
                updateStateIcon()
            }
        } else if characteristicId == targetStateId {
            if let state = value as? Int {
                targetState = state
                modeSegment.selectedSegment = state
                updateTargetDisplay()
            }
        } else if characteristicId == coolingThresholdId {
            if let temp = value as? Double {
                coolingThreshold = temp
                updateTargetDisplay()
            } else if let temp = value as? Int {
                coolingThreshold = Double(temp)
                updateTargetDisplay()
            }
        } else if characteristicId == heatingThresholdId {
            if let temp = value as? Double {
                heatingThreshold = temp
                updateTargetDisplay()
            } else if let temp = value as? Int {
                heatingThreshold = Double(temp)
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
        let (symbolName, color): (String, NSColor) = {
            if !isActive {
                return ("air.conditioner.horizontal", DS.Colors.mutedForeground)
            }
            switch currentState {
            case 2: return ("flame", DS.Colors.thermostatHeat)      // heating
            case 3: return ("snowflake", DS.Colors.thermostatCool)  // cooling
            default: return ("air.conditioner.horizontal", DS.Colors.success) // idle/inactive but on
            }
        }()
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = color
    }

    private func updateTargetDisplay() {
        let targetTemp: Double
        switch targetState {
        case 1: targetTemp = heatingThreshold  // heat mode
        case 2: targetTemp = coolingThreshold  // cool mode
        default: targetTemp = coolingThreshold // auto - show cooling threshold
        }
        targetLabel.stringValue = String(format: "%.0f°C", targetTemp)
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
            }
        default: // cool or auto
            coolingThreshold = clamped
            if let id = coolingThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(clamped))
            }
        }
        updateTargetDisplay()
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isActive = sender.isOn
        if let id = activeId {
            bridge?.writeCharacteristic(identifier: id, value: isActive ? 1 : 0)
        }
        updateUI()
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        targetState = sender.selectedSegment
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
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
