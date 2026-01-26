//
//  AirPurifierMenuItem.swift
//  macOSBridge
//
//  Menu item for Air Purifier controls
//

import AppKit

class AirPurifierMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var activeId: UUID?
    private var currentStateId: UUID?
    private var targetStateId: UUID?
    private var rotationSpeedId: UUID?

    private var isActive: Bool = false
    private var currentState: Int = 0  // 0=inactive, 1=idle, 2=purifying
    private var targetState: Int = 0   // 0=manual, 1=auto
    private var speed: Double = 100

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when active)
    private let controlsRow: NSView
    private let modeButtonManual: ModeButton
    private let modeButtonAuto: ModeButton
    private let speedSlider: ModernSlider

    private let hasSpeed: Bool
    private let speedMin: Double
    private let speedMax: Double

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let expandedHeight: CGFloat = DS.ControlSize.menuItemHeight + 36

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        if let id = rotationSpeedId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId.flatMap { UUID(uuidString: $0) }
        self.currentStateId = serviceData.currentAirPurifierStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateId = serviceData.targetAirPurifierStateId.flatMap { UUID(uuidString: $0) }
        self.rotationSpeedId = serviceData.rotationSpeedId.flatMap { UUID(uuidString: $0) }

        self.hasSpeed = rotationSpeedId != nil
        self.speedMin = serviceData.rotationSpeedMin ?? 0
        self.speedMax = serviceData.rotationSpeedMax ?? 100

        // Create wrapper view - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, power toggle
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Power toggle position
        let switchX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.switchWidth

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (collapsedHeight - 17) / 2
        let labelWidth = switchX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Power toggle
        let switchY = (collapsedHeight - DS.ControlSize.switchHeight) / 2
        powerToggle = ToggleSwitch()
        powerToggle.frame = NSRect(x: switchX,
                                   y: switchY,
                                   width: DS.ControlSize.switchWidth,
                                   height: DS.ControlSize.switchHeight)
        containerView.addSubview(powerToggle)

        // Controls row (initially hidden)
        controlsRow = NSView(frame: NSRect(x: 0, y: DS.Spacing.sm, width: DS.ControlSize.menuItemWidth, height: 26))
        controlsRow.isHidden = true

        // Mode buttons container
        let buttonWidth: CGFloat = 48
        let buttonHeight: CGFloat = 18
        let containerPadding: CGFloat = 2
        let modeContainerWidth = buttonWidth * 2 + containerPadding * 2
        let modeContainerHeight = buttonHeight + containerPadding * 2

        let modeContainer = NSView(frame: NSRect(x: labelX, y: 3, width: modeContainerWidth, height: modeContainerHeight))
        modeContainer.wantsLayer = true
        modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        modeContainer.layer?.cornerRadius = modeContainerHeight / 2

        modeButtonManual = ModeButton(title: "Manual", color: DS.Colors.fanOn)  // Cyan - manual control
        modeButtonManual.frame = NSRect(x: containerPadding, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonManual.tag = 0
        modeContainer.addSubview(modeButtonManual)

        modeButtonAuto = ModeButton(title: "Auto", color: DS.Colors.success)  // Green - automatic
        modeButtonAuto.frame = NSRect(x: containerPadding + buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonAuto.tag = 1
        modeContainer.addSubview(modeButtonAuto)

        controlsRow.addSubview(modeContainer)

        // Speed slider (optional, positioned after mode buttons)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = DS.ControlSize.menuItemWidth - DS.Spacing.md - sliderWidth
        let sliderY: CGFloat = 6

        speedSlider = ModernSlider(minValue: speedMin, maxValue: speedMax)
        speedSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        speedSlider.doubleValue = speedMax
        speedSlider.isContinuous = false
        speedSlider.isHidden = true
        speedSlider.progressTintColor = DS.Colors.sliderFan
        if hasSpeed {
            controlsRow.addSubview(speedSlider)
        }

        // Set initial selection
        modeButtonManual.isSelected = true

        containerView.addSubview(controlsRow)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isActive.toggle()
            self.powerToggle.setOn(self.isActive, animated: true)
            if let id = self.activeId {
                self.bridge?.writeCharacteristic(identifier: id, value: self.isActive ? 1 : 0)
                self.notifyLocalChange(characteristicId: id, value: self.isActive ? 1 : 0)
            }
            self.updateUI()
        }

        // Set up actions
        powerToggle.target = self
        powerToggle.action = #selector(togglePower(_:))

        modeButtonManual.target = self
        modeButtonManual.action = #selector(modeChanged(_:))
        modeButtonAuto.target = self
        modeButtonAuto.action = #selector(modeChanged(_:))

        speedSlider.target = self
        speedSlider.action = #selector(sliderChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == activeId {
            if let active = ValueConversion.toBool(value) {
                isActive = active
                updateUI()
            }
        } else if characteristicId == currentStateId {
            if let state = ValueConversion.toInt(value) {
                currentState = state
                updateStateIcon()
            }
        } else if characteristicId == targetStateId {
            if let state = ValueConversion.toInt(value) {
                targetState = state
                updateModeButtons()
            }
        } else if characteristicId == rotationSpeedId {
            if let newSpeed = ValueConversion.toDouble(value) {
                speed = newSpeed
                speedSlider.doubleValue = newSpeed
            }
        }
    }

    private func updateUI() {
        powerToggle.setOn(isActive, animated: false)
        controlsRow.isHidden = !isActive

        // Resize container
        let newHeight = isActive ? expandedHeight : collapsedHeight
        containerView.frame.size.height = newHeight

        // Reposition row 1 elements
        let topAreaY = newHeight - collapsedHeight
        let iconY = topAreaY + (collapsedHeight - DS.ControlSize.iconMedium) / 2
        let labelY = topAreaY + (collapsedHeight - 17) / 2
        let switchY = topAreaY + (collapsedHeight - DS.ControlSize.switchHeight) / 2
        iconView.frame.origin.y = iconY
        nameLabel.frame.origin.y = labelY
        powerToggle.frame.origin.y = switchY

        // Show speed slider when active and has speed
        speedSlider.isHidden = !isActive || !hasSpeed

        updateStateIcon()
    }

    private func updateStateIcon() {
        let filled = isActive
        let color: NSColor = isActive ? DS.Colors.success : DS.Colors.mutedForeground
        iconView.image = IconResolver.icon(for: serviceData, filled: filled)
    }

    private func updateModeButtons() {
        modeButtonManual.isSelected = (targetState == 0)
        modeButtonAuto.isSelected = (targetState == 1)
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isActive = sender.isOn
        if let id = activeId {
            bridge?.writeCharacteristic(identifier: id, value: isActive ? 1 : 0)
            notifyLocalChange(characteristicId: id, value: isActive ? 1 : 0)
        }
        updateUI()
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        targetState = sender.tag
        updateModeButtons()
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
            notifyLocalChange(characteristicId: id, value: targetState)
        }
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
    }
}
