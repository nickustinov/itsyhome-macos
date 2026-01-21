//
//  BlindMenuItem.swift
//  macOSBridge
//
//  Menu item for blinds/window coverings with position slider
//

import AppKit

class BlindMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentPositionCharacteristicId: UUID?
    private var targetPositionCharacteristicId: UUID?
    private var position: Int = 0

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let positionSlider: ModernSlider

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentPositionCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentPositionCharacteristicId = serviceData.currentPositionId.flatMap { UUID(uuidString: $0) }
        self.targetPositionCharacteristicId = serviceData.targetPositionId.flatMap { UUID(uuidString: $0) }

        // Single row height
        let height: CGFloat = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "blinds.horizontal.closed", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Slider position (right-aligned)
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let labelWidth = sliderX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Position slider (fixed width, right-aligned)
        let sliderY = (height - 12) / 2
        positionSlider = ModernSlider(minValue: 0, maxValue: 100)
        positionSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        positionSlider.doubleValue = 0
        positionSlider.isContinuous = false
        positionSlider.progressTintColor = DS.Colors.sliderBlind
        containerView.addSubview(positionSlider)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        positionSlider.target = self
        positionSlider.action = #selector(sliderChanged(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == currentPositionCharacteristicId {
            if let pos = value as? Int {
                position = pos
                positionSlider.doubleValue = Double(pos)
                updateIcon()
            }
        }
    }

    private func updateIcon() {
        let symbolName: String
        if position == 0 {
            symbolName = "blinds.horizontal.closed"
        } else {
            symbolName = "blinds.horizontal.open"
        }
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = position > 0 ? DS.Colors.info : DS.Colors.mutedForeground
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        let value = Int(sender.doubleValue)
        position = value
        updateIcon()

        if let id = targetPositionCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: value)
            // Notify with current position ID so other copies update their slider
            if let currentId = currentPositionCharacteristicId {
                notifyLocalChange(characteristicId: currentId, value: value)
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
