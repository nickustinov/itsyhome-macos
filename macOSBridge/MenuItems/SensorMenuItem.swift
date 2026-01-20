//
//  SensorMenuItem.swift
//  macOSBridge
//
//  Menu item for read-only sensors (temperature, humidity, motion)
//

import AppKit

class SensorMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var valueCharacteristicId: UUID?

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let valueLabel: NSTextField

    var characteristicIdentifiers: [UUID] {
        if let id = valueCharacteristicId { return [id] }
        return []
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUID based on sensor type
        switch serviceData.serviceType {
        case ServiceTypes.temperatureSensor:
            self.valueCharacteristicId = serviceData.currentTemperatureId.flatMap { UUID(uuidString: $0) }
        case ServiceTypes.humiditySensor:
            self.valueCharacteristicId = serviceData.humidityId.flatMap { UUID(uuidString: $0) }
        case ServiceTypes.motionSensor:
            self.valueCharacteristicId = serviceData.motionDetectedId.flatMap { UUID(uuidString: $0) }
        default:
            self.valueCharacteristicId = nil
        }

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))

        // Determine icon based on service type
        let iconName: String = {
            switch serviceData.serviceType {
            case ServiceTypes.temperatureSensor:
                return "thermometer"
            case ServiceTypes.humiditySensor:
                return "humidity"
            case ServiceTypes.motionSensor:
                return "figure.walk.motion"
            default:
                return "sensor"
            }
        }()

        // Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 5, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        containerView.addSubview(iconView)

        // Name label
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: 6, width: 140, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Value label
        valueLabel = NSTextField(labelWithString: "--")
        valueLabel.frame = NSRect(x: 180, y: 6, width: 60, height: 17)
        valueLabel.font = NSFont.systemFont(ofSize: 13)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        containerView.addSubview(valueLabel)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == valueCharacteristicId {
            updateDisplay(value: value)
        }
    }

    private func updateDisplay(value: Any) {
        switch serviceData.serviceType {
        case ServiceTypes.temperatureSensor:
            if let temp = value as? Double {
                valueLabel.stringValue = String(format: "%.1f°C", temp)
            } else if let temp = value as? Int {
                valueLabel.stringValue = String(format: "%.1f°C", Double(temp))
            }
        case ServiceTypes.humiditySensor:
            if let humidity = value as? Double {
                valueLabel.stringValue = String(format: "%.0f%%", humidity)
            } else if let humidity = value as? Int {
                valueLabel.stringValue = "\(humidity)%"
            }
        case ServiceTypes.motionSensor:
            if let motion = value as? Bool {
                valueLabel.stringValue = motion ? "Motion" : "Clear"
                iconView.contentTintColor = motion ? .systemOrange : .secondaryLabelColor
            } else if let motion = value as? Int {
                let detected = motion != 0
                valueLabel.stringValue = detected ? "Motion" : "Clear"
                iconView.contentTintColor = detected ? .systemOrange : .secondaryLabelColor
            }
        default:
            valueLabel.stringValue = "\(value)"
        }
    }
}
