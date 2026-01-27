//
//  GarageDoorMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling garage doors with toggle switch
//

import AppKit

class GarageDoorMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentDoorStateId: UUID?
    private var targetDoorStateId: UUID?
    private var obstructionDetectedId: UUID?

    // Door states: 0=open, 1=closed, 2=opening, 3=closing, 4=stopped
    private var currentState: Int = 1  // Default closed
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

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentDoorStateId = serviceData.currentDoorStateId.flatMap { UUID(uuidString: $0) }
        self.targetDoorStateId = serviceData.targetDoorStateId.flatMap { UUID(uuidString: $0) }
        self.obstructionDetectedId = serviceData.obstructionDetectedId.flatMap { UUID(uuidString: $0) }

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

        // Toggle switch position (calculate first for alignment)
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md

        // Status label position (right-aligned before toggle)
        let statusWidth: CGFloat = 55
        let statusX = switchX - statusWidth - DS.Spacing.sm

        // Name label (fills space up to status label)
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
        statusLabel = NSTextField(labelWithString: "Closed")
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
            guard let self else { return }
            // Toggle: if open (0) or opening (2), close; otherwise open
            let isOpen = self.currentState == 0 || self.currentState == 2 || self.currentState == 4
            let targetState = isOpen ? 1 : 0
            if let id = self.targetDoorStateId {
                self.bridge?.writeCharacteristic(identifier: id, value: targetState)
                if let currentId = self.currentDoorStateId {
                    self.notifyLocalChange(characteristicId: currentId, value: targetState == 1 ? 1 : 0)
                }
            }
        }

        // Set up action
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleDoor(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentDoorStateId {
            if let state = ValueConversion.toInt(value) {
                currentState = state
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
        let (filled, stateText, isOpen): (Bool, String, Bool) = {
            if isObstructed {
                return (false, "Obstructed", false)
            }
            switch currentState {
            case 0:  // Open
                return (false, "Open", true)
            case 1:  // Closed
                return (true, "Closed", false)
            case 2:  // Opening
                return (false, "Opening...", true)
            case 3:  // Closing
                return (true, "Closing...", false)
            case 4:  // Stopped
                return (false, "Stopped", true)
            default:
                return (true, "Unknown", false)
            }
        }()

        if isObstructed {
            iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: "obstructed", filled: false)
                ?? IconResolver.icon(for: serviceData, filled: false)
        } else {
            iconView.image = IconResolver.icon(for: serviceData, filled: filled)
        }
        iconView.contentTintColor = DS.Colors.iconForeground
        statusLabel.stringValue = stateText
        statusLabel.textColor = .secondaryLabelColor
        toggleSwitch.setOn(!isOpen, animated: false)  // ON = closed, OFF = open
        toggleSwitch.isEnabled = !isObstructed
    }

    @objc private func toggleDoor(_ sender: ToggleSwitch) {
        // Closed = ON (target 1), Open = OFF (target 0)
        let targetState = sender.isOn ? 1 : 0

        if let id = targetDoorStateId {
            bridge?.writeCharacteristic(identifier: id, value: targetState)
            // Notify with current state ID so other copies update
            if let currentId = currentDoorStateId {
                // Map target to approximate current state (1=closed, 0=open)
                notifyLocalChange(characteristicId: currentId, value: targetState == 1 ? 1 : 0)
            }
        }
    }
}
