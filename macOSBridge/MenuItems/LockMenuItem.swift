//
//  LockMenuItem.swift
//  macOSBridge
//
//  Menu item for door locks with confirmation for unlock
//

import AppKit

class LockMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var lockStateCharacteristicId: UUID?
    private var targetStateCharacteristicId: UUID?
    private var isLocked: Bool = true

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField
    private let toggleSwitch: ToggleSwitch

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = lockStateCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.lockStateCharacteristicId = serviceData.lockCurrentStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateCharacteristicId = serviceData.lockTargetStateId.flatMap { UUID(uuidString: $0) }

        let height = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.success
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
        statusLabel = NSTextField(labelWithString: "Locked")
        statusLabel.frame = NSRect(x: statusX, y: labelY, width: statusWidth, height: 17)
        statusLabel.font = DS.Typography.labelSmall
        statusLabel.textColor = DS.Colors.mutedForeground
        statusLabel.alignment = .right
        containerView.addSubview(statusLabel)

        // Toggle switch (on = locked, off = unlocked)
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        toggleSwitch.isOn = true
        containerView.addSubview(toggleSwitch)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleLock(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == lockStateCharacteristicId {
            if let state = value as? Int {
                isLocked = state == 1
                updateUI()
            }
        }
    }

    private func updateUI() {
        iconView.image = NSImage(systemSymbolName: isLocked ? "lock.fill" : "lock.open", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
        statusLabel.stringValue = isLocked ? "Locked" : "Unlocked"
        statusLabel.textColor = DS.Colors.mutedForeground
        toggleSwitch.setOn(isLocked, animated: false)
    }

    @objc private func toggleLock(_ sender: ToggleSwitch) {
        setLockState(locked: sender.isOn)
    }

    private func setLockState(locked: Bool) {
        if let id = targetStateCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: locked ? 1 : 0)
            isLocked = locked
            updateUI()
            // Notify with current state ID so other copies update
            if let currentId = lockStateCharacteristicId {
                notifyLocalChange(characteristicId: currentId, value: locked ? 1 : 0)
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
