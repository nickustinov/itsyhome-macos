//
//  HistoryDetailView.swift
//  macOSBridge
//
//  Larger history chart shown in the row's submenu: a bigger sparkline, a
//  min/now/max line for numeric kinds, and a 24h/7d/30d range toggle.
//
//  Hover support: moving the cursor over the chart replaces the stats label
//  with the value/state at that point in time; leaving reverts to range stats.
//

import AppKit

final class HistoryDetailView: NSView {

    enum Range: CaseIterable {
        case day, week, month
        var seconds: TimeInterval {
            switch self {
            case .day: return 24 * 60 * 60
            case .week: return 7 * 24 * 60 * 60
            case .month: return 30 * 24 * 60 * 60
            }
        }
        var label: String {
            switch self {
            case .day: return String(localized: "history.range.day", defaultValue: "24h", bundle: .macOSBridge)
            case .week: return String(localized: "history.range.week", defaultValue: "7d", bundle: .macOSBridge)
            case .month: return String(localized: "history.range.month", defaultValue: "30d", bundle: .macOSBridge)
            }
        }
    }

    private let series: SensorSeries
    private let kind: SeriesKind
    private let unitFormatter: (Double) -> String
    /// Optional formatter for a binary state int (1 or 0) to a display word.
    /// When nil, "On"/"Off" is used.
    private let stateFormatter: ((Int) -> String)?

    private let chart = SparklineView(frame: .zero)
    private let statsLabel = NSTextField(labelWithString: "")
    private let segmented = NSSegmentedControl()
    private var range: Range = .day

    // Reusable time formatter for hover labels.
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// `unitFormatter` formats a numeric value (e.g. "21.4 degrees"); for binary
    /// kinds it is unused. `stateFormatter` converts a binary state int to a word
    /// (e.g. "Open" for 1); pass nil to use a generic "On"/"Off".
    init(series: SensorSeries,
         kind: SeriesKind,
         tint: NSColor,
         unitFormatter: @escaping (Double) -> String,
         stateFormatter: ((Int) -> String)? = nil) {
        self.series = series
        self.kind = kind
        self.unitFormatter = unitFormatter
        self.stateFormatter = stateFormatter
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 96))
        chart.tint = tint
        buildLayout()
        applyRange()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        chart.frame = NSRect(x: 12, y: 34, width: 236, height: 44)
        addSubview(chart)

        statsLabel.frame = NSRect(x: 12, y: 12, width: 236, height: 16)
        statsLabel.font = NSFont.systemFont(ofSize: 11)
        statsLabel.textColor = .secondaryLabelColor
        addSubview(statsLabel)

        segmented.segmentCount = Range.allCases.count
        for (i, r) in Range.allCases.enumerated() {
            segmented.setLabel(r.label, forSegment: i)
            segmented.setWidth(46, forSegment: i)
        }
        segmented.selectedSegment = 0
        segmented.segmentStyle = .rounded
        segmented.controlSize = .mini
        segmented.target = self
        segmented.action = #selector(rangeChanged)
        segmented.frame = NSRect(x: 110, y: 70, width: 138, height: 20)
        addSubview(segmented)

        // Wire hover callback: show detail on move, restore stats on exit.
        chart.onHover = { [weak self] point in
            guard let self else { return }
            if let point {
                self.statsLabel.stringValue = self.hoverText(for: point)
            } else {
                self.applyRange()
            }
        }
    }

    @objc private func rangeChanged() {
        range = Range.allCases[segmented.selectedSegment]
        applyRange()
    }

    /// Oldest sample/transition in the series (arrays are appended in time order).
    private var earliestTimestamp: Date? {
        switch (series.numeric.first?.t, series.binary.first?.t) {
        case let (n?, b?): return min(n, b)
        case let (n?, nil): return n
        case let (nil, b?): return b
        default: return nil
        }
    }

    func applyRange() {
        let now = Date()
        let since = now.addingTimeInterval(-range.seconds)
        // Fit the chart to the data span so a short burst of recent activity is
        // visible instead of a sliver in a wide window. Never wider than the
        // selected range, never narrower than 5 minutes. This always covers all
        // in-range data (window >= data span), so nothing is hidden.
        let span = earliestTimestamp.map { now.timeIntervalSince($0) } ?? range.seconds
        chart.windowOverride = min(range.seconds, max(5 * 60, span * 1.2))
        chart.update(series: series, kind: kind, now: now)
        if kind == .numeric, let stats = HistoryRendering.stats(series.numeric.filter { $0.t >= since }) {
            statsLabel.stringValue = String(localized: "history.detail.stats",
                defaultValue: "min \(unitFormatter(stats.min))   now \(unitFormatter(stats.now))   max \(unitFormatter(stats.max))",
                bundle: .macOSBridge)
        } else if kind == .binary {
            let changes = series.binary.filter { $0.t >= since }.count
            statsLabel.stringValue = String(localized: "history.detail.changes",
                defaultValue: "\(changes) change\(changes == 1 ? "" : "s") in \(range.label)",
                bundle: .macOSBridge)
        } else {
            statsLabel.stringValue = String(localized: "history.detail.no_data", defaultValue: "No data yet", bundle: .macOSBridge)
        }
    }

    // MARK: - Hover label formatting

    private func hoverText(for point: SparklineView.HoverPoint) -> String {
        let timeStr = formattedTime(point.time)
        switch kind {
        case .numeric:
            if let value = point.value {
                return "\(unitFormatter(value))  \(timeStr)"
            }
            return timeStr
        case .binary:
            let stateStr: String
            if let state = point.state {
                stateStr = stateFormatter?(state)
                    ?? (state == 1 ? String(localized: "history.state.on", defaultValue: "On", bundle: .macOSBridge)
                                   : String(localized: "history.state.off", defaultValue: "Off", bundle: .macOSBridge))
            } else {
                stateStr = "-"
            }
            return "\(stateStr)  \(timeStr)"
        }
    }

    private func formattedTime(_ date: Date) -> String {
        // Include a short date when the sample is older than ~20 hours.
        let twentyHoursAgo = Date().addingTimeInterval(-20 * 60 * 60)
        if date < twentyHoursAgo {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return timeFormatter.string(from: date)
    }
}
