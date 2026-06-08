//
//  SensorStateMenuItem.swift
//  macOSBridge
//
//  Read-only menu row for a binary safety/occupancy sensor (contact, motion,
//  occupancy, leak, smoke, carbon monoxide, carbon dioxide), styled like SensorSummaryMenuItem:
//  an icon plus a two-line name / state block. Each kind shows its own state
//  words (Open/Closed, Motion/Clear, Leak/Dry, ...). The icon is state-aware:
//  contact sensors swap door-open / door via the central config's modeIcons,
//  other kinds fill in when active, and a user's custom icon always wins.
//

import AppKit

class SensorStateMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    weak var bridge: Mac2iOS?

    /// The kind of binary sensor this row represents. Determines which
    /// characteristic drives the state and which words label it.
    private enum SensorKind {
        case contact, motion, occupancy, leak, smoke, carbonMonoxide, carbonDioxide

        init?(serviceType: String) {
            switch serviceType {
            case ServiceTypes.contactSensor: self = .contact
            case ServiceTypes.motionSensor: self = .motion
            case ServiceTypes.occupancySensor: self = .occupancy
            case ServiceTypes.leakSensor: self = .leak
            case ServiceTypes.smokeSensor: self = .smoke
            case ServiceTypes.carbonMonoxideSensor: self = .carbonMonoxide
            case ServiceTypes.carbonDioxideSensor: self = .carbonDioxide
            default: return nil
            }
        }

        /// The ServiceData field holding this kind's state characteristic UUID.
        func stateCharacteristicId(from serviceData: ServiceData) -> String? {
            switch self {
            case .contact: return serviceData.contactSensorStateId
            case .motion: return serviceData.motionDetectedId
            case .occupancy: return serviceData.occupancyDetectedId
            case .leak: return serviceData.leakDetectedId
            case .smoke: return serviceData.smokeDetectedId
            case .carbonMonoxide: return serviceData.carbonMonoxideDetectedId
            case .carbonDioxide: return serviceData.carbonDioxideDetectedId
            }
        }

        /// Display words for the raw characteristic value. HAP uses 1 for the
        /// "active" reading on every one of these sensors (open / motion /
        /// occupied / leak / smoke / CO / CO2) and 0 for the resting state.
        var stateLabels: (one: String, zero: String) {
            switch self {
            case .contact: return ("Open", "Closed")
            case .motion: return ("Motion", "Clear")
            case .occupancy: return ("Occupied", "Clear")
            case .leak: return ("Leak", "Dry")
            case .smoke: return ("Smoke", "Clear")
            case .carbonMonoxide: return ("CO", "Clear")
            case .carbonDioxide: return ("CO2", "Clear")
            }
        }
    }

    private let serviceData: ServiceData
    private let kind: SensorKind
    private let stateCharacteristicId: UUID?

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let valueLabel: NSTextField

    var characteristicIdentifiers: [UUID] {
        stateCharacteristicId.map { [$0] } ?? []
    }

    /// The currently displayed state word (e.g. "Open", "Leak", "—"). Exposed
    /// for tests; the underlying label stays private.
    var displayedState: String { valueLabel.stringValue }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.bridge = bridge
        self.serviceData = serviceData
        let kind = SensorKind(serviceType: serviceData.serviceType) ?? .contact
        self.kind = kind
        self.stateCharacteristicId = kind.stateCharacteristicId(from: serviceData)
            .flatMap { UUID(uuidString: $0) }

        let itemHeight: CGFloat = 44
        containerView = HighlightingMenuItemView(
            frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: itemHeight))

        let iconSize: CGFloat = 24
        var currentX = DS.Spacing.md

        // Icon (scaled to fit by the image view)
        iconView = NSImageView(frame: NSRect(x: currentX, y: 8, width: iconSize, height: iconSize))
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)
        // Icon is set by setState(nil) below, once the row reflects its state.

        currentX += iconSize + DS.Spacing.xs
        let textWidth = DS.ControlSize.menuItemWidth - currentX - DS.Spacing.md

        // Name (top)
        let titleLabel = NSTextField(labelWithString: serviceData.name)
        titleLabel.frame = NSRect(x: currentX, y: itemHeight - 10 - 12, width: textWidth, height: 12)
        titleLabel.font = DS.Typography.labelSmall
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(titleLabel)

        // State (bottom)
        valueLabel = NSTextField(labelWithString: "—")
        valueLabel.frame = NSRect(x: currentX, y: 6, width: textWidth, height: 14)
        valueLabel.font = DS.Typography.labelSmall
        valueLabel.textColor = .secondaryLabelColor
        containerView.addSubview(valueLabel)

        super.init(title: "", action: nil, keyEquivalent: "")
        self.view = containerView

        setState(nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - CharacteristicUpdatable

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        guard characteristicId == stateCharacteristicId else { return }
        setState(ValueConversion.toInt(value))
    }

    // MARK: - Display

    private func setState(_ raw: Int?) {
        let labels = kind.stateLabels
        switch raw {
        case 1: valueLabel.stringValue = labels.one
        case 0: valueLabel.stringValue = labels.zero
        default: valueLabel.stringValue = "—"
        }
        updateIcon(active: raw == 1)
    }

    /// Resolve the row icon for the current state. A user-chosen custom icon is
    /// always honoured (only its fill weight reflects state); otherwise the
    /// central config's per-state glyphs are used (e.g. door-open / door for a
    /// contact sensor), falling back to filling the default icon when active.
    private func updateIcon(active: Bool) {
        if PreferencesManager.shared.customIcon(for: serviceData.uniqueIdentifier) != nil {
            iconView.image = IconResolver.icon(for: serviceData, filled: active)
            return
        }
        let mode = active ? "open" : "closed"
        iconView.image = PhosphorIcon.modeIcon(for: serviceData.serviceType, mode: mode, filled: false)
            ?? IconResolver.icon(for: serviceData, filled: active)
    }
}
