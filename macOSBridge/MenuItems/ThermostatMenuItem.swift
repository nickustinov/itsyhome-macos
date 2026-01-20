//
//  ThermostatMenuItem.swift
//  macOSBridge
//
//  Menu item for thermostat controls
//

import AppKit

class ThermostatMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentTempCharacteristicId: UUID?
    private var targetTempCharacteristicId: UUID?
    private var modeCharacteristicId: UUID?

    private var currentTemp: Double = 0
    private var targetTemp: Double = 20
    private var mode: Int = 0 // 0=off, 1=heat, 2=cool

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tempLabel: NSTextField
    private let stepper: NSStepper
    private let targetLabel: NSTextField

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentTempCharacteristicId { ids.append(id) }
        if let id = targetTempCharacteristicId { ids.append(id) }
        if let id = modeCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentTempCharacteristicId = serviceData.currentTemperatureId.flatMap { UUID(uuidString: $0) }
        self.targetTempCharacteristicId = serviceData.targetTemperatureId.flatMap { UUID(uuidString: $0) }
        self.modeCharacteristicId = serviceData.heatingCoolingStateId.flatMap { UUID(uuidString: $0) }

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 50))

        // Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 15, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: "thermometer", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        containerView.addSubview(iconView)

        // Name label
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: 28, width: 120, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Current temp
        tempLabel = NSTextField(labelWithString: "--°C")
        tempLabel.frame = NSRect(x: 160, y: 28, width: 50, height: 17)
        tempLabel.font = NSFont.systemFont(ofSize: 13)
        tempLabel.alignment = .right
        containerView.addSubview(tempLabel)

        // Target label
        targetLabel = NSTextField(labelWithString: "Target: 20°C")
        targetLabel.frame = NSRect(x: 38, y: 5, width: 100, height: 17)
        targetLabel.font = NSFont.systemFont(ofSize: 11)
        targetLabel.textColor = .secondaryLabelColor
        containerView.addSubview(targetLabel)

        // Stepper for target temp
        stepper = NSStepper(frame: NSRect(x: 200, y: 5, width: 40, height: 20))
        stepper.minValue = 10
        stepper.maxValue = 30
        stepper.increment = 0.5
        stepper.doubleValue = 20
        containerView.addSubview(stepper)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == currentTempCharacteristicId {
            if let temp = value as? Double {
                currentTemp = temp
                tempLabel.stringValue = String(format: "%.1f°C", temp)
            } else if let temp = value as? Int {
                currentTemp = Double(temp)
                tempLabel.stringValue = String(format: "%.1f°C", currentTemp)
            }
        } else if characteristicId == targetTempCharacteristicId {
            if let temp = value as? Double {
                targetTemp = temp
                stepper.doubleValue = temp
                targetLabel.stringValue = String(format: "Target: %.1f°C", temp)
            } else if let temp = value as? Int {
                targetTemp = Double(temp)
                stepper.doubleValue = targetTemp
                targetLabel.stringValue = String(format: "Target: %.1f°C", targetTemp)
            }
        } else if characteristicId == modeCharacteristicId {
            if let m = value as? Int {
                mode = m
                updateModeIcon()
            }
        }
    }

    private func updateModeIcon() {
        let (symbolName, color): (String, NSColor) = switch mode {
        case 1: ("flame", .systemOrange)
        case 2: ("snowflake", .systemBlue)
        default: ("thermometer", .secondaryLabelColor)
        }
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = color
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        let value = sender.doubleValue
        targetTemp = value
        targetLabel.stringValue = String(format: "Target: %.1f°C", value)

        if let id = targetTempCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: Float(value))
        }
    }
}
