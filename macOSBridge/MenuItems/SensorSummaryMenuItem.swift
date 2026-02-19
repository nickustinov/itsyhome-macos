//
//  SensorSummaryMenuItem.swift
//  macOSBridge
//
//  Compact summary of temperature and humidity sensors for a room
//

import AppKit

class SensorSummaryMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    weak var bridge: Mac2iOS?

    private var temperatureCharacteristicIds: [UUID] = []
    private var humidityCharacteristicIds: [UUID] = []

    private var temperatureValues: [UUID: Double] = [:]
    private var humidityValues: [UUID: Double] = [:]

    private let containerView: NSView
    private let tempIconView: NSImageView
    private let tempTitleLabel: NSTextField
    private let tempValueLabel: NSTextField
    private let humidityIconView: NSImageView
    private let humidityTitleLabel: NSTextField
    private let humidityValueLabel: NSTextField

    var characteristicIdentifiers: [UUID] {
        return temperatureCharacteristicIds + humidityCharacteristicIds
    }

    init(temperatureSensors: [ServiceData], humiditySensors: [ServiceData], bridge: Mac2iOS?) {
        self.bridge = bridge

        // Extract characteristic IDs
        for sensor in temperatureSensors {
            if let idString = sensor.currentTemperatureId, let id = UUID(uuidString: idString) {
                temperatureCharacteristicIds.append(id)
            }
        }
        for sensor in humiditySensors {
            if let idString = sensor.humidityId, let id = UUID(uuidString: idString) {
                humidityCharacteristicIds.append(id)
            }
        }

        let hasTemp = !temperatureCharacteristicIds.isEmpty
        let hasHumidity = !humidityCharacteristicIds.isEmpty

        // Taller height for two-line layout
        let itemHeight: CGFloat = 44

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: itemHeight))

        let iconSize: CGFloat = 24
        let sectionWidth: CGFloat = 115

        var currentX = DS.Spacing.md

        // Temperature section - center icon with two-line text block
        let iconY: CGFloat = 8
        tempIconView = NSImageView(frame: NSRect(x: currentX, y: iconY, width: iconSize, height: iconSize))
        tempIconView.image = PhosphorIcon.regular("thermometer")
        tempIconView.contentTintColor = .secondaryLabelColor
        tempIconView.imageScaling = .scaleProportionallyUpOrDown
        tempIconView.isHidden = !hasTemp
        containerView.addSubview(tempIconView)

        currentX += iconSize + DS.Spacing.xs

        // Temperature title (top)
        let titleY = itemHeight - 10 - 12
        tempTitleLabel = NSTextField(labelWithString: String(localized: "device.sensor.temperature", defaultValue: "Temperature", bundle: .macOSBridge))
        tempTitleLabel.frame = NSRect(x: currentX, y: titleY, width: 80, height: 12)
        tempTitleLabel.font = DS.Typography.labelSmall
        tempTitleLabel.textColor = .secondaryLabelColor
        tempTitleLabel.isHidden = !hasTemp
        containerView.addSubview(tempTitleLabel)

        // Temperature value (bottom)
        let valueY: CGFloat = 6
        tempValueLabel = NSTextField(labelWithString: "—")
        tempValueLabel.frame = NSRect(x: currentX, y: valueY, width: 80, height: 14)
        tempValueLabel.font = DS.Typography.labelSmall
        tempValueLabel.textColor = .secondaryLabelColor
        tempValueLabel.isHidden = !hasTemp
        containerView.addSubview(tempValueLabel)

        currentX += sectionWidth

        // Humidity section
        humidityIconView = NSImageView(frame: NSRect(x: currentX, y: iconY, width: iconSize, height: iconSize))
        humidityIconView.image = PhosphorIcon.regular("drop-half")
        humidityIconView.contentTintColor = .secondaryLabelColor
        humidityIconView.imageScaling = .scaleProportionallyUpOrDown
        humidityIconView.isHidden = !hasHumidity
        containerView.addSubview(humidityIconView)

        currentX += iconSize + DS.Spacing.xs

        // Humidity title (top)
        humidityTitleLabel = NSTextField(labelWithString: String(localized: "device.sensor.humidity", defaultValue: "Humidity", bundle: .macOSBridge))
        humidityTitleLabel.frame = NSRect(x: currentX, y: titleY, width: 70, height: 12)
        humidityTitleLabel.font = DS.Typography.labelSmall
        humidityTitleLabel.textColor = .secondaryLabelColor
        humidityTitleLabel.isHidden = !hasHumidity
        containerView.addSubview(humidityTitleLabel)

        // Humidity value (bottom)
        humidityValueLabel = NSTextField(labelWithString: "—")
        humidityValueLabel.frame = NSRect(x: currentX, y: valueY, width: 70, height: 14)
        humidityValueLabel.font = DS.Typography.labelSmall
        humidityValueLabel.textColor = .secondaryLabelColor
        humidityValueLabel.isHidden = !hasHumidity
        containerView.addSubview(humidityValueLabel)

        super.init(title: "", action: nil, keyEquivalent: "")

        self.view = containerView
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if temperatureCharacteristicIds.contains(characteristicId) {
            if let temp = ValueConversion.toDouble(value) {
                temperatureValues[characteristicId] = temp
            }
            updateTemperatureDisplay()
        } else if humidityCharacteristicIds.contains(characteristicId) {
            if let humidity = ValueConversion.toDouble(value) {
                humidityValues[characteristicId] = humidity
            }
            updateHumidityDisplay()
        }
    }

    private func updateTemperatureDisplay() {
        guard !temperatureValues.isEmpty else {
            tempValueLabel.stringValue = "—"
            return
        }

        let values = Array(temperatureValues.values).sorted()
        let minTemp = values.first ?? 0
        let maxTemp = values.last ?? 0

        if values.count == 1 || minTemp == maxTemp {
            // Single value
            tempValueLabel.stringValue = TemperatureFormatter.format(minTemp, decimals: 1)
        } else {
            // Range (smallest – largest)
            let minFormatted = TemperatureFormatter.format(minTemp, decimals: 1)
            let maxFormatted = TemperatureFormatter.format(maxTemp, decimals: 1)
            tempValueLabel.stringValue = "\(minFormatted.dropLast())–\(maxFormatted)"
        }
    }

    private func updateHumidityDisplay() {
        guard !humidityValues.isEmpty else {
            humidityValueLabel.stringValue = "—"
            return
        }

        let values = Array(humidityValues.values).sorted()
        let minHumidity = values.first ?? 0
        let maxHumidity = values.last ?? 0

        if values.count == 1 || minHumidity == maxHumidity {
            // Single value
            humidityValueLabel.stringValue = String(format: "%.0f%%", minHumidity)
        } else {
            // Range (smallest – largest)
            humidityValueLabel.stringValue = String(format: "%.0f–%.0f%%", minHumidity, maxHumidity)
        }
    }
}
