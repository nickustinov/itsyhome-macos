//
//  HALockMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant locks with state-aware updating
//  Handles transitional states (locking/unlocking) and jammed state
//

import AppKit

class HALockMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var lockStateId: UUID?
    private var targetStateId: UUID?

    // HA lock states: locked, unlocked, locking, unlocking, jammed
    private var currentState: String = "locked"

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField
    private let toggleSwitch: ToggleSwitch

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = lockStateId { ids.append(id) }
        if let id = targetStateId { ids.append(id) }
        return ids
    }

    private var isLocked: Bool {
        currentState == "locked" || currentState == "locking"
    }

    private var isTransitioning: Bool {
        currentState == "locking" || currentState == "unlocking"
    }

    private var isJammed: Bool {
        currentState == "jammed"
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs
        self.lockStateId = serviceData.lockCurrentStateId?.uuid
        self.targetStateId = serviceData.lockTargetStateId?.uuid

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
        statusLabel = NSTextField(labelWithString: String(localized: "device.lock.locked", defaultValue: "Locked", bundle: .macOSBridge))
        statusLabel.frame = NSRect(x: statusX, y: labelY - 1, width: statusWidth, height: 17)
        statusLabel.font = DS.Typography.labelSmall
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        containerView.addSubview(statusLabel)

        // Toggle switch
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        toggleSwitch.setOn(true, animated: false)
        containerView.addSubview(toggleSwitch)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self, !self.isJammed, !self.isTransitioning else { return }
            self.setLockState(locked: !self.isLocked)
        }

        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleLock(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == lockStateId {
            // HA sends state as string or int
            if let stateString = value as? String {
                currentState = stateString
                updateUI()
            } else if let stateInt = ValueConversion.toInt(value) {
                // HomeKit-style: 0=unsecured, 1=secured, 2=jammed, 3=unknown
                switch stateInt {
                case 0: currentState = "unlocked"
                case 1: currentState = "locked"
                case 2: currentState = "jammed"
                default: currentState = "locked"
                }
                updateUI()
            }
        }
    }

    private func updateUI() {
        // Update icon image only - let HighlightingMenuItemView handle tint color
        let mode = isLocked ? "locked" : "unlocked"
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: isLocked)
            ?? IconResolver.icon(for: serviceData, filled: isLocked)

        // Update status label text (don't set textColor - let HighlightingMenuItemView handle it)
        switch currentState {
        case "locked": statusLabel.stringValue = String(localized: "device.lock.locked", defaultValue: "Locked", bundle: .macOSBridge)
        case "unlocked": statusLabel.stringValue = String(localized: "device.lock.unlocked", defaultValue: "Unlocked", bundle: .macOSBridge)
        case "locking": statusLabel.stringValue = String(localized: "device.lock.locking", defaultValue: "Locking...", bundle: .macOSBridge)
        case "unlocking": statusLabel.stringValue = String(localized: "device.lock.unlocking", defaultValue: "Unlocking...", bundle: .macOSBridge)
        case "jammed": statusLabel.stringValue = String(localized: "device.lock.jammed", defaultValue: "Jammed", bundle: .macOSBridge)
        default: statusLabel.stringValue = currentState.capitalized
        }

        // Update toggle
        toggleSwitch.setOn(isLocked, animated: false)
        toggleSwitch.isEnabled = !isJammed

        // Orange tint during transitional states
        if isTransitioning {
            toggleSwitch.onTintColor = DS.Colors.warning
        } else {
            toggleSwitch.onTintColor = DS.Colors.switchOn
        }
    }

    @objc private func toggleLock(_ sender: ToggleSwitch) {
        guard !isJammed, !isTransitioning else {
            // Revert switch to current state
            sender.setOn(isLocked, animated: true)
            return
        }
        setLockState(locked: sender.isOn)
    }

    private func setLockState(locked: Bool) {
        guard let id = targetStateId else { return }

        // Optimistic update to transitional state
        currentState = locked ? "locking" : "unlocking"
        updateUI()

        bridge?.writeCharacteristic(identifier: id, value: locked ? 1 : 0)

        // Notify with current state ID so other copies update
        if let currentId = lockStateId {
            notifyLocalChange(characteristicId: currentId, value: locked ? 1 : 0)
        }
    }
}
