//
//  HAGarageDoorMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant garage doors with state-aware updating
//  Handles transitional states (opening/closing) and obstructions
//

import AppKit

class HAGarageDoorMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentDoorStateId: UUID?
    private var targetDoorStateId: UUID?
    private var obstructionDetectedId: UUID?

    // HA garage door states: open, closed, opening, closing
    private var currentState: String = "closed"
    private var isObstructed: Bool = false

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField
    private let toggleSwitch: ToggleSwitch

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentDoorStateId { ids.append(id) }
        if let id = targetDoorStateId { ids.append(id) }
        if let id = obstructionDetectedId { ids.append(id) }
        return ids
    }

    private var isOpen: Bool {
        currentState == "open" || currentState == "opening"
    }

    private var isTransitioning: Bool {
        currentState == "opening" || currentState == "closing"
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs
        self.currentDoorStateId = serviceData.currentDoorStateId?.uuid
        self.targetDoorStateId = serviceData.targetDoorStateId?.uuid
        self.obstructionDetectedId = serviceData.obstructionDetectedId?.uuid

        let height = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: true)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Toggle switch position
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md

        // Status label position
        let statusWidth: CGFloat = 65
        let statusX = switchX - statusWidth - DS.Spacing.sm

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let labelWidth = statusX - labelX - DS.Spacing.xs
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Status label
        statusLabel = NSTextField(labelWithString: String(localized: "device.door.closed", defaultValue: "Closed", bundle: .macOSBridge))
        statusLabel.frame = NSRect(x: statusX, y: labelY - 1, width: statusWidth, height: 17)
        statusLabel.font = DS.Typography.labelSmall
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        containerView.addSubview(statusLabel)

        // Toggle switch (on = closed, off = open)
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        toggleSwitch.setOn(true, animated: false)  // Closed = on
        containerView.addSubview(toggleSwitch)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self, !self.isObstructed, !self.isTransitioning else { return }
            self.setDoorState(closed: self.isOpen)
        }

        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleDoor(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentDoorStateId {
            // HA sends state as string, but EntityMapper converts to HomeKit int
            if let stateString = value as? String {
                currentState = stateString
                updateUI()
            } else if let stateInt = ValueConversion.toInt(value) {
                // HomeKit-style: 0=open, 1=closed, 2=opening, 3=closing, 4=stopped
                switch stateInt {
                case 0: currentState = "open"
                case 1: currentState = "closed"
                case 2: currentState = "opening"
                case 3: currentState = "closing"
                default: currentState = "closed"
                }
                updateUI()
            }
        } else if characteristicId == obstructionDetectedId {
            if let obstructed = ValueConversion.toBool(value) {
                isObstructed = obstructed
                updateUI()
            }
        }
    }

    private func updateUI() {
        // Update icon
        let filled = !isOpen
        if isObstructed {
            iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: "obstructed", filled: false)
                ?? IconResolver.icon(for: serviceData, filled: false)
        } else {
            iconView.image = IconResolver.icon(for: serviceData, filled: filled)
        }

        // Update status label (don't set textColor - let HighlightingMenuItemView handle it)
        switch currentState {
        case "open": statusLabel.stringValue = String(localized: "device.door.open", defaultValue: "Open", bundle: .macOSBridge)
        case "closed": statusLabel.stringValue = String(localized: "device.door.closed", defaultValue: "Closed", bundle: .macOSBridge)
        case "opening": statusLabel.stringValue = String(localized: "device.door.opening", defaultValue: "Opening...", bundle: .macOSBridge)
        case "closing": statusLabel.stringValue = String(localized: "device.door.closing", defaultValue: "Closing...", bundle: .macOSBridge)
        default: statusLabel.stringValue = currentState.capitalized
        }

        // Update toggle (ON = closed, OFF = open)
        toggleSwitch.setOn(!isOpen, animated: false)
        toggleSwitch.isEnabled = !isObstructed
    }

    @objc private func toggleDoor(_ sender: ToggleSwitch) {
        guard !isObstructed, !isTransitioning else {
            // Revert switch to current state
            sender.setOn(!isOpen, animated: true)
            return
        }
        // ON = close, OFF = open
        setDoorState(closed: sender.isOn)
    }

    private func setDoorState(closed: Bool) {
        guard let id = targetDoorStateId else { return }

        // Optimistic update to transitional state
        currentState = closed ? "closing" : "opening"
        updateUI()

        // HA garage doors: 0=open, 1=closed (same as HomeKit target)
        bridge?.writeCharacteristic(identifier: id, value: closed ? 1 : 0)

        // Notify with current state ID so other copies update
        if let currentId = currentDoorStateId {
            // Use HomeKit values: 2=opening, 3=closing
            notifyLocalChange(characteristicId: currentId, value: closed ? 3 : 2)
        }
    }
}
