//
//  SlatMenuItem.swift
//  macOSBridge
//
//  Menu item for slat/louver control with tilt angle slider

import AppKit

class SlatMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentTiltAngleId: UUID?
    private var targetTiltAngleId: UUID?
    private var swingModeId: UUID?
    private var currentSlatStateId: UUID?

    private var tiltAngle: Int = 0  // -90 to 90, where 0 = horizontal/open
    private var isSwingEnabled: Bool = false
    private var ignoreTiltUpdatesUntil: Date?

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let tiltSlider: ModernSlider

    // Swing button (only created if swing mode is present)
    private var swingButton: ModeButton?
    private var swingButtonGroup: ModeButtonGroup?

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentTiltAngleId { ids.append(id) }
        if let id = currentSlatStateId { ids.append(id) }
        if let id = swingModeId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentTiltAngleId = serviceData.currentTiltAngleId.flatMap { UUID(uuidString: $0) }
        self.targetTiltAngleId = serviceData.targetTiltAngleId.flatMap { UUID(uuidString: $0) }
        self.swingModeId = serviceData.swingModeId.flatMap { UUID(uuidString: $0) }
        self.currentSlatStateId = serviceData.currentSlatStateId.flatMap { UUID(uuidString: $0) }

        let height = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Slider position (right-aligned)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md

        // Swing button group position (before slider, only if present)
        let swingGroupWidth = ModeButtonGroup.widthForIconButtons(count: 1)
        let swingGroupX = sliderX - (swingModeId != nil ? swingGroupWidth + DS.Spacing.sm : 0)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let labelWidth = (swingModeId != nil ? swingGroupX : sliderX) - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Swing button group (before slider, only if present)
        if swingModeId != nil {
            let swingY = (height - 18) / 2
            let swingGroup = ModeButtonGroup(frame: NSRect(x: swingGroupX, y: swingY, width: swingGroupWidth, height: 18))
            swingButton = swingGroup.addButton(icon: "angle", color: DS.Colors.sliderFan)
            containerView.addSubview(swingGroup)
            swingButtonGroup = swingGroup
        }

        // Tilt slider (-90 to 90)
        let sliderY = (height - 12) / 2
        tiltSlider = ModernSlider(minValue: -90, maxValue: 90)
        tiltSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        tiltSlider.doubleValue = 0
        tiltSlider.isContinuous = false
        tiltSlider.progressTintColor = DS.Colors.sliderFan
        containerView.addSubview(tiltSlider)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            // Toggle between -90/0/90 on click
            let newTilt: Int
            if self.tiltAngle < -45 {
                newTilt = 0
            } else if self.tiltAngle < 45 {
                newTilt = 90
            } else {
                newTilt = -90
            }
            self.tiltAngle = newTilt
            self.tiltSlider.doubleValue = Double(newTilt)
            self.updateIcon()
            if let id = self.targetTiltAngleId {
                self.bridge?.writeCharacteristic(identifier: id, value: newTilt)
                if let currentId = self.currentTiltAngleId {
                    self.notifyLocalChange(characteristicId: currentId, value: newTilt)
                }
            }
        }

        // Set up actions
        tiltSlider.target = self
        tiltSlider.action = #selector(tiltSliderChanged(_:))

        swingButton?.target = self
        swingButton?.action = #selector(swingButtonTapped(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentTiltAngleId {
            if let angle = ValueConversion.toInt(value) {
                if isLocalChange {
                    ignoreTiltUpdatesUntil = Date().addingTimeInterval(60)
                }

                if !isLocalChange, let ignoreUntil = ignoreTiltUpdatesUntil, Date() < ignoreUntil {
                    return
                }

                tiltAngle = angle
                tiltSlider.doubleValue = Double(angle)
                updateIcon()
            }
        } else if characteristicId == swingModeId {
            if let swing = ValueConversion.toBool(value) {
                isSwingEnabled = swing
                swingButton?.isSelected = swing
            }
        }
    }

    private func updateIcon() {
        // Icon filled when slats are not horizontal (tilted)
        let isTilted = abs(tiltAngle) > 10
        iconView.image = IconResolver.icon(for: serviceData, filled: isTilted)
    }

    @objc private func tiltSliderChanged(_ sender: ModernSlider) {
        let value = Int(sender.doubleValue)
        tiltAngle = value
        updateIcon()

        if let id = targetTiltAngleId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            if let currentId = currentTiltAngleId {
                notifyLocalChange(characteristicId: currentId, value: value)
            }
        }
    }

    @objc private func swingButtonTapped(_ sender: ModeButton) {
        isSwingEnabled.toggle()
        sender.isSelected = isSwingEnabled

        if let id = swingModeId {
            bridge?.writeCharacteristic(identifier: id, value: isSwingEnabled ? 1 : 0)
            notifyLocalChange(characteristicId: id, value: isSwingEnabled ? 1 : 0)
        }
    }
}
