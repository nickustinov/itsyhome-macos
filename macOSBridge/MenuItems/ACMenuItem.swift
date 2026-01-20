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
    private let modePopup: NSPopUpButton
    private let targetLabel: NSTextField
    private let stepper: NSStepper
    private let powerButton: NSButton

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

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 70))

        // Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 40, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: "air.conditioner.horizontal", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        containerView.addSubview(iconView)

        // Name label
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: 45, width: 120, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Current temp
        tempLabel = NSTextField(labelWithString: "--°C")
        tempLabel.frame = NSRect(x: 160, y: 45, width: 50, height: 17)
        tempLabel.font = NSFont.systemFont(ofSize: 13)
        tempLabel.alignment = .right
        containerView.addSubview(tempLabel)

        // Power button
        powerButton = NSButton(frame: NSRect(x: 220, y: 40, width: 50, height: 26))
        powerButton.bezelStyle = .inline
        powerButton.setButtonType(.toggle)
        powerButton.title = "Off"
        powerButton.font = NSFont.systemFont(ofSize: 11)
        containerView.addSubview(powerButton)

        // Mode popup
        modePopup = NSPopUpButton(frame: NSRect(x: 38, y: 22, width: 80, height: 20))
        modePopup.addItems(withTitles: ["Auto", "Heat", "Cool"])
        modePopup.font = NSFont.systemFont(ofSize: 11)
        containerView.addSubview(modePopup)

        // Target label
        targetLabel = NSTextField(labelWithString: "Target: --°C")
        targetLabel.frame = NSRect(x: 125, y: 25, width: 90, height: 17)
        targetLabel.font = NSFont.systemFont(ofSize: 11)
        targetLabel.textColor = .secondaryLabelColor
        containerView.addSubview(targetLabel)

        // Stepper for target temp
        stepper = NSStepper(frame: NSRect(x: 220, y: 22, width: 40, height: 20))
        stepper.minValue = 16
        stepper.maxValue = 30
        stepper.increment = 0.5
        stepper.doubleValue = 24
        containerView.addSubview(stepper)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up actions
        powerButton.target = self
        powerButton.action = #selector(togglePower(_:))

        modePopup.target = self
        modePopup.action = #selector(modeChanged(_:))

        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))
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
                modePopup.selectItem(at: state)
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
        powerButton.state = isActive ? .on : .off
        powerButton.title = isActive ? "On" : "Off"
        modePopup.isEnabled = isActive
        stepper.isEnabled = isActive
        updateStateIcon()
    }

    private func updateStateIcon() {
        let (symbolName, color): (String, NSColor) = {
            if !isActive {
                return ("air.conditioner.horizontal", .secondaryLabelColor)
            }
            switch currentState {
            case 2: return ("flame", .systemOrange)      // heating
            case 3: return ("snowflake", .systemBlue)   // cooling
            default: return ("air.conditioner.horizontal", .systemGreen) // idle/inactive but on
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
        stepper.doubleValue = targetTemp
        targetLabel.stringValue = String(format: "Target: %.1f°C", targetTemp)
    }

    @objc private func togglePower(_ sender: NSButton) {
        isActive = sender.state == .on
        if let id = activeId {
            bridge?.writeCharacteristic(identifier: id, value: isActive ? 1 : 0)
        }
        updateUI()
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        targetState = sender.indexOfSelectedItem
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
        }
        updateTargetDisplay()
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        let value = sender.doubleValue
        targetLabel.stringValue = String(format: "Target: %.1f°C", value)

        // Update the appropriate threshold based on mode
        switch targetState {
        case 1: // heat mode
            heatingThreshold = value
            if let id = heatingThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(value))
            }
        case 2: // cool mode
            coolingThreshold = value
            if let id = coolingThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(value))
            }
        default: // auto - update cooling threshold
            coolingThreshold = value
            if let id = coolingThresholdId {
                bridge?.writeCharacteristic(identifier: id, value: Float(value))
            }
        }
    }
}
