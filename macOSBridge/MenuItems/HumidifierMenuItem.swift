//
//  HumidifierMenuItem.swift
//  macOSBridge
//
//  Menu item for Humidifier/Dehumidifier controls
//

import AppKit

class HumidifierMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var activeId: UUID?
    private var currentStateId: UUID?
    private var targetStateId: UUID?
    private var humidityId: UUID?
    private var humidifierThresholdId: UUID?
    private var dehumidifierThresholdId: UUID?

    private var isActive: Bool = false
    private var currentState: Int = 0  // 0=inactive, 1=idle, 2=humidifying, 3=dehumidifying
    private var targetState: Int = 0   // 0=auto, 1=humidifier, 2=dehumidifier
    private var currentHumidity: Double = 0
    private var humidifierThreshold: Double = 50
    private var dehumidifierThreshold: Double = 50

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let humidityLabel: NSTextField
    private let powerToggle: ToggleSwitch

    // Controls row (shown when active)
    private let controlsRow: NSView
    private let modeButtonAuto: ModeButton
    private let modeButtonHumidify: ModeButton
    private let modeButtonDehumidify: ModeButton

    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let expandedHeight: CGFloat = DS.ControlSize.menuItemHeight + 36

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        if let id = humidityId { ids.append(id) }
        if let id = humidifierThresholdId { ids.append(id) }
        if let id = dehumidifierThresholdId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId.flatMap { UUID(uuidString: $0) }
        self.currentStateId = serviceData.currentHumidifierDehumidifierStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateId = serviceData.targetHumidifierDehumidifierStateId.flatMap { UUID(uuidString: $0) }
        self.humidityId = serviceData.humidityId.flatMap { UUID(uuidString: $0) }
        self.humidifierThresholdId = serviceData.humidifierThresholdId.flatMap { UUID(uuidString: $0) }
        self.dehumidifierThresholdId = serviceData.dehumidifierThresholdId.flatMap { UUID(uuidString: $0) }

        // Create wrapper view (full width for menu sizing) - start collapsed
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: collapsedHeight))

        // Row 1: Icon, name, current humidity, power toggle (centered vertically)
        let iconY = (collapsedHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Power toggle position (calculate first for alignment)
        let switchX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.switchWidth

        // Current humidity position (right-aligned before toggle)
        let humidityWidth: CGFloat = 50
        let humidityX = switchX - humidityWidth - DS.Spacing.sm

        // Name label (fills space up to humidity label)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (collapsedHeight - 17) / 2
        let labelWidth = humidityX - labelX - DS.Spacing.xs
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Current humidity
        humidityLabel = NSTextField(labelWithString: "--%")
        humidityLabel.frame = NSRect(x: humidityX, y: labelY, width: humidityWidth, height: 17)
        humidityLabel.font = DS.Typography.labelSmall
        humidityLabel.textColor = DS.Colors.mutedForeground
        humidityLabel.alignment = .right
        containerView.addSubview(humidityLabel)

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

        // Mode buttons container (pill-shaped dark background)
        let buttonWidth: CGFloat = 52
        let buttonHeight: CGFloat = 18
        let containerPadding: CGFloat = 2
        let modeContainerWidth = buttonWidth * 3 + containerPadding * 2
        let modeContainerHeight = buttonHeight + containerPadding * 2

        let modeContainer = NSView(frame: NSRect(x: labelX, y: 3, width: modeContainerWidth, height: modeContainerHeight))
        modeContainer.wantsLayer = true
        modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        modeContainer.layer?.cornerRadius = modeContainerHeight / 2

        modeButtonAuto = ModeButton(title: "Auto", color: DS.Colors.success)  // Green
        modeButtonAuto.frame = NSRect(x: containerPadding, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonAuto.tag = 0
        modeContainer.addSubview(modeButtonAuto)

        modeButtonHumidify = ModeButton(title: "Humid", color: DS.Colors.info)  // Blue - adding moisture
        modeButtonHumidify.frame = NSRect(x: containerPadding + buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonHumidify.tag = 1
        modeContainer.addSubview(modeButtonHumidify)

        modeButtonDehumidify = ModeButton(title: "Dry", color: DS.Colors.warning)  // Orange - removing moisture
        modeButtonDehumidify.frame = NSRect(x: containerPadding + buttonWidth * 2, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonDehumidify.tag = 2
        modeContainer.addSubview(modeButtonDehumidify)

        controlsRow.addSubview(modeContainer)

        // Set initial selection
        modeButtonAuto.isSelected = true

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

        modeButtonAuto.target = self
        modeButtonAuto.action = #selector(modeChanged(_:))
        modeButtonHumidify.target = self
        modeButtonHumidify.action = #selector(modeChanged(_:))
        modeButtonDehumidify.target = self
        modeButtonDehumidify.action = #selector(modeChanged(_:))
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
        } else if characteristicId == humidityId {
            if let humidity = ValueConversion.toDouble(value) {
                currentHumidity = humidity
                humidityLabel.stringValue = String(format: "%.0f%%", humidity)
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
        } else if characteristicId == humidifierThresholdId {
            if let threshold = ValueConversion.toDouble(value) {
                humidifierThreshold = threshold
            }
        } else if characteristicId == dehumidifierThresholdId {
            if let threshold = ValueConversion.toDouble(value) {
                dehumidifierThreshold = threshold
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
        humidityLabel.frame.origin.y = labelY
        powerToggle.frame.origin.y = switchY

        updateStateIcon()
    }

    private func updateStateIcon() {
        if !isActive {
            iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: false)
            return
        }
        // currentState: 2 = humidifying, 3 = dehumidifying
        let mode = currentState == 3 ? "dehumidify" : "humidify"
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: true)
            ?? IconMapping.iconForServiceType(serviceData.serviceType, filled: true)
    }

    private func updateModeButtons() {
        modeButtonAuto.isSelected = (targetState == 0)
        modeButtonHumidify.isSelected = (targetState == 1)
        modeButtonDehumidify.isSelected = (targetState == 2)
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
}
