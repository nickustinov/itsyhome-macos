//
//  BatteryBadge.swift
//  macOSBridge
//
//  Small battery indicator shown inline after a device name for battery-powered
//  accessories, mirroring the iOS app: a proportionally-filled battery glyph
//  (green / orange ≤20% / red when low) followed by the percentage. Self
//  contained – it owns its battery characteristic ids and updates itself.
//

import AppKit

/// The drawn battery glyph: rounded body outline, proportional fill, and a nub.
private final class BatteryGauge: NSView {
    var level: Int = 0 { didSet { needsDisplay = true } }
    var isLow: Bool = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let h = bounds.height
        let nubW: CGFloat = 1.5
        let bodyW = w - nubW
        let cornerR: CGFloat = 1.5
        let inset: CGFloat = 1
        let fraction = CGFloat(max(0, min(level, 100))) / 100.0

        let outline = NSColor.secondaryLabelColor.withAlphaComponent(0.6)
        let fill: NSColor = isLow ? DS.Colors.destructive : (level <= 20 ? DS.Colors.warning : DS.Colors.success)

        // Body outline
        let bodyRect = NSRect(x: 0.5, y: 0.5, width: bodyW - 1, height: h - 1)
        let body = NSBezierPath(roundedRect: bodyRect, xRadius: cornerR, yRadius: cornerR)
        body.lineWidth = 1
        outline.setStroke()
        body.stroke()

        // Fill
        let fillW = max((bodyW - inset * 2) * fraction, 1)
        let fillRect = NSRect(x: inset, y: inset, width: fillW, height: h - inset * 2)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: max(cornerR - inset, 0.5), yRadius: max(cornerR - inset, 0.5))
        fill.setFill()
        fillPath.fill()

        // Nub (positive terminal)
        let nubRect = NSRect(x: bodyW, y: h * 0.3, width: nubW, height: h * 0.4)
        let nub = NSBezierPath(roundedRect: nubRect, xRadius: 0.5, yRadius: 0.5)
        outline.setFill()
        nub.fill()
    }
}

/// Inline battery badge (glyph + percentage). Created only for services that
/// expose a battery level; hidden until the first reading arrives.
final class BatteryBadgeView: NSView {

    static let gaugeSize = NSSize(width: 20, height: 10)
    private static let labelWidth: CGFloat = 32  // fits "100%"
    private static let gaugeGap: CGFloat = 4
    /// Total width of the badge (glyph + spacing + percentage label).
    static let width: CGFloat = gaugeSize.width + gaugeGap + labelWidth

    private let levelCharId: UUID?
    private let lowCharId: UUID?
    private let gauge = BatteryGauge()
    private let percentLabel = NSTextField(labelWithString: "")

    private var level: Int?
    private var isLow = false

    /// Battery characteristics this badge tracks (for the row's subscriptions).
    var characteristicIds: [UUID] { [levelCharId, lowCharId].compactMap { $0 } }

    /// Returns nil when the service has no battery level characteristic.
    init?(serviceData: ServiceData) {
        guard let levelId = serviceData.batteryLevelId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        self.levelCharId = levelId
        self.lowCharId = serviceData.statusLowBatteryId.flatMap { UUID(uuidString: $0) }

        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 17))

        let gaugeY = (bounds.height - Self.gaugeSize.height) / 2
        gauge.frame = NSRect(x: 0, y: gaugeY, width: Self.gaugeSize.width, height: Self.gaugeSize.height)
        addSubview(gauge)

        // Nudge the percentage down 1pt so its baseline lines up with the name.
        percentLabel.frame = NSRect(x: Self.gaugeSize.width + Self.gaugeGap, y: -1, width: Self.labelWidth, height: 17)
        percentLabel.font = DS.Typography.labelSmall
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .left
        addSubview(percentLabel)

        isHidden = true  // shown once a level is known
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Place the badge right after the name text (like iOS), bounded by
    /// `rightEdgeX` so it never collides with the trailing control. Shrinks the
    /// name label to its text so the badge can sit next to it.
    func install(in container: NSView, rightEdgeX: CGFloat, nameLabel: NSTextField) {
        // Size the name to its text (sizeToFit accounts for the field's padding,
        // so short names like "Door" never truncate) and sit right after it,
        // capped so we don't run into the trailing control.
        let origin = nameLabel.frame.origin
        let height = nameLabel.frame.height
        nameLabel.sizeToFit()
        let gap = DS.Spacing.sm - 2  // sit a touch closer to the name
        let maxNameWidth = max(0, rightEdgeX - gap - Self.width - origin.x)
        let nameWidth = min(nameLabel.frame.width, maxNameWidth)
        nameLabel.frame = NSRect(x: origin.x, y: origin.y, width: nameWidth, height: height)

        let x = origin.x + nameWidth + gap
        let y = nameLabel.frame.midY - frame.height / 2
        frame = NSRect(x: x, y: y, width: Self.width, height: frame.height)
        container.addSubview(self)
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == levelCharId, let level = ValueConversion.toInt(value) {
            self.level = level
        } else if characteristicId == lowCharId, let low = ValueConversion.toInt(value) {
            self.isLow = low == 1
        } else {
            return
        }
        refresh()
    }

    private func refresh() {
        guard let level else { return }
        gauge.level = level
        gauge.isLow = isLow
        percentLabel.stringValue = "\(level)%"
        percentLabel.textColor = isLow ? DS.Colors.destructive : .secondaryLabelColor
        isHidden = false
    }
}
