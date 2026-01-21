//
//  FanMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling fans with speed slider
//

import AppKit

class FanMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var activeId: UUID?
    private var rotationSpeedId: UUID?
    private var isActive: Bool = false
    private var speed: Double = 1

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let speedSlider: ModernSlider
    private let toggleSwitch: ToggleSwitch

    private let hasSpeed: Bool
    private let speedMin: Double
    private let speedMax: Double

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = rotationSpeedId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId.flatMap { UUID(uuidString: $0) }
        self.rotationSpeedId = serviceData.rotationSpeedId.flatMap { UUID(uuidString: $0) }

        self.hasSpeed = rotationSpeedId != nil
        self.speedMin = serviceData.rotationSpeedMin ?? 0
        self.speedMax = serviceData.rotationSpeedMax ?? 100

        // Single row height
        let height: CGFloat = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "fan", accessibilityDescription: nil)
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

        // Speed slider (fixed width, positioned before toggle)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = switchX - sliderWidth - DS.Spacing.sm
        let sliderY = (height - 12) / 2

        // Speed slider with actual min/max from characteristic
        speedSlider = ModernSlider(minValue: speedMin, maxValue: speedMax)
        speedSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        speedSlider.doubleValue = speedMax
        speedSlider.isContinuous = false
        speedSlider.isHidden = true
        speedSlider.progressTintColor = DS.Colors.sliderFan
        if hasSpeed {
            containerView.addSubview(speedSlider)
        }

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up actions
        speedSlider.target = self
        speedSlider.action = #selector(sliderChanged(_:))

        toggleSwitch.target = self
        toggleSwitch.action = #selector(togglePower(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == activeId {
            if let intValue = value as? Int {
                isActive = intValue == 1
                updateUI()
            } else if let boolValue = value as? Bool {
                isActive = boolValue
                updateUI()
            }
        } else if characteristicId == rotationSpeedId {
            if let doubleValue = value as? Double {
                speed = doubleValue
                speedSlider.doubleValue = doubleValue
            } else if let intValue = value as? Int {
                speed = Double(intValue)
                speedSlider.doubleValue = speed
            } else if let floatValue = value as? Float {
                speed = Double(floatValue)
                speedSlider.doubleValue = speed
            }
        }
    }

    private func updateUI() {
        iconView.image = NSImage(systemSymbolName: isActive ? "fan.fill" : "fan", accessibilityDescription: nil)
        iconView.contentTintColor = isActive ? DS.Colors.fanOn : DS.Colors.mutedForeground
        toggleSwitch.setOn(isActive, animated: false)

        let showSlider = isActive && hasSpeed
        speedSlider.isHidden = !showSlider

        // Adjust name label width based on slider visibility
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let sliderWidth = DS.ControlSize.sliderWidth
        if showSlider {
            nameLabel.frame.size.width = switchX - sliderWidth - DS.Spacing.sm * 2 - labelX
        } else {
            nameLabel.frame.size.width = switchX - labelX - DS.Spacing.sm
        }
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        // Round to nearest integer step
        let roundedValue = round(sender.doubleValue)
        sender.doubleValue = roundedValue
        speed = roundedValue

        let value = Float(roundedValue)
        if let id = rotationSpeedId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            notifyLocalChange(characteristicId: id, value: value)
        }

        // Also turn on if setting speed > 0 and fan is off
        if value > 0 && !isActive, let powerId = activeId {
            bridge?.writeCharacteristic(identifier: powerId, value: 1)
            notifyLocalChange(characteristicId: powerId, value: 1)
            isActive = true
            updateUI()
        }
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isActive = sender.isOn
        if let id = activeId {
            bridge?.writeCharacteristic(identifier: id, value: isActive ? 1 : 0)
            notifyLocalChange(characteristicId: id, value: isActive ? 1 : 0)
        }
        updateUI()
    }

    private func notifyLocalChange(characteristicId: UUID, value: Any) {
        NotificationCenter.default.post(
            name: .characteristicDidChangeLocally,
            object: self,
            userInfo: ["characteristicId": characteristicId, "value": value]
        )
    }
}
