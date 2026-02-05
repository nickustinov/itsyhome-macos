//
//  HAHumidifierMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant humidifier/dehumidifier controls
//  Simpler than HomeKit version - HA devices are either humidifier or dehumidifier
//

import AppKit

class HAHumidifierMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var powerStateId: UUID?
    private var humidityId: UUID?
    private var targetHumidityId: UUID?
    private var modeId: UUID?  // Only for devices with modes (like hygrostat)

    private var isOn: Bool = false
    private var currentHumidity: Double = 0
    private var targetHumidity: Double = 50
    private var currentMode: String = ""

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let humidityLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when active)
    private let controlsRow: NSView
    private var modeButtons: [ModeButton] = []
    private var minusButton: NSButton?
    private var thresholdLabel: NSTextField?
    private var plusButton: NSButton?

    private let availableModes: [String]
    private let hasModes: Bool

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private var expandedHeight: CGFloat { DS.ControlSize.menuItemHeight + 36 }

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = powerStateId { ids.append(id) }
        if let id = humidityId { ids.append(id) }
        if let id = targetHumidityId { ids.append(id) }
        if let id = modeId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs
        self.powerStateId = serviceData.powerStateId?.uuid
        self.humidityId = serviceData.humidityId?.uuid
        self.targetHumidityId = serviceData.humidifierThresholdId?.uuid
        self.modeId = serviceData.targetHumidifierDehumidifierStateId?.uuid
        self.availableModes = serviceData.humidifierAvailableModes ?? []
        self.hasModes = !availableModes.isEmpty

        // Create container view - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current humidity, power toggle
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Power toggle position
        let switchX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.switchWidth

        // Current humidity position
        let humidityWidth: CGFloat = 50
        let humidityX = switchX - humidityWidth - DS.Spacing.sm

        // Name label (wider if no humidity display)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (collapsedHeight - 17) / 2
        let hasHumidity = serviceData.humidityId != nil
        let labelWidth = (hasHumidity ? humidityX : switchX) - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Current humidity (only show if device reports it)
        humidityLabel = NSTextField(labelWithString: "--%")
        humidityLabel.frame = NSRect(x: humidityX, y: labelY - 2, width: humidityWidth, height: 17)
        humidityLabel.font = DS.Typography.labelSmall
        humidityLabel.textColor = .secondaryLabelColor
        humidityLabel.alignment = .right
        humidityLabel.isHidden = (humidityId == nil)
        containerView.addSubview(humidityLabel)

        // Power toggle
        let switchY = (collapsedHeight - DS.ControlSize.switchHeight) / 2
        powerToggle = ToggleSwitch()
        powerToggle.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(powerToggle)

        // Controls row (initially hidden)
        controlsRow = NSView(frame: NSRect(x: 0, y: DS.Spacing.sm, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Threshold stepper on right side: [−] 50% [+]
        let thresholdX = DS.ControlSize.menuItemWidth - DS.Spacing.md - 90
        let minusBtn = StepperButton.create(title: "−", size: .regular)
        minusBtn.frame.origin = NSPoint(x: thresholdX, y: 4)
        controlsRow.addSubview(minusBtn)
        minusButton = minusBtn

        let threshLabel = NSTextField(labelWithString: "50%")
        threshLabel.frame = NSRect(x: thresholdX + 22, y: 5, width: 44, height: 17)
        threshLabel.font = DS.Typography.labelSmall
        threshLabel.textColor = .secondaryLabelColor
        threshLabel.alignment = .center
        controlsRow.addSubview(threshLabel)
        thresholdLabel = threshLabel

        let plusBtn = StepperButton.create(title: "+", size: .regular)
        plusBtn.frame.origin = NSPoint(x: thresholdX + 68, y: 4)
        controlsRow.addSubview(plusBtn)
        plusButton = plusBtn

        // Mode buttons (only if device has modes)
        if hasModes {
            let buttonHeight: CGFloat = 18
            let containerPadding: CGFloat = 2
            let buttonWidth: CGFloat = 52
            let modeContainerWidth = CGFloat(availableModes.count) * buttonWidth + containerPadding * 2
            let modeContainerHeight = buttonHeight + containerPadding * 2

            let modeContainer = NSView(frame: NSRect(x: labelX, y: 3, width: modeContainerWidth, height: modeContainerHeight))
            modeContainer.wantsLayer = true
            modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
            modeContainer.layer?.cornerRadius = modeContainerHeight / 2

            for (index, mode) in availableModes.enumerated() {
                let button = ModeButton(title: mode.capitalized, color: DS.Colors.info)
                button.frame = NSRect(x: containerPadding + CGFloat(index) * buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
                button.tag = index
                modeContainer.addSubview(button)
                modeButtons.append(button)
            }

            controlsRow.addSubview(modeContainer)
        }

        containerView.addSubview(controlsRow)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isOn.toggle()
            self.powerToggle.setOn(self.isOn, animated: true)
            self.writePower()
            self.updateUI()
        }

        // Set up actions
        powerToggle.target = self
        powerToggle.action = #selector(togglePower(_:))

        for button in modeButtons {
            button.target = self
            button.action = #selector(modeChanged(_:))
        }

        minusButton?.target = self
        minusButton?.action = #selector(decreaseThreshold(_:))
        plusButton?.target = self
        plusButton?.action = #selector(increaseThreshold(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == powerStateId {
            if let on = ValueConversion.toBool(value) {
                isOn = on
                updateUI()
            }
        } else if characteristicId == humidityId {
            if let humidity = ValueConversion.toDouble(value) {
                currentHumidity = humidity
                humidityLabel.stringValue = String(format: "%.0f%%", humidity)
            }
        } else if characteristicId == targetHumidityId {
            if let threshold = ValueConversion.toDouble(value) {
                targetHumidity = threshold
                updateThresholdLabel()
            }
        } else if characteristicId == modeId {
            if let mode = value as? String {
                currentMode = mode
                updateModeButtons()
            }
        }
    }

    private func updateUI() {
        powerToggle.setOn(isOn, animated: false)
        controlsRow.isHidden = !isOn
        iconView.image = IconResolver.icon(for: serviceData, filled: isOn)

        // Resize container
        let newHeight = isOn ? expandedHeight : collapsedHeight
        containerView.frame.size.height = newHeight

        // Reposition row 1 elements
        let topAreaY = newHeight - collapsedHeight
        let iconY = topAreaY + (collapsedHeight - DS.ControlSize.iconMedium) / 2
        let labelY = topAreaY + (collapsedHeight - 17) / 2
        let switchY = topAreaY + (collapsedHeight - DS.ControlSize.switchHeight) / 2
        iconView.frame.origin.y = iconY
        nameLabel.frame.origin.y = labelY
        humidityLabel.frame.origin.y = labelY - 2
        powerToggle.frame.origin.y = switchY

        updateModeButtons()
        updateThresholdLabel()
    }

    private func updateModeButtons() {
        for button in modeButtons {
            let mode = availableModes[button.tag]
            button.isSelected = (mode == currentMode)
        }
    }

    private func updateThresholdLabel() {
        thresholdLabel?.stringValue = String(format: "%.0f%%", targetHumidity)
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isOn = sender.isOn
        writePower()
        updateUI()
    }

    private func writePower() {
        if let id = powerStateId {
            bridge?.writeCharacteristic(identifier: id, value: isOn)
            notifyLocalChange(characteristicId: id, value: isOn)
        }
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        let mode = availableModes[sender.tag]
        currentMode = mode
        updateModeButtons()
        if let id = modeId {
            bridge?.writeCharacteristic(identifier: id, value: mode)
            notifyLocalChange(characteristicId: id, value: mode)
        }
    }

    @objc private func decreaseThreshold(_ sender: NSButton) {
        let clamped = min(max(targetHumidity - 5, 0), 100)
        targetHumidity = clamped
        updateThresholdLabel()
        if let id = targetHumidityId {
            bridge?.writeCharacteristic(identifier: id, value: Int(clamped))
            notifyLocalChange(characteristicId: id, value: Int(clamped))
        }
    }

    @objc private func increaseThreshold(_ sender: NSButton) {
        let clamped = min(max(targetHumidity + 5, 0), 100)
        targetHumidity = clamped
        updateThresholdLabel()
        if let id = targetHumidityId {
            bridge?.writeCharacteristic(identifier: id, value: Int(clamped))
            notifyLocalChange(characteristicId: id, value: Int(clamped))
        }
    }
}
