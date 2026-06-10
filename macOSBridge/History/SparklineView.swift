//
//  SparklineView.swift
//  macOSBridge
//
//  Tiny inline trend for a sensor row: a line for numeric kinds, an on/off
//  timeline bar for binary kinds. Renders the last 24 hours by default;
//  set windowOverride to use a different range (used by the detail chart).
//
//  Hover support: when onHover is set the view installs a tracking area and
//  calls back with the nearest data point under the cursor, or nil when the
//  cursor leaves the view.
//

import AppKit

final class SparklineView: NSView {

    /// How far back the inline sparkline looks (default: 24 hours).
    static let window: TimeInterval = 24 * 60 * 60

    /// Overrides the default 24h window (used by the detail chart's range toggle).
    var windowOverride: TimeInterval?

    /// Minimum value span used to scale the numeric line, so a sensor whose
    /// reading wobbles within a small band (e.g. an AC current-temp drifting
    /// 1-2 degrees) reads as a gentle line, not a full-height sawtooth. In the
    /// series' native unit (degrees C for temperature, % for humidity).
    var numericMinRange: Double = 5

    private var series: SensorSeries?
    private var kind: SeriesKind = .numeric
    private var referenceNow: Date = Date()

    /// Tint for the line / "on" segments. Defaults to the control accent.
    var tint: NSColor = .controlAccentColor { didSet { needsDisplay = true } }

    // MARK: - Hover

    struct HoverPoint {
        let time: Date
        let value: Double?
        let state: Int?
    }

    /// Called with the nearest data point when the cursor moves inside the view,
    /// or with nil when the cursor exits. Set to nil to disable hover entirely.
    var onHover: ((HoverPoint?) -> Void)?

    private var hoverX: CGFloat?
    private var trackingArea: NSTrackingArea?

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(series: SensorSeries, kind: SeriesKind, now: Date = Date()) {
        self.series = series
        self.kind = kind
        self.referenceNow = now
        needsDisplay = true
    }

    // MARK: - Tracking area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        // `.activeAlways` is required: this is a menu-bar app, so its menus are
        // shown while the app is not the active app, and `.activeInActiveApp`
        // tracking would silently never fire. Mirrors HighlightingMenuItemView.
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Clear any stale cursor when the menu closes (window becomes nil) or
        // reopens, so a fresh hover starts clean. The system re-runs
        // updateTrackingAreas on the window change to re-establish tracking.
        if hoverX != nil {
            hoverX = nil
            onHover?(nil)
            needsDisplay = true
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard onHover != nil, let series else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let x = min(max(loc.x, 0), bounds.width)
        let since = referenceNow.addingTimeInterval(-(windowOverride ?? Self.window))
        let fraction = bounds.width > 0 ? Double(x / bounds.width) : 0
        let cursorTime = since.addingTimeInterval(fraction * referenceNow.timeIntervalSince(since))

        let point: HoverPoint
        switch kind {
        case .numeric:
            let inWindow = series.numeric.filter { $0.t >= since && $0.t <= referenceNow }
            guard let nearest = inWindow.min(by: { abs($0.t.timeIntervalSince(cursorTime)) < abs($1.t.timeIntervalSince(cursorTime)) }) else { return }
            point = HoverPoint(time: nearest.t, value: nearest.v, state: nil)
        case .binary:
            // Mirror HistoryRendering.binarySegments seeding: state at cursorTime
            // is the last transition at/before cursorTime, or the inverse of the
            // first in-window transition if capture began inside the window.
            let windowed = series.binary.filter { $0.t > since && $0.t <= referenceNow }
            let state: Int?
            if let seed = series.binary.last(where: { $0.t <= cursorTime }) {
                state = seed.s
            } else if let first = windowed.first {
                state = first.s == 1 ? 0 : 1
            } else {
                state = nil
            }
            point = HoverPoint(time: cursorTime, value: nil, state: state)
        }

        hoverX = x
        onHover?(point)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoverX = nil
        onHover?(nil)
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let series else { return }
        let since = referenceNow.addingTimeInterval(-(windowOverride ?? Self.window))
        switch kind {
        case .numeric:
            drawLine(series.numeric, since: since)
        case .binary:
            drawTimeline(series.binary, since: since)
        }
        drawHoverCursor(series: series, since: since)
    }

    private func drawLine(_ samples: [NumericSample], since: Date) {
        let pts = HistoryRendering.numericPoints(samples, width: bounds.width, height: bounds.height,
                                                 since: since, now: referenceNow, minRange: numericMinRange)
        guard pts.count > 1 else { return }
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        tint.setStroke()
        path.stroke()
    }

    private func drawTimeline(_ transitions: [BinaryTransition], since: Date) {
        let segments = HistoryRendering.binarySegments(transitions, width: bounds.width,
                                                       since: since, now: referenceNow)
        // "On" (open/detected) pops in the tint; "off" (resting) is a muted but
        // clearly visible track so a held state reads as a filled bar, not blank.
        let off = NSColor.secondaryLabelColor
        for seg in segments {
            let rect = NSRect(x: seg.x, y: bounds.midY - 5, width: max(seg.width, 1), height: 10)
            (seg.on ? tint : off).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        }
    }

    private func drawHoverCursor(series: SensorSeries, since: Date) {
        guard let hoverX, onHover != nil else { return }

        // Vertical cursor line.
        let line = NSBezierPath()
        line.lineWidth = 1
        line.move(to: CGPoint(x: hoverX, y: 0))
        line.line(to: CGPoint(x: hoverX, y: bounds.height))
        NSColor.secondaryLabelColor.setStroke()
        line.stroke()

        // For numeric: draw a small filled dot at the nearest sample's y position.
        if kind == .numeric {
            let inWindow = series.numeric.filter { $0.t >= since && $0.t <= referenceNow }
            let pts = HistoryRendering.numericPoints(inWindow, width: bounds.width,
                                                     height: bounds.height,
                                                     since: since, now: referenceNow, minRange: numericMinRange)
            // Find the point whose x is closest to hoverX.
            if let nearest = pts.min(by: { abs($0.x - hoverX) < abs($1.x - hoverX) }) {
                let dotRadius: CGFloat = 3
                let dotRect = NSRect(
                    x: nearest.x - dotRadius,
                    y: nearest.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2)
                let dot = NSBezierPath(ovalIn: dotRect)
                tint.setFill()
                dot.fill()
            }
        }
    }
}
