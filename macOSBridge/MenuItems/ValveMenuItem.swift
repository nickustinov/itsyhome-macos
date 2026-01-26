//
//  ValveMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling valves (irrigation, faucets, etc.)
//

import AppKit

class ValveMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var activeId: UUID?
    private var inUseId: UUID?
    private let valveType: Int  // 0=generic, 1=irrigation, 2=shower, 3=faucet

    private var isActive: Bool = false
    private var isInUse: Bool = false

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let inUseIndicator: NSView
    private let toggleSwitch: ToggleSwitch

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = activeId { ids.append(id) }
        if let id = inUseId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.activeId = serviceData.activeId.flatMap { UUID(uuidString: $0) }
        self.inUseId = serviceData.inUseId.flatMap { UUID(uuidString: $0) }
        self.valveType = serviceData.valveTypeValue ?? 0

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: DS.ControlSize.menuItemHeight))

        // Icon
        let iconY = (DS.ControlSize.menuItemHeight - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = PhosphorIcon.regular(Self.iconName(for: valveType))
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Toggle switch position (rightmost)
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let switchY = (DS.ControlSize.menuItemHeight - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        // In Use indicator (small dot before toggle)
        let indicatorSize: CGFloat = 8
        let indicatorX = switchX - indicatorSize - DS.Spacing.sm
        let indicatorY = (DS.ControlSize.menuItemHeight - indicatorSize) / 2
        inUseIndicator = NSView(frame: NSRect(x: indicatorX, y: indicatorY, width: indicatorSize, height: indicatorSize))
        inUseIndicator.wantsLayer = true
        inUseIndicator.layer?.cornerRadius = indicatorSize / 2
        inUseIndicator.layer?.backgroundColor = DS.Colors.success.cgColor
        inUseIndicator.isHidden = true
        containerView.addSubview(inUseIndicator)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (DS.ControlSize.menuItemHeight - 17) / 2
        let labelWidth = indicatorX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
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
            if let id = self.activeId {
                self.bridge?.writeCharacteristic(identifier: id, value: self.isActive ? 1 : 0)
                self.notifyLocalChange(characteristicId: id, value: self.isActive ? 1 : 0)
            }
            self.updateUI()
        }

        // Set up action
        toggleSwitch.target = self
        toggleSwitch.action = #selector(togglePower(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func iconName(for valveType: Int) -> String {
        switch valveType {
        case 1: return "pipe"     // irrigation
        case 2: return "shower"   // shower
        case 3: return "drop"     // faucet
        default: return "pipe"    // generic
        }
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == activeId {
            if let active = ValueConversion.toBool(value) {
                isActive = active
                updateUI()
            }
        } else if characteristicId == inUseId {
            if let inUse = ValueConversion.toBool(value) {
                isInUse = inUse
                updateUI()
            }
        }
    }

    private func updateUI() {
        let iconName = Self.iconName(for: valveType)
        iconView.image = PhosphorIcon.icon(iconName, filled: isActive)

        toggleSwitch.setOn(isActive, animated: false)

        // Show "In Use" indicator when water is flowing
        inUseIndicator.isHidden = !isInUse
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isActive = sender.isOn
        if let id = activeId {
            bridge?.writeCharacteristic(identifier: id, value: isActive ? 1 : 0)
            notifyLocalChange(characteristicId: id, value: isActive ? 1 : 0)
        }
        updateUI()
    }
}
