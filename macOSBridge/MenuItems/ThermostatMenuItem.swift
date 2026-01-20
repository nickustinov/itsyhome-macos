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
    private let currentTempLabel: NSTextField
    private let targetSlider: ModernSlider
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

        let height: CGFloat = DS.ControlSize.menuItemHeightLarge + 8

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = height - DS.Spacing.lg - DS.ControlSize.iconMedium
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "thermometer", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Target label position (right-aligned)
        let targetWidth: CGFloat = 50
        let targetX = DS.ControlSize.menuItemWidth - DS.Spacing.md - targetWidth

        // Current temp label position (before target)
        let tempWidth: CGFloat = 50
        let tempX = targetX - tempWidth - DS.Spacing.xs

        // Name label (fills space up to temp label)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = height - DS.Spacing.lg - 17
        let labelWidth = tempX - labelX - DS.Spacing.xs
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Current temp label
        currentTempLabel = NSTextField(labelWithString: "--°C")
        currentTempLabel.frame = NSRect(x: tempX, y: labelY, width: tempWidth, height: 17)
        currentTempLabel.font = DS.Typography.labelSmall
        currentTempLabel.textColor = DS.Colors.mutedForeground
        currentTempLabel.alignment = .right
        containerView.addSubview(currentTempLabel)

        // Target label
        targetLabel = NSTextField(labelWithString: "20.0°C")
        targetLabel.frame = NSRect(x: targetX, y: labelY, width: targetWidth, height: 17)
        targetLabel.font = DS.Typography.labelSmall
        targetLabel.textColor = DS.Colors.primary
        targetLabel.alignment = .right
        containerView.addSubview(targetLabel)

        // Target temperature slider
        let sliderX = labelX
        let sliderWidth = DS.ControlSize.menuItemWidth - sliderX - DS.Spacing.md
        targetSlider = ModernSlider(minValue: 10, maxValue: 30)
        targetSlider.frame = NSRect(x: sliderX, y: DS.Spacing.sm, width: sliderWidth, height: DS.ControlSize.sliderThumbSize)
        targetSlider.doubleValue = 20
        targetSlider.isContinuous = false
        targetSlider.progressTintColor = DS.Colors.sliderThermostat
        containerView.addSubview(targetSlider)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        targetSlider.target = self
        targetSlider.action = #selector(sliderChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == currentTempCharacteristicId {
            if let temp = value as? Double {
                currentTemp = temp
                currentTempLabel.stringValue = String(format: "%.1f°C", temp)
            } else if let temp = value as? Int {
                currentTemp = Double(temp)
                currentTempLabel.stringValue = String(format: "%.1f°C", currentTemp)
            }
        } else if characteristicId == targetTempCharacteristicId {
            if let temp = value as? Double {
                targetTemp = temp
                targetSlider.doubleValue = temp
                targetLabel.stringValue = String(format: "%.1f°C", temp)
            } else if let temp = value as? Int {
                targetTemp = Double(temp)
                targetSlider.doubleValue = targetTemp
                targetLabel.stringValue = String(format: "%.1f°C", targetTemp)
            }
        } else if characteristicId == modeCharacteristicId {
            if let m = value as? Int {
                mode = m
                updateModeUI()
            }
        }
    }

    private func updateModeUI() {
        let (symbolName, color): (String, NSColor) = switch mode {
        case 1: ("flame", DS.Colors.thermostatHeat)
        case 2: ("snowflake", DS.Colors.thermostatCool)
        default: ("thermometer", DS.Colors.mutedForeground)
        }
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = color
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        // Round to nearest 0.5
        let rawValue = sender.doubleValue
        let roundedValue = (rawValue * 2).rounded() / 2
        targetTemp = roundedValue
        targetSlider.doubleValue = roundedValue
        targetLabel.stringValue = String(format: "%.1f°C", roundedValue)

        if let id = targetTempCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: Float(roundedValue))
        }
    }
}
