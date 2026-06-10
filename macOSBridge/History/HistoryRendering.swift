//
//  HistoryRendering.swift
//  macOSBridge
//
//  Pure geometry for sparkline/detail rendering. No AppKit so it stays testable.
//

import CoreGraphics
import Foundation

enum HistoryRendering {

    /// Maps in-window numeric samples to points. x runs left->right across
    /// [since, now]; y is inverted (max value at top y=0, min at bottom y=height).
    /// `minRange` is a floor on the value span used for scaling: when the data
    /// varies by less than this, the data is centred in a `minRange`-tall band so
    /// small wobbles read as a gentle line rather than a full-height sawtooth.
    /// Equal values (with `minRange` 0) render at mid-height.
    static func numericPoints(_ samples: [NumericSample], width: CGFloat, height: CGFloat,
                              since: Date, now: Date, minRange: Double = 0) -> [CGPoint] {
        let windowed = samples.filter { $0.t >= since && $0.t <= now }
        guard !windowed.isEmpty else { return [] }

        let span = max(now.timeIntervalSince(since), 1)
        let values = windowed.map(\.v)
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let mid = (minV + maxV) / 2
        let effectiveRange = max(maxV - minV, minRange)
        let lo = mid - effectiveRange / 2

        return windowed.map { sample in
            let x = CGFloat(sample.t.timeIntervalSince(since) / span) * width
            let normalized: CGFloat = effectiveRange == 0 ? 0.5 : CGFloat((sample.v - lo) / effectiveRange)
            let y = height - normalized * height
            return CGPoint(x: x, y: y)
        }
    }

    /// One drawable segment of a binary timeline.
    struct Segment: Equatable {
        let x: CGFloat
        let width: CGFloat
        let on: Bool
    }

    /// Expands transitions into contiguous on/off segments spanning [since, now].
    /// The window is always filled: the state at the left edge is seeded from the
    /// last transition at/before `since`, or - when capture only began inside the
    /// window - inferred as the inverse of the first in-window transition. This
    /// avoids a blank bar for a sensor that has held one state across the window.
    static func binarySegments(_ transitions: [BinaryTransition], width: CGFloat,
                               since: Date, now: Date) -> [Segment] {
        guard !transitions.isEmpty else { return [] }

        let span = max(now.timeIntervalSince(since), 1)
        func x(_ date: Date) -> CGFloat {
            CGFloat(min(max(date.timeIntervalSince(since), 0), span) / span) * width
        }

        // Transitions strictly inside the window.
        let windowed = transitions.filter { $0.t > since && $0.t <= now }

        // Seed the state at the window's left edge so the bar is never blank.
        var effective: [BinaryTransition] = []
        if let seed = transitions.last(where: { $0.t <= since }) {
            effective.append(BinaryTransition(t: since, s: seed.s))
        } else if let first = windowed.first {
            // Capture began inside the window: before the first transition the
            // sensor must have held the opposite state.
            effective.append(BinaryTransition(t: since, s: first.s == 1 ? 0 : 1))
        }
        effective.append(contentsOf: windowed)
        guard !effective.isEmpty else { return [] }

        var segments: [Segment] = []
        for (index, transition) in effective.enumerated() {
            let startX = x(transition.t)
            let endDate = index + 1 < effective.count ? effective[index + 1].t : now
            let endX = x(endDate)
            segments.append(Segment(x: startX, width: endX - startX, on: transition.s == 1))
        }
        return segments
    }

    /// min / current (last) / max for the detail header. nil when empty.
    static func stats(_ samples: [NumericSample]) -> (min: Double, now: Double, max: Double)? {
        guard let last = samples.last else { return nil }
        let values = samples.map(\.v)
        return (values.min() ?? last.v, last.v, values.max() ?? last.v)
    }
}
