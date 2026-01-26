//
//  ThermostatMenuItem.swift
//  macOSBridge
//
//  Menu item for thermostat controls
//

import AppKit

class ThermostatMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentTempCharacteristicId: UUID?
    private var targetTempCharacteristicId: UUID?
    private var modeCharacteristicId: UUID?

    private var currentTemp: Double = 0
    private var targetTemp: Double = 20
    private var mode: Int = 0 // 0=off, 1=heat, 2=cool

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let currentTempLabel: NSTextField
    private let targetSlider: ModernSlider

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

        // Single row height - consistent with other accessories
        let height: CGFloat = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Slider (right-aligned, consistent width)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md
        let sliderY = (height - 12) / 2
        targetSlider = ModernSlider(minValue: 10, maxValue: 30)
        targetSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        targetSlider.doubleValue = 20
        targetSlider.isContinuous = false
        targetSlider.progressTintColor = DS.Colors.sliderThermostat
        containerView.addSubview(targetSlider)

        // Current temp label (before slider)
        let tempWidth: CGFloat = 42
        let tempX = sliderX - tempWidth - DS.Spacing.xs
        let labelY = (height - 17) / 2
        currentTempLabel = NSTextField(labelWithString: "--°")
        currentTempLabel.frame = NSRect(x: tempX, y: labelY, width: tempWidth, height: 17)
        currentTempLabel.font = DS.Typography.labelSmall
        currentTempLabel.textColor = .secondaryLabelColor
        currentTempLabel.alignment = .right
        containerView.addSubview(currentTempLabel)

        // Name label (fills space up to temp label)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelWidth = tempX - labelX - DS.Spacing.xs
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView


        // Set up action
        targetSlider.target = self
        targetSlider.action = #selector(sliderChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentTempCharacteristicId {
            if let temp = ValueConversion.toDouble(value) {
                currentTemp = temp
                currentTempLabel.stringValue = TemperatureFormatter.format(temp)
            }
        } else if characteristicId == targetTempCharacteristicId {
            if let temp = ValueConversion.toDouble(value) {
                targetTemp = temp
                targetSlider.doubleValue = temp
            }
        } else if characteristicId == modeCharacteristicId {
            if let m = ValueConversion.toInt(value) {
                mode = m
                updateModeUI()
            }
        }
    }

    private func updateModeUI() {
        // mode: 0 = off, 1 = heat, 2 = cool
        if mode == 0 {
            iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: false)
        } else {
            let modeStr = mode == 1 ? "heat" : "cool"
            iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: modeStr, filled: true)
                ?? IconMapping.iconForServiceType(serviceData.serviceType, filled: true)
        }
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        // Round to nearest 0.5
        let rawValue = sender.doubleValue
        let roundedValue = (rawValue * 2).rounded() / 2
        targetTemp = roundedValue
        targetSlider.doubleValue = roundedValue

        if let id = targetTempCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: Float(roundedValue))
            notifyLocalChange(characteristicId: id, value: Float(roundedValue))
        }
    }
}
