//
//  SwitchMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling switches and outlets
//

import AppKit

class SwitchMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var powerCharacteristicId: UUID?
    private var isOn: Bool = false

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let toggleSwitch: ToggleSwitch

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = powerCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.powerCharacteristicId = serviceData.powerStateId.flatMap { UUID(uuidString: $0) }

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: DS.ControlSize.menuItemHeight))

        // Icon
        let iconY = (DS.ControlSize.menuItemHeight - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (DS.ControlSize.menuItemHeight - 17) / 2
        let labelWidth = DS.ControlSize.menuItemWidth - labelX - DS.ControlSize.switchWidth - DS.Spacing.lg - DS.Spacing.md
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Toggle switch
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let switchY = (DS.ControlSize.menuItemHeight - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isOn.toggle()
            self.toggleSwitch.setOn(self.isOn, animated: true)
            if let id = self.powerCharacteristicId {
                self.bridge?.writeCharacteristic(identifier: id, value: self.isOn)
                self.notifyLocalChange(characteristicId: id, value: self.isOn)
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

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == powerCharacteristicId {
            if let power = ValueConversion.toBool(value) {
                isOn = power
                updateUI()
            }
        }
    }

    private func updateUI() {
        iconView.image = IconResolver.icon(for: serviceData, filled: isOn)
        toggleSwitch.setOn(isOn, animated: false)
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isOn = sender.isOn
        if let id = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: isOn)
            notifyLocalChange(characteristicId: id, value: isOn)
        }
        updateUI()
    }
}
