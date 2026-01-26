//
//  SecuritySystemMenuItem.swift
//  macOSBridge
//
//  Menu item for Security System controls
//

import AppKit

class SecuritySystemMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentStateId: UUID?
    private var targetStateId: UUID?

    // CurrentState: 0=Stay, 1=Away, 2=Night, 3=Disarmed, 4=Triggered
    // TargetState: 0=Stay, 1=Away, 2=Night, 3=Disarmed (no triggered)
    private var currentState: Int = 3  // Default to disarmed
    private var targetState: Int = 3

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let triggeredIcon: NSImageView

    // Mode buttons row
    private let modeButtonOff: ModeButton
    private let modeButtonStay: ModeButton
    private let modeButtonAway: ModeButton
    private let modeButtonNight: ModeButton

    private let rowHeight: CGFloat = DS.ControlSize.menuItemHeight + 36

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentStateId = serviceData.securitySystemCurrentStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateId = serviceData.securitySystemTargetStateId.flatMap { UUID(uuidString: $0) }

        // Create wrapper view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: rowHeight))

        let topRowHeight = DS.ControlSize.menuItemHeight

        // Row 1: Icon, name, triggered indicator
        let iconY = rowHeight - topRowHeight + (topRowHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Triggered icon (shown when alarm is triggered)
        let triggeredX = DS.ControlSize.menuItemWidth - DS.Spacing.md - DS.ControlSize.iconMedium
        triggeredIcon = NSImageView(frame: NSRect(x: triggeredX, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        triggeredIcon.image = PhosphorIcon.fill("shield-warning")
        triggeredIcon.contentTintColor = DS.Colors.destructive
        triggeredIcon.imageScaling = .scaleProportionallyUpOrDown
        triggeredIcon.isHidden = true
        containerView.addSubview(triggeredIcon)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = rowHeight - topRowHeight + (topRowHeight - 17) / 2
        let labelWidth = triggeredX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Mode buttons row
        let buttonWidth: CGFloat = 44
        let buttonHeight: CGFloat = 18
        let containerPadding: CGFloat = 2
        let modeContainerWidth = buttonWidth * 4 + containerPadding * 2
        let modeContainerHeight = buttonHeight + containerPadding * 2

        let modeContainer = NSView(frame: NSRect(x: labelX, y: DS.Spacing.sm + 3, width: modeContainerWidth, height: modeContainerHeight))
        modeContainer.wantsLayer = true
        modeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        modeContainer.layer?.cornerRadius = modeContainerHeight / 2

        modeButtonOff = ModeButton(title: "Off", color: DS.Colors.mutedForeground)  // Gray - disarmed
        modeButtonOff.frame = NSRect(x: containerPadding, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonOff.tag = 3  // Disarmed
        modeContainer.addSubview(modeButtonOff)

        modeButtonStay = ModeButton(title: "Stay", color: DS.Colors.success)  // Green - home & protected
        modeButtonStay.frame = NSRect(x: containerPadding + buttonWidth, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonStay.tag = 0  // Stay Arm
        modeContainer.addSubview(modeButtonStay)

        modeButtonAway = ModeButton(title: "Away", color: DS.Colors.warning)  // Orange - fully armed
        modeButtonAway.frame = NSRect(x: containerPadding + buttonWidth * 2, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonAway.tag = 1  // Away Arm
        modeContainer.addSubview(modeButtonAway)

        modeButtonNight = ModeButton(title: "Night", color: DS.Colors.info)  // Blue - night mode
        modeButtonNight.frame = NSRect(x: containerPadding + buttonWidth * 3, y: containerPadding, width: buttonWidth, height: buttonHeight)
        modeButtonNight.tag = 2  // Night Arm
        modeContainer.addSubview(modeButtonNight)

        containerView.addSubview(modeContainer)

        // Set initial selection (disarmed)
        modeButtonOff.isSelected = true

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView


        // Set up actions
        modeButtonOff.target = self
        modeButtonOff.action = #selector(modeChanged(_:))
        modeButtonStay.target = self
        modeButtonStay.action = #selector(modeChanged(_:))
        modeButtonAway.target = self
        modeButtonAway.action = #selector(modeChanged(_:))
        modeButtonNight.target = self
        modeButtonNight.action = #selector(modeChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentStateId {
            if let state = ValueConversion.toInt(value) {
                currentState = state
                updateUI()
            }
        } else if characteristicId == targetStateId {
            if let state = ValueConversion.toInt(value) {
                targetState = state
                updateModeButtons()
            }
        }
    }

    private func updateUI() {
        updateStateIcon()
        updateModeButtons()
    }

    private func updateStateIcon() {
        let isArmed = currentState != 3 && currentState != 4
        let isTriggered = currentState == 4

        let mode: String
        let filled: Bool
        if isTriggered {
            mode = "triggered"
            filled = true
        } else if isArmed {
            mode = "armed"
            filled = true
        } else {
            mode = "disarmed"
            filled = false
        }

        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: filled)
            ?? IconMapping.iconForServiceType(serviceData.serviceType, filled: filled)

        // Show triggered indicator
        triggeredIcon.isHidden = !isTriggered
    }

    private func updateModeButtons() {
        modeButtonOff.isSelected = (targetState == 3)
        modeButtonStay.isSelected = (targetState == 0)
        modeButtonAway.isSelected = (targetState == 1)
        modeButtonNight.isSelected = (targetState == 2)
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        targetState = sender.tag
        updateModeButtons()
        if let id = targetStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
            notifyLocalChange(characteristicId: id, value: targetState)
        }
        // Update icon based on target state (optimistic update)
        currentState = targetState
        updateStateIcon()
    }
}
