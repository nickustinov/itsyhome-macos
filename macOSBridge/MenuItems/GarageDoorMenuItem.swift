//
//  GarageDoorMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling garage doors with toggle switch
//

import AppKit

class GarageDoorMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentDoorStateId: UUID?
    private var targetDoorStateId: UUID?
    private var obstructionDetectedId: UUID?

    // Door states: 0=open, 1=closed, 2=opening, 3=closing, 4=stopped
    private var currentState: Int = 1  // Default closed
    private var isObstructed: Bool = false

    private let containerView: NSView
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
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "door.garage.closed", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
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
        statusLabel.frame = NSRect(x: statusX, y: labelY, width: statusWidth, height: 17)
        statusLabel.font = DS.Typography.labelSmall
        statusLabel.textColor = DS.Colors.mutedForeground
        statusLabel.alignment = .right
        containerView.addSubview(statusLabel)

        // Toggle switch (on = closed, off = open)
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        toggleSwitch.isOn = true  // Closed = on
        containerView.addSubview(toggleSwitch)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleDoor(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == currentDoorStateId, let intValue = value as? Int {
            currentState = intValue
            updateUI()
        } else if characteristicId == obstructionDetectedId {
            if let boolValue = value as? Bool {
                isObstructed = boolValue
                updateUI()
            } else if let intValue = value as? Int {
                isObstructed = intValue != 0
                updateUI()
            }
        }
    }

    private func updateUI() {
        let (symbolName, stateText, isOpen): (String, String, Bool) = {
            if isObstructed {
                return ("exclamationmark.triangle", "Obstructed", false)
            }
            switch currentState {
            case 0:  // Open
                return ("door.garage.open", "Open", true)
            case 1:  // Closed
                return ("door.garage.closed", "Closed", false)
            case 2:  // Opening
                return ("door.garage.open", "Opening...", true)
            case 3:  // Closing
                return ("door.garage.closed", "Closing...", false)
            case 4:  // Stopped
                return ("door.garage.open", "Stopped", true)
            default:
                return ("door.garage.closed", "Unknown", false)
            }
        }()

        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
        statusLabel.stringValue = stateText
        statusLabel.textColor = DS.Colors.mutedForeground
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

    private func notifyLocalChange(characteristicId: UUID, value: Any) {
        NotificationCenter.default.post(
            name: .characteristicDidChangeLocally,
            object: self,
            userInfo: ["characteristicId": characteristicId, "value": value]
        )
    }
}
