//
//  BlindMenuItem.swift
//  macOSBridge
//
//  Menu item for blinds/window coverings with position slider and optional tilt

import AppKit

class BlindMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentPositionId: UUID?
    private var targetPositionId: UUID?
    private var currentTiltId: UUID?   // Horizontal or vertical tilt (whichever is present)
    private var targetTiltId: UUID?

    private var position: Int = 0
    private var tilt: Int = 0  // -90 to 90, where 0 = horizontal/open
    private var ignorePositionUpdatesUntil: Date?
    private var ignoreTiltUpdatesUntil: Date?

    private let hasTilt: Bool
    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let positionSlider: ModernSlider

    // Tilt row (only created if tilt is present)
    private var tiltLabel: NSTextField?
    private var tiltSlider: ModernSlider?

    private let singleRowHeight: CGFloat = DS.ControlSize.menuItemHeight
    private let twoRowHeight: CGFloat = DS.ControlSize.menuItemHeight + 24

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentPositionId { ids.append(id) }
        if let id = currentTiltId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentPositionId = serviceData.currentPositionId.flatMap { UUID(uuidString: $0) }
        self.targetPositionId = serviceData.targetPositionId.flatMap { UUID(uuidString: $0) }

        // Check for tilt - prefer horizontal, fall back to vertical
        if let horizCurrent = serviceData.currentHorizontalTiltId.flatMap({ UUID(uuidString: $0) }),
           let horizTarget = serviceData.targetHorizontalTiltId.flatMap({ UUID(uuidString: $0) }) {
            self.currentTiltId = horizCurrent
            self.targetTiltId = horizTarget
            self.hasTilt = true
        } else if let vertCurrent = serviceData.currentVerticalTiltId.flatMap({ UUID(uuidString: $0) }),
                  let vertTarget = serviceData.targetVerticalTiltId.flatMap({ UUID(uuidString: $0) }) {
            self.currentTiltId = vertCurrent
            self.targetTiltId = vertTarget
            self.hasTilt = true
        } else {
            self.hasTilt = false
        }

        let height = hasTilt ? twoRowHeight : singleRowHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Row 1: Icon, name, position slider
        let row1Y = hasTilt ? (height - singleRowHeight) : 0
        let iconY = row1Y + (singleRowHeight - DS.ControlSize.iconMedium) / 2

        // Icon
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Slider position (right-aligned)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = row1Y + (singleRowHeight - 17) / 2
        let labelWidth = sliderX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Position slider
        let sliderY = row1Y + (singleRowHeight - 12) / 2
        positionSlider = ModernSlider(minValue: 0, maxValue: 100)
        positionSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        positionSlider.doubleValue = 0
        positionSlider.isContinuous = false
        positionSlider.progressTintColor = DS.Colors.sliderFan
        containerView.addSubview(positionSlider)

        // Row 2: Tilt label and slider (if tilt is present)
        if hasTilt {
            let row2Y: CGFloat = DS.Spacing.sm

            // Tilt label (right-aligned before slider, same spacing as status labels)
            let tiltLabelWidth: CGFloat = 30
            let tiltLabelX = sliderX - tiltLabelWidth - DS.Spacing.xs
            let tiltLabelView = NSTextField(labelWithString: "Tilt")
            tiltLabelView.frame = NSRect(x: tiltLabelX, y: row2Y - 1, width: tiltLabelWidth, height: 14)
            tiltLabelView.font = DS.Typography.labelSmall
            tiltLabelView.textColor = .secondaryLabelColor
            tiltLabelView.alignment = .right
            containerView.addSubview(tiltLabelView)
            tiltLabel = tiltLabelView

            // Tilt slider (-90 to 90, but we use 0-100 for display where 50 = 0°)
            let tiltSliderView = ModernSlider(minValue: -90, maxValue: 90)
            tiltSliderView.frame = NSRect(x: sliderX, y: row2Y, width: sliderWidth, height: 12)
            tiltSliderView.doubleValue = 0
            tiltSliderView.isContinuous = false
            tiltSliderView.progressTintColor = DS.Colors.sliderFan
            containerView.addSubview(tiltSliderView)
            tiltSlider = tiltSliderView
        }

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            let newPosition = self.position > 50 ? 0 : 100
            self.position = newPosition
            self.positionSlider.doubleValue = Double(newPosition)
            self.updateIcon()
            if let id = self.targetPositionId {
                self.bridge?.writeCharacteristic(identifier: id, value: newPosition)
                if let currentId = self.currentPositionId {
                    self.notifyLocalChange(characteristicId: currentId, value: newPosition)
                }
            }
        }

        // Set up actions
        positionSlider.target = self
        positionSlider.action = #selector(positionSliderChanged(_:))

        tiltSlider?.target = self
        tiltSlider?.action = #selector(tiltSliderChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentPositionId {
            if let pos = ValueConversion.toInt(value) {
                if isLocalChange {
                    ignorePositionUpdatesUntil = Date().addingTimeInterval(60)
                }

                if !isLocalChange, let ignoreUntil = ignorePositionUpdatesUntil, Date() < ignoreUntil {
                    return
                }

                position = pos
                positionSlider.doubleValue = Double(pos)
                updateIcon()
            }
        } else if characteristicId == currentTiltId {
            if let t = ValueConversion.toInt(value) {
                if isLocalChange {
                    ignoreTiltUpdatesUntil = Date().addingTimeInterval(60)
                }

                if !isLocalChange, let ignoreUntil = ignoreTiltUpdatesUntil, Date() < ignoreUntil {
                    return
                }

                tilt = t
                tiltSlider?.doubleValue = Double(t)
            }
        }
    }

    private func updateIcon() {
        iconView.image = IconResolver.icon(for: serviceData, filled: position > 0)
    }

    @objc private func positionSliderChanged(_ sender: ModernSlider) {
        let value = Int(sender.doubleValue)
        position = value
        updateIcon()

        if let id = targetPositionId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            if let currentId = currentPositionId {
                notifyLocalChange(characteristicId: currentId, value: value)
            }
        }
    }

    @objc private func tiltSliderChanged(_ sender: ModernSlider) {
        let value = Int(sender.doubleValue)
        tilt = value

        if let id = targetTiltId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            if let currentId = currentTiltId {
                notifyLocalChange(characteristicId: currentId, value: value)
            }
        }
    }
}
