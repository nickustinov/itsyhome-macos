//
//  SensorStateMenuItem.swift
//  macOSBridge
//
//  Read-only menu row for a single sensor, laid out like the other menu items:
//  a small icon plus name on the left, with the reading right-aligned. Binary
//  kinds (contact, motion, occupancy, leak, smoke, carbon monoxide, carbon
//  dioxide) show a state word (Open/Closed, Motion/Clear, Leak/Dry, ...) with a
//  state-aware icon; numeric kinds (temperature, humidity) show their formatted
//  reading, used for individual rows when the aggregate summary is off. The
//  aggregate temperature/humidity summary keeps its own two-column layout in
//  SensorSummaryMenuItem. See SensorKind for the per-kind characteristic, words
//  and formatting.
//

import AppKit

class SensorStateMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    weak var bridge: Mac2iOS?

    private let serviceData: ServiceData
    /// The HomeKit-equivalent kind, or nil for a generic Home Assistant sensor
    /// (driven instead by the ServiceData sensor fields).
    private let kind: SensorKind?
    private let stateCharacteristicId: UUID?

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let valueLabel: NSTextField
    private let batteryBadge: BatteryBadgeView?

    var characteristicIdentifiers: [UUID] {
        (stateCharacteristicId.map { [$0] } ?? []) + (batteryBadge?.characteristicIds ?? [])
    }

    /// The currently displayed reading (e.g. "Open", "Leak", "21.5°", "—").
    /// Exposed for tests; the underlying label stays private.
    var displayedState: String { valueLabel.stringValue }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.bridge = bridge
        self.serviceData = serviceData
        let kind = SensorKind(serviceType: serviceData.serviceType)
        self.kind = kind
        let charId = kind?.stateCharacteristicId(from: serviceData) ?? serviceData.sensorReadingId
        self.stateCharacteristicId = charId.flatMap { UUID(uuidString: $0) }

        // Single-line row matching the other menu items: small icon + name on
        // the left, reading right-aligned. (The aggregate temperature/humidity
        // summary keeps its own taller two-column layout in SensorSummaryMenuItem.)
        let height = DS.ControlSize.menuItemHeight
        containerView = HighlightingMenuItemView(
            frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)
        // Icon image is set by apply(nil) below, once the row reflects its state.

        // Reading label (right-aligned)
        let labelY = (height - 17) / 2
        let valueWidth: CGFloat = 80
        let valueX = DS.ControlSize.menuItemWidth - valueWidth - DS.Spacing.md
        valueLabel = NSTextField(labelWithString: "—")
        valueLabel.frame = NSRect(x: valueX, y: labelY - 1, width: valueWidth, height: 17)
        valueLabel.font = DS.Typography.labelSmall
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        containerView.addSubview(valueLabel)

        // Name label (fills space up to the reading)
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let titleLabel = NSTextField(labelWithString: serviceData.name)
        titleLabel.frame = NSRect(x: labelX, y: labelY, width: valueX - labelX - DS.Spacing.xs, height: 17)
        titleLabel.font = DS.Typography.label
        titleLabel.textColor = DS.Colors.foreground
        titleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(titleLabel)

        // Battery badge sits just left of the reading.
        batteryBadge = BatteryBadgeView(serviceData: serviceData)
        batteryBadge?.install(in: containerView, rightEdgeX: valueX - DS.Spacing.sm, nameLabel: titleLabel)

        super.init(title: "", action: nil, keyEquivalent: "")
        self.view = containerView

        apply(nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - CharacteristicUpdatable

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if let batteryBadge, batteryBadge.characteristicIds.contains(characteristicId) {
            batteryBadge.updateValue(for: characteristicId, value: value)
            return
        }
        guard characteristicId == stateCharacteristicId else { return }
        apply(value)
    }

    // MARK: - Display

    /// Update the value label and icon for a raw characteristic value (nil
    /// shows the placeholder). Numeric kinds format the reading; binary kinds
    /// map 1/0 to their state words and drive a state-aware icon.
    private func apply(_ value: Any?) {
        guard let kind else {
            applyGeneric(value)
            return
        }
        if kind.isNumeric {
            valueLabel.stringValue = value.flatMap(ValueConversion.toDouble)
                .flatMap(kind.formattedValue) ?? "—"
            iconView.image = IconResolver.icon(for: serviceData)
            refreshHistory()
            return
        }
        let raw = value.flatMap(ValueConversion.toInt)
        if let labels = kind.stateLabels {
            switch raw {
            case 1: valueLabel.stringValue = labels.one
            case 0: valueLabel.stringValue = labels.zero
            default: valueLabel.stringValue = "—"
            }
        }
        iconView.image = IconResolver.sensorIcon(for: serviceData, active: raw == 1)
        refreshHistory()
    }

    // MARK: - History

    private func refreshHistory() {
        // Match the summary row: history is a Pro feature gated on the toggle, so
        // "Record sensor history" off means no chart on any row (not just the
        // temperature/humidity summary).
        guard ProStatusCache.shared.isPro, PreferencesManager.shared.historyEnabled else {
            submenu = nil
            return
        }
        guard let kind, let id = stateCharacteristicId,
              let series = HistoryStore.shared.series(for: id),
              !series.numeric.isEmpty || !series.binary.isEmpty else {
            submenu = nil
            return
        }

        // Detail submenu (the expandable chart).
        let detail = HistoryDetailView(
            series: series,
            kind: kind.seriesKind,
            tint: SensorStateMenuItem.tint(for: kind),
            sessions: HistoryStore.shared.sessions,
            unitFormatter: { kind.formattedValue($0) ?? "" },
            stateFormatter: { state in
                if state == 1 { return kind.stateLabels?.one ?? String(localized: "sensor.state.generic.on", defaultValue: "On", bundle: .macOSBridge) }
                return kind.stateLabels?.zero ?? String(localized: "sensor.state.generic.off", defaultValue: "Off", bundle: .macOSBridge)
            })
        let host = NSMenuItem()
        host.view = detail
        let menu = NSMenu()
        menu.addItem(host)
        submenu = menu
    }

    private static func tint(for kind: SensorKind) -> NSColor {
        switch kind {
        case .temperature: return NSColor.systemOrange
        case .humidity: return NSColor.systemTeal
        default: return NSColor.controlAccentColor
        }
    }

    /// Generic Home Assistant sensor: a binary On/Off, or a numeric reading with
    /// its unit. The icon comes from the HA device_class via IconResolver.
    private func applyGeneric(_ value: Any?) {
        if serviceData.serviceType == ServiceTypes.binarySensor {
            let raw = value.flatMap(ValueConversion.toInt)
            let labels = GenericSensor.binaryLabels
            switch raw {
            case 1: valueLabel.stringValue = labels.one
            case 0: valueLabel.stringValue = labels.zero
            default: valueLabel.stringValue = "—"
            }
            iconView.image = IconResolver.icon(for: serviceData, filled: raw == 1)
        } else {
            valueLabel.stringValue = value.flatMap(ValueConversion.toDouble)
                .map { GenericSensor.formattedReading($0, unit: serviceData.sensorUnit) } ?? "—"
            iconView.image = IconResolver.icon(for: serviceData)
        }
    }
}
