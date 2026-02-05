//
//  HAValveMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant valves with state-aware updating
//  Handles transitional states (opening/closing) and optional position slider
//

import AppKit

class HAValveMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var valveStateId: UUID?
    private var activeId: UUID?
    private var currentPositionId: UUID?
    private var targetPositionId: UUID?

    // HA valve states: open, closed, opening, closing
    private var currentState: String = "closed"
    private var position: Int = 0
    private var ignorePositionUpdatesUntil: Date?

    private let hasPosition: Bool
    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField
    private let toggleSwitch: ToggleSwitch
    private var positionSlider: ModernSlider?

    private let singleRowHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let twoRowHeight: CGFloat = DS.ControlSize.menuItemHeight + 24

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = valveStateId { ids.append(id) }
        if let id = activeId { ids.append(id) }
        if let id = currentPositionId { ids.append(id) }
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
        self.valveStateId = serviceData.valveStateId?.uuid
        self.activeId = serviceData.activeId?.uuid
        self.currentPositionId = serviceData.currentPositionId?.uuid
        self.targetPositionId = serviceData.targetPositionId?.uuid
        self.hasPosition = serviceData.targetPositionId != nil

        let height = hasPosition ? twoRowHeight : singleRowHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Row 1: Icon, name, status, toggle
        let row1Y = hasPosition ? (height - singleRowHeight) : 0

        // Icon
        let iconY = row1Y + (singleRowHeight - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
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
        let labelY = row1Y + (singleRowHeight - 17) / 2
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

        // Toggle switch
        let switchY = row1Y + (singleRowHeight - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        // Row 2: Position slider (only for valves with SET_POSITION)
        if hasPosition {
            let row2Y: CGFloat = DS.Spacing.sm

            let sliderWidth = DS.ControlSize.sliderWidth
            let thumbOffset = DS.ControlSize.sliderThumbSize / 2
            let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md + thumbOffset

            // Position label
            let posLabelWidth: CGFloat = 30
            let posLabelX = sliderX - posLabelWidth - DS.Spacing.xs
            let posLabel = NSTextField(labelWithString: "0%")
            posLabel.frame = NSRect(x: posLabelX, y: row2Y - 1, width: posLabelWidth, height: 14)
            posLabel.font = DS.Typography.labelSmall
            posLabel.textColor = .secondaryLabelColor
            posLabel.alignment = .right
            containerView.addSubview(posLabel)

            // Slider
            let slider = ModernSlider(minValue: 0, maxValue: 100)
            slider.frame = NSRect(x: sliderX, y: row2Y, width: sliderWidth, height: 12)
            slider.doubleValue = 0
            slider.isContinuous = false
            slider.progressTintColor = DS.Colors.sliderFan
            containerView.addSubview(slider)
            positionSlider = slider
        }

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self, !self.isTransitioning else { return }
            self.setValveState(open: !self.isOpen)
        }

        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleValve(_:))

        positionSlider?.target = self
        positionSlider?.action = #selector(positionSliderChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == valveStateId {
            if let stateString = value as? String {
                currentState = stateString
                updateUI()
            }
        } else if characteristicId == currentPositionId {
            if let pos = ValueConversion.toInt(value) {
                if isLocalChange {
                    ignorePositionUpdatesUntil = Date().addingTimeInterval(60)
                }
                if !isLocalChange, let ignoreUntil = ignorePositionUpdatesUntil, Date() < ignoreUntil {
                    return
                }
                position = pos
                positionSlider?.doubleValue = Double(pos)
                updatePositionLabel()
            }
        } else if characteristicId == activeId {
            // Fallback: interpret active as bool for initial state
            if let active = ValueConversion.toBool(value) {
                let newState = active ? "open" : "closed"
                if !isTransitioning {
                    currentState = newState
                    updateUI()
                }
            }
        }
    }

    private func updateUI() {
        // Update icon
        iconView.image = IconResolver.icon(for: serviceData, filled: isOpen)

        // Update status label
        switch currentState {
        case "open":
            statusLabel.stringValue = hasPosition ? "\(position)%" : "Open"
            statusLabel.textColor = .secondaryLabelColor
        case "closed":
            statusLabel.stringValue = "Closed"
            statusLabel.textColor = .secondaryLabelColor
        case "opening":
            statusLabel.stringValue = "Opening..."
            statusLabel.textColor = DS.Colors.warning
        case "closing":
            statusLabel.stringValue = "Closing..."
            statusLabel.textColor = DS.Colors.warning
        default:
            statusLabel.stringValue = currentState.capitalized
            statusLabel.textColor = .secondaryLabelColor
        }

        // Update toggle
        toggleSwitch.setOn(isOpen, animated: false)

        // Orange tint during transitional states
        if isTransitioning {
            toggleSwitch.onTintColor = DS.Colors.warning
        } else {
            toggleSwitch.onTintColor = DS.Colors.switchOn
        }
    }

    private func updatePositionLabel() {
        // Find the position label (first label in row 2 area)
        for subview in containerView.subviews {
            if let label = subview as? NSTextField,
               label !== nameLabel,
               label !== statusLabel,
               label.frame.origin.y < singleRowHeight / 2 {
                label.stringValue = "\(position)%"
                break
            }
        }
        // Also update status to show position when open
        if currentState == "open" && hasPosition {
            statusLabel.stringValue = "\(position)%"
        }
    }

    @objc private func toggleValve(_ sender: ToggleSwitch) {
        guard !isTransitioning else {
            sender.setOn(isOpen, animated: true)
            return
        }
        setValveState(open: sender.isOn)
    }

    @objc private func positionSliderChanged(_ sender: ModernSlider) {
        let value = Int(sender.doubleValue)
        position = value
        updatePositionLabel()

        if let id = targetPositionId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            if let currentId = currentPositionId {
                notifyLocalChange(characteristicId: currentId, value: value)
            }
        }
    }

    private func setValveState(open: Bool) {
        guard let id = activeId else { return }

        // Optimistic update to transitional state
        currentState = open ? "opening" : "closing"
        updateUI()

        bridge?.writeCharacteristic(identifier: id, value: open)

        // Notify with valve state ID so other copies update
        if let stateId = valveStateId {
            notifyLocalChange(characteristicId: stateId, value: open ? "open" : "closed")
        }
    }
}
