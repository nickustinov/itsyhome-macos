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
    private let positionSlider: NSSlider
    private let positionLabel: NSTextField

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

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 50))

        // Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 15, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: "blinds.horizontal.closed", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        containerView.addSubview(iconView)

        // Name label
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: 28, width: 160, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Position label
        positionLabel = NSTextField(labelWithString: "0%")
        positionLabel.frame = NSRect(x: 200, y: 28, width: 40, height: 17)
        positionLabel.font = NSFont.systemFont(ofSize: 11)
        positionLabel.textColor = .secondaryLabelColor
        positionLabel.alignment = .right
        containerView.addSubview(positionLabel)

        // Position slider
        positionSlider = NSSlider(frame: NSRect(x: 38, y: 5, width: 200, height: 20))
        positionSlider.minValue = 0
        positionSlider.maxValue = 100
        positionSlider.integerValue = 0
        positionSlider.isContinuous = false
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
                positionSlider.integerValue = pos
                positionLabel.stringValue = "\(pos)%"
                updateIcon()
            }
        }
    }

    private func updateIcon() {
        let symbolName: String
        if position == 0 {
            symbolName = "blinds.horizontal.closed"
        } else if position == 100 {
            symbolName = "blinds.horizontal.open"
        } else {
            symbolName = "blinds.horizontal.open"
        }
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = position > 0 ? .systemBlue : .secondaryLabelColor
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.integerValue
        position = value
        positionLabel.stringValue = "\(value)%"
        updateIcon()

        if let id = targetPositionCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: value)
        }
    }
}
