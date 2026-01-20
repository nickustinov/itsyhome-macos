//
//  SwitchMenuItem.swift
//  macOSBridge
//
//  Menu item for simple on/off switches and outlets
//

import AppKit

class SwitchMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var powerCharacteristicId: UUID?
    private var isOn: Bool = false

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let toggleButton: NSButton

    var characteristicIdentifiers: [UUID] {
        if let id = powerCharacteristicId { return [id] }
        return []
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUID from ServiceData
        self.powerCharacteristicId = serviceData.powerStateId.flatMap { UUID(uuidString: $0) }

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))

        // Icon
        let iconName = serviceData.serviceType == ServiceTypes.outlet ? "poweroutlet.type.b" : "switch.2"
        iconView = NSImageView(frame: NSRect(x: 10, y: 5, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        containerView.addSubview(iconView)

        // Name label
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: 6, width: 160, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Toggle switch
        toggleButton = NSButton(frame: NSRect(x: 200, y: 2, width: 40, height: 26))
        toggleButton.setButtonType(.switch)
        toggleButton.title = ""
        containerView.addSubview(toggleButton)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        toggleButton.target = self
        toggleButton.action = #selector(togglePower(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == powerCharacteristicId, let boolValue = value as? Bool {
            isOn = boolValue
            updateUI()
        } else if characteristicId == powerCharacteristicId, let intValue = value as? Int {
            isOn = intValue != 0
            updateUI()
        }
    }

    private func updateUI() {
        toggleButton.state = isOn ? .on : .off
        iconView.contentTintColor = isOn ? .systemGreen : .secondaryLabelColor
    }

    @objc private func togglePower(_ sender: NSButton) {
        isOn = sender.state == .on
        if let id = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: isOn)
        }
        updateUI()
    }
}
