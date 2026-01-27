//
//  FanMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling fans with speed slider and optional controls
//

import AppKit

class FanMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    // Characteristic IDs
    private var activeId: UUID?
    private var powerStateId: UUID?
    private var rotationSpeedId: UUID?
    private var targetFanStateId: UUID?
    private var currentFanStateId: UUID?
    private var rotationDirectionId: UUID?
    private var swingModeId: UUID?

    // State
    private var isActive: Bool = false
    private var speed: Double = 1
    private var targetFanState: Int = 0      // 0=MANUAL, 1=AUTO
    private var rotationDirection: Int = 0   // 0=CLOCKWISE, 1=COUNTER_CLOCKWISE
    private var swingMode: Int = 0           // 0=DISABLED, 1=ENABLED

    // UI elements
    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let speedSlider: ModernSlider
    private let toggleSwitch: ToggleSwitch

    // Control buttons (shown when active)
    private var modeButtonGroup: ModeButtonGroup?
    private var autoButton: ModeButton?
    private var directionButton: ModeButton?
    private var swingButton: ModeButton?

    // Layout
    private let hasSpeed: Bool
    private let speedMin: Double
    private let speedMax: Double
    private let hasAdvancedControls: Bool

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = powerStateId { ids.append(id) }
        if let id = rotationSpeedId { ids.append(id) }
        if let id = targetFanStateId { ids.append(id) }
        if let id = currentFanStateId { ids.append(id) }
        if let id = rotationDirectionId { ids.append(id) }
        if let id = swingModeId { ids.append(id) }
        return ids
    }

    private var powerId: UUID? { activeId ?? powerStateId }
    private var usesActiveCharacteristic: Bool { activeId != nil }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId.flatMap { UUID(uuidString: $0) }
        self.powerStateId = serviceData.powerStateId.flatMap { UUID(uuidString: $0) }
        self.rotationSpeedId = serviceData.rotationSpeedId.flatMap { UUID(uuidString: $0) }
        self.targetFanStateId = serviceData.targetFanStateId.flatMap { UUID(uuidString: $0) }
        self.currentFanStateId = serviceData.currentFanStateId.flatMap { UUID(uuidString: $0) }
        self.rotationDirectionId = serviceData.rotationDirectionId.flatMap { UUID(uuidString: $0) }
        self.swingModeId = serviceData.swingModeId.flatMap { UUID(uuidString: $0) }

        self.hasSpeed = rotationSpeedId != nil
        self.speedMin = serviceData.rotationSpeedMin ?? 0
        self.speedMax = serviceData.rotationSpeedMax ?? 100
        self.hasAdvancedControls = targetFanStateId != nil || rotationDirectionId != nil || swingModeId != nil

        // Single row height
        let height = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Toggle switch (rightmost)
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        // Speed slider (fixed width, positioned before toggle)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = switchX - sliderWidth - DS.Spacing.sm
        let sliderY = (height - 12) / 2

        speedSlider = ModernSlider(minValue: speedMin, maxValue: speedMax)
        speedSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        speedSlider.doubleValue = speedMax
        speedSlider.isContinuous = false
        speedSlider.isHidden = true
        speedSlider.progressTintColor = DS.Colors.sliderFan
        if hasSpeed {
            containerView.addSubview(speedSlider)
        }

        // Build buttons container (positioned before slider, shown when active)
        var buttonCount = 0
        if targetFanStateId != nil { buttonCount += 1 }
        if rotationDirectionId != nil { buttonCount += 1 }
        if swingModeId != nil { buttonCount += 1 }

        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm

        if hasAdvancedControls {
            let containerWidth = ModeButtonGroup.widthForIconButtons(count: buttonCount)
            let buttonsX = sliderX - containerWidth - DS.Spacing.sm
            let buttonsY = (height - 18) / 2
            let modeContainer = ModeButtonGroup(frame: NSRect(x: buttonsX, y: buttonsY, width: containerWidth, height: 18))
            modeButtonGroup = modeContainer

            if targetFanStateId != nil {
                autoButton = modeContainer.addButton(icon: "a.square", color: DS.Colors.success)
            }
            if rotationDirectionId != nil {
                directionButton = modeContainer.addButton(icon: "arrow.clockwise", color: DS.Colors.sliderFan)
            }
            if swingModeId != nil {
                swingButton = modeContainer.addButton(icon: "angle", color: DS.Colors.sliderFan)
            }

            modeContainer.isHidden = true
            containerView.addSubview(modeContainer)
        }

        // Name label (width adjusts based on what's visible)
        let labelY = (height - 17) / 2
        let fullLabelWidth = switchX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: fullLabelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isActive.toggle()
            self.toggleSwitch.setOn(self.isActive, animated: true)
            self.writePower()
            self.updateUI()
        }

        // Set up actions
        speedSlider.target = self
        speedSlider.action = #selector(sliderChanged(_:))

        toggleSwitch.target = self
        toggleSwitch.action = #selector(togglePower(_:))

        autoButton?.target = self
        autoButton?.action = #selector(autoTapped(_:))

        directionButton?.target = self
        directionButton?.action = #selector(directionTapped(_:))

        swingButton?.target = self
        swingButton?.action = #selector(swingTapped(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == activeId || characteristicId == powerStateId {
            if let active = ValueConversion.toBool(value) {
                isActive = active
                updateUI()
            }
        } else if characteristicId == rotationSpeedId {
            if let newSpeed = ValueConversion.toDouble(value) {
                speed = newSpeed
                speedSlider.doubleValue = newSpeed
            }
        } else if characteristicId == targetFanStateId {
            if let state = ValueConversion.toInt(value) {
                targetFanState = state
                updateAutoButton()
            }
        } else if characteristicId == rotationDirectionId {
            if let dir = ValueConversion.toInt(value) {
                rotationDirection = dir
                updateDirectionButton()
            }
        } else if characteristicId == swingModeId {
            if let mode = ValueConversion.toInt(value) {
                swingMode = mode
                updateSwingButton()
            }
        }
    }

    private func updateUI() {
        iconView.image = IconResolver.icon(for: serviceData, filled: isActive)
        toggleSwitch.setOn(isActive, animated: false)

        let showSlider = isActive && hasSpeed
        speedSlider.isHidden = !showSlider

        let showControls = isActive && hasAdvancedControls
        modeButtonGroup?.isHidden = !showControls

        // Adjust name label width based on what's visible
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let sliderX = switchX - DS.ControlSize.sliderWidth - DS.Spacing.sm

        if showSlider && showControls {
            // Buttons + slider visible: label ends before buttons
            let buttonsX = sliderX - (modeButtonGroup?.frame.width ?? 0) - DS.Spacing.sm
            nameLabel.frame.size.width = buttonsX - labelX - DS.Spacing.sm
        } else if showSlider {
            // Only slider visible
            nameLabel.frame.size.width = sliderX - labelX - DS.Spacing.sm
        } else {
            // Nothing extra visible
            nameLabel.frame.size.width = switchX - labelX - DS.Spacing.sm
        }

        updateAutoButton()
        updateDirectionButton()
        updateSwingButton()
    }

    private func updateAutoButton() {
        guard let btn = autoButton else { return }
        btn.isSelected = targetFanState == 1
    }

    private func updateDirectionButton() {
        guard let btn = directionButton else { return }
        // 0 = clockwise, 1 = counter-clockwise
        let iconName = rotationDirection == 0 ? "arrow.clockwise" : "arrow.counterclockwise"
        btn.setIcon(iconName)
        btn.isSelected = rotationDirection == 1
    }

    private func updateSwingButton() {
        guard let btn = swingButton else { return }
        btn.isSelected = swingMode == 1
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        let roundedValue = round(sender.doubleValue)
        sender.doubleValue = roundedValue
        speed = roundedValue

        let value = Float(roundedValue)
        if let id = rotationSpeedId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            notifyLocalChange(characteristicId: id, value: value)
        }

        // Also turn on if setting speed > 0 and fan is off
        if value > 0 && !isActive {
            isActive = true
            writePower()
            updateUI()
        }
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isActive = sender.isOn
        writePower()
        updateUI()
    }

    @objc private func autoTapped(_ sender: NSButton) {
        targetFanState = targetFanState == 0 ? 1 : 0
        if let id = targetFanStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetFanState)
            notifyLocalChange(characteristicId: id, value: targetFanState)
        }
        updateAutoButton()
    }

    @objc private func directionTapped(_ sender: NSButton) {
        rotationDirection = rotationDirection == 0 ? 1 : 0
        if let id = rotationDirectionId {
            bridge?.writeCharacteristic(identifier: id, value: rotationDirection)
            notifyLocalChange(characteristicId: id, value: rotationDirection)
        }
        updateDirectionButton()
    }

    @objc private func swingTapped(_ sender: NSButton) {
        swingMode = swingMode == 0 ? 1 : 0
        if let id = swingModeId {
            bridge?.writeCharacteristic(identifier: id, value: swingMode)
            notifyLocalChange(characteristicId: id, value: swingMode)
        }
        updateSwingButton()
    }

    private func writePower() {
        guard let id = powerId else { return }
        let value: Any = usesActiveCharacteristic ? (isActive ? 1 : 0) : isActive
        bridge?.writeCharacteristic(identifier: id, value: value)
        notifyLocalChange(characteristicId: id, value: value)
    }
}
