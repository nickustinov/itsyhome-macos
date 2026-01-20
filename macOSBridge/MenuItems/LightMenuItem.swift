//
//  LightMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling lights with brightness slider
//

import AppKit

class LightMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var powerCharacteristicId: UUID?
    private var brightnessCharacteristicId: UUID?
    private var isOn: Bool = false
    private var brightness: Double = 100

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let brightnessSlider: NSSlider
    private let toggleButton: NSButton

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = powerCharacteristicId { ids.append(id) }
        if let id = brightnessCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.powerCharacteristicId = serviceData.powerStateId.flatMap { UUID(uuidString: $0) }
        self.brightnessCharacteristicId = serviceData.brightnessId.flatMap { UUID(uuidString: $0) }

        let hasBrightness = brightnessCharacteristicId != nil

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: hasBrightness ? 50 : 30))

        // Icon
        let iconY = hasBrightness ? 15 : 5
        iconView = NSImageView(frame: NSRect(x: 10, y: iconY, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        containerView.addSubview(iconView)

        // Name label
        let labelY = hasBrightness ? 28 : 6
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: labelY, width: 170, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Brightness slider (only if dimmable)
        brightnessSlider = NSSlider(frame: NSRect(x: 38, y: 5, width: 160, height: 20))
        brightnessSlider.minValue = 0
        brightnessSlider.maxValue = 100
        brightnessSlider.doubleValue = 100
        brightnessSlider.isContinuous = false
        brightnessSlider.isHidden = !hasBrightness
        if hasBrightness {
            containerView.addSubview(brightnessSlider)
        }

        // Toggle button
        let buttonY = hasBrightness ? 12 : 2
        toggleButton = NSButton(frame: NSRect(x: 210, y: buttonY, width: 30, height: 26))
        toggleButton.bezelStyle = .inline
        toggleButton.setButtonType(.toggle)
        toggleButton.title = ""
        toggleButton.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        containerView.addSubview(toggleButton)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up actions
        brightnessSlider.target = self
        brightnessSlider.action = #selector(sliderChanged(_:))

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
        } else if characteristicId == brightnessCharacteristicId, let doubleValue = value as? Double {
            brightness = doubleValue
            brightnessSlider.doubleValue = doubleValue
        } else if characteristicId == brightnessCharacteristicId, let intValue = value as? Int {
            brightness = Double(intValue)
            brightnessSlider.doubleValue = brightness
        }
    }

    private func updateUI() {
        iconView.image = NSImage(systemSymbolName: isOn ? "lightbulb.fill" : "lightbulb", accessibilityDescription: nil)
        iconView.contentTintColor = isOn ? .systemYellow : .secondaryLabelColor
        toggleButton.state = isOn ? .on : .off
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        if let id = brightnessCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: Int(value))
        }

        // Also turn on if setting brightness > 0 and light is off
        if value > 0 && !isOn, let powerId = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: powerId, value: true)
            isOn = true
            updateUI()
        }
    }

    @objc private func togglePower(_ sender: NSButton) {
        isOn = sender.state == .on
        if let id = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: isOn)
        }
        updateUI()
    }
}
