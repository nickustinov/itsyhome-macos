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
    private let sensorSummarySwitch = NSSwitch()
    private let historySwitch = NSSwitch()

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
        addContentToBox(tempBox, content: tempRow, verticalInset: 4)
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
        addContentToBox(lightBox, content: simpleLightRow, verticalInset: 4)
        stackView.addArrangedSubview(lightBox)
        lightBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Sensor summary box
        let sensorBox = createCardBox()
        sensorSummarySwitch.controlSize = .mini
        sensorSummarySwitch.target = self
        sensorSummarySwitch.action = #selector(sensorSummarySwitchChanged)
        let sensorRow = createSettingRow(
            label: String(localized: "settings.advanced.sensor_summary", defaultValue: "Summarise temperature and humidity", bundle: .macOSBridge),
            subtitle: String(localized: "settings.advanced.sensor_summary_subtitle", defaultValue: "When off, shows each sensor individually.", bundle: .macOSBridge),
            control: sensorSummarySwitch
        )
        addContentToBox(sensorBox, content: sensorRow, verticalInset: 4)
        stackView.addArrangedSubview(sensorBox)
        sensorBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Sensor history: toggle + clear grouped in one card with a separator
        // between the rows (same idiom as the doorbell group in Cameras).
        let historyBox = createCardBox()
        let historyStack = NSStackView()
        historyStack.orientation = .vertical
        historyStack.spacing = 0
        historyStack.alignment = .leading
        historyStack.translatesAutoresizingMaskIntoConstraints = false

        historySwitch.controlSize = .mini
        historySwitch.target = self
        historySwitch.action = #selector(historySwitchChanged(_:))
        let historyRow = createSettingRow(
            label: String(localized: "settings.advanced.history", defaultValue: "Record sensor history", bundle: .macOSBridge),
            subtitle: String(localized: "settings.advanced.history_subtitle", defaultValue: "Keeps 30 days of temperature, humidity and sensor changes. Hover a sensor in the menu to see its chart.", bundle: .macOSBridge),
            control: historySwitch
        )
        historyStack.addArrangedSubview(historyRow)
        historyRow.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true
        // The two-line footnote fills its fixed-height row, leaving its last
        // line glued to the separator - give the hairline air above it.
        historyStack.setCustomSpacing(8, after: historyRow)

        let historySeparator = createSeparator()
        historyStack.addArrangedSubview(historySeparator)
        historySeparator.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true

        let clearButton = NSButton(
            title: String(localized: "settings.advanced.history_clear", defaultValue: "Clear history", bundle: .macOSBridge),
            target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        let clearRow = createSettingRow(
            label: String(localized: "settings.advanced.history_clear_label", defaultValue: "Stored history", bundle: .macOSBridge),
            control: clearButton
        )
        historyStack.addArrangedSubview(clearRow)
        clearRow.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true

        addContentToBox(historyBox, content: historyStack, verticalInset: 4)
        stackView.addArrangedSubview(historyBox)
        historyBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
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
            subtitleField.cell?.wraps = true
            subtitleField.cell?.isScrollable = false
            // Let the field shrink below its single-line width so long text wraps
            // instead of widening the (fixed-width) settings window.
            subtitleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            subtitleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
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
        sensorSummarySwitch.state = PreferencesManager.shared.sensorSummary ? .on : .off
        historySwitch.state = PreferencesManager.shared.historyEnabled ? .on : .off
        // History is a Pro feature; disable (not hide) the switch for free
        // users so it can't look functional while the store refuses to record.
        historySwitch.isEnabled = ProStatusCache.shared.isPro
    }

    @objc private func temperatureUnitChanged(_ sender: NSPopUpButton) {
        let values = ["system", "celsius", "fahrenheit"]
        PreferencesManager.shared.temperatureUnit = values[sender.indexOfSelectedItem]
    }

    @objc private func simpleLightSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.simpleLightControls = sender.state == .on
    }

    @objc private func sensorSummarySwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.sensorSummary = sender.state == .on
    }

    @objc private func historySwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.historyEnabled = sender.state == .on
    }

    @objc private func clearHistory() {
        HistoryStore.shared.clearAll()
    }
}
