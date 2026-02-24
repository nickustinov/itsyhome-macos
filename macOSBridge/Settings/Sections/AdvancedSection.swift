//
//  AdvancedSection.swift
//  macOSBridge
//
//  Advanced settings section
//

import AppKit

class AdvancedSection: SettingsCard {

    private let temperaturePopUp = NSPopUpButton()
    private let simpleLightSwitch = NSSwitch()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        loadPreferences()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        // Temperature units box
        let tempBox = createCardBox()
        temperaturePopUp.removeAllItems()
        temperaturePopUp.addItems(withTitles: [
            String(localized: "settings.general.temperature_system", defaultValue: "System default", bundle: .macOSBridge),
            String(localized: "settings.general.temperature_celsius", defaultValue: "Celsius (°C)", bundle: .macOSBridge),
            String(localized: "settings.general.temperature_fahrenheit", defaultValue: "Fahrenheit (°F)", bundle: .macOSBridge)
        ])
        temperaturePopUp.controlSize = .small
        temperaturePopUp.target = self
        temperaturePopUp.action = #selector(temperatureUnitChanged)
        let tempRow = createSettingRow(label: String(localized: "settings.general.temperature_units", defaultValue: "Temperature units", bundle: .macOSBridge), control: temperaturePopUp)
        addContentToBox(tempBox, content: tempRow)
        stackView.addArrangedSubview(tempBox)
        tempBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Simple light controls box
        let lightBox = createCardBox()
        simpleLightSwitch.controlSize = .mini
        simpleLightSwitch.target = self
        simpleLightSwitch.action = #selector(simpleLightSwitchChanged)
        let simpleLightRow = createSettingRow(
            label: String(localized: "settings.general.simple_light_controls", defaultValue: "Simple light controls", bundle: .macOSBridge),
            subtitle: String(localized: "settings.general.simple_light_controls_subtitle", defaultValue: "Hide brightness and colour controls for lights.", bundle: .macOSBridge),
            control: simpleLightSwitch
        )
        addContentToBox(lightBox, content: simpleLightRow)
        stackView.addArrangedSubview(lightBox)
        lightBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func createCardBox() -> NSView {
        let box = CardBoxView()
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func addContentToBox(_ box: NSView, content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4)
        ])
    }

    private func createSettingRow(label: String, subtitle: String? = nil, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let labelField = createLabel(label, style: .body)
        labelStack.addArrangedSubview(labelField)

        if let subtitle = subtitle {
            let subtitleField = createLabel(subtitle, style: .caption)
            subtitleField.lineBreakMode = .byWordWrapping
            subtitleField.maximumNumberOfLines = 2
            labelStack.addArrangedSubview(subtitleField)
        }

        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelStack)
        container.addSubview(control)

        let rowHeight: CGFloat = subtitle != nil ? 56 : 36

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: rowHeight),
            labelStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func loadPreferences() {
        switch PreferencesManager.shared.temperatureUnit {
        case "celsius": temperaturePopUp.selectItem(at: 1)
        case "fahrenheit": temperaturePopUp.selectItem(at: 2)
        default: temperaturePopUp.selectItem(at: 0)
        }
        simpleLightSwitch.state = PreferencesManager.shared.simpleLightControls ? .on : .off
    }

    @objc private func temperatureUnitChanged(_ sender: NSPopUpButton) {
        let values = ["system", "celsius", "fahrenheit"]
        PreferencesManager.shared.temperatureUnit = values[sender.indexOfSelectedItem]
    }

    @objc private func simpleLightSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.simpleLightControls = sender.state == .on
    }
}
