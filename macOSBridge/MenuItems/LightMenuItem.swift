//
//  LightMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling lights with brightness slider
//

import AppKit

class LightMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var powerCharacteristicId: UUID?
    private var brightnessCharacteristicId: UUID?
    private var isOn: Bool = false
    private var brightness: Double = 100

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let brightnessSlider: ModernSlider
    private let toggleSwitch: ToggleSwitch

    private let hasBrightness: Bool

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = powerCharacteristicId { ids.append(id) }
        if let id = brightnessCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.powerCharacteristicId = serviceData.powerStateId.flatMap { UUID(uuidString: $0) }
        self.brightnessCharacteristicId = serviceData.brightnessId.flatMap { UUID(uuidString: $0) }

        self.hasBrightness = brightnessCharacteristicId != nil

        // Single row height
        let height: CGFloat = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Toggle switch (rightmost)
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        // Name label (full width when off, truncated when on with slider)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let fullLabelWidth = switchX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: fullLabelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Brightness slider (fixed width, positioned before toggle)
        let sliderWidth: CGFloat = 80
        let sliderX = switchX - sliderWidth - DS.Spacing.sm
        let sliderY = (height - 12) / 2

        // Brightness slider
        brightnessSlider = ModernSlider(minValue: 0, maxValue: 100)
        brightnessSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        brightnessSlider.doubleValue = 100
        brightnessSlider.isContinuous = false
        brightnessSlider.isHidden = true
        brightnessSlider.progressTintColor = DS.Colors.sliderLight
        if hasBrightness {
            containerView.addSubview(brightnessSlider)
        }

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up actions
        brightnessSlider.target = self
        brightnessSlider.action = #selector(sliderChanged(_:))

        toggleSwitch.target = self
        toggleSwitch.action = #selector(togglePower(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == powerCharacteristicId, let boolValue = value as? Bool {
            isOn = boolValue
            updateUI()
        } else if characteristicId == powerCharacteristicId, let intValue = value as? Int {
            isOn = intValue != 0
            updateUI()
        } else if characteristicId == brightnessCharacteristicId, let doubleValue = value as? Double {
            brightness = doubleValue
            brightnessSlider.doubleValue = doubleValue
        } else if characteristicId == brightnessCharacteristicId, let intValue = value as? Int {
            brightness = Double(intValue)
            brightnessSlider.doubleValue = brightness
        }
    }

    private func updateUI() {
        iconView.image = NSImage(systemSymbolName: isOn ? "lightbulb.fill" : "lightbulb", accessibilityDescription: nil)
        iconView.contentTintColor = isOn ? DS.Colors.lightOn : DS.Colors.mutedForeground
        toggleSwitch.setOn(isOn, animated: false)

        let showSlider = isOn && hasBrightness
        brightnessSlider.isHidden = !showSlider

        // Adjust name label width based on slider visibility
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let sliderWidth: CGFloat = 80
        if showSlider {
            nameLabel.frame.size.width = switchX - sliderWidth - DS.Spacing.sm * 2 - labelX
        } else {
            nameLabel.frame.size.width = switchX - labelX - DS.Spacing.sm
        }
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        let value = sender.doubleValue
        if let id = brightnessCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: Int(value))
        }

        // Also turn on if setting brightness > 0 and light is off
        if value > 0 && !isOn, let powerId = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: powerId, value: true)
            isOn = true
            updateUI()
        }
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isOn = sender.isOn
        if let id = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: isOn)
        }
        updateUI()
    }
}
