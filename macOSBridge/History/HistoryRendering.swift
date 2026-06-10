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

    /// Like `numericPoints`, but split into continuous runs: a break is
    /// inserted between consecutive samples not covered by a single capture
    /// session, so the line shows a gap where recording was off. Scaling is
    /// shared across all in-window samples. Empty `sessions` means coverage
    /// tracking isn't available - everything renders as one run (no gaps).
    static func numericPointRuns(_ samples: [NumericSample], width: CGFloat, height: CGFloat,
                                 since: Date, now: Date, minRange: Double = 0,
                                 sessions: [CaptureSession] = []) -> [[CGPoint]] {
        let windowed = samples.filter { $0.t >= since && $0.t <= now }
        let pts = numericPoints(windowed, width: width, height: height,
                                since: since, now: now, minRange: minRange)
        guard !pts.isEmpty else { return [] }
        guard !sessions.isEmpty, pts.count > 1 else { return [pts] }

        var runs: [[CGPoint]] = [[pts[0]]]
        for i in 1..<pts.count {
            let a = windowed[i - 1].t
            let b = windowed[i].t
            let covered = sessions.contains { $0.start <= a && b <= $0.end }
            if covered {
                runs[runs.count - 1].append(pts[i])
            } else {
                runs.append([pts[i]])
            }
        }
        return runs
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
    /// `sessions` clips the bar to capture coverage: window regions not covered
    /// by any session stay blank (no data) instead of extending the held state
    /// across periods when nothing was recording. Empty `sessions` keeps the
    /// legacy behaviour of filling the whole window.
    static func binarySegments(_ transitions: [BinaryTransition], width: CGFloat,
                               since: Date, now: Date,
                               sessions: [CaptureSession] = []) -> [Segment] {
        guard !transitions.isEmpty else { return [] }

        // Coverage intervals clipped to the window (whole window when no info).
        let intervals: [(Date, Date)]
        if sessions.isEmpty {
            intervals = [(since, now)]
        } else {
            intervals = sessions.compactMap { session in
                let start = max(session.start, since)
                let end = min(session.end, now)
                return start < end ? (start, end) : nil
            }
        }

        let span = max(now.timeIntervalSince(since), 1)
        func x(_ date: Date) -> CGFloat {
            CGFloat(min(max(date.timeIntervalSince(since), 0), span) / span) * width
        }

        var segments: [Segment] = []
        for (intervalStart, intervalEnd) in intervals {
            // Transitions strictly inside this covered interval.
            let windowed = transitions.filter { $0.t > intervalStart && $0.t <= intervalEnd }

            // Seed the state at the interval's left edge so a held state reads
            // as a filled bar across the whole covered region.
            var effective: [BinaryTransition] = []
            if let seed = transitions.last(where: { $0.t <= intervalStart }) {
                effective.append(BinaryTransition(t: intervalStart, s: seed.s))
            } else if let first = windowed.first {
                // Capture began inside the interval: before the first transition
                // the sensor must have held the opposite state.
                effective.append(BinaryTransition(t: intervalStart, s: first.s == 1 ? 0 : 1))
            }
            effective.append(contentsOf: windowed)

            for (index, transition) in effective.enumerated() {
                let startX = x(transition.t)
                let endDate = index + 1 < effective.count ? effective[index + 1].t : intervalEnd
                let endX = x(endDate)
                segments.append(Segment(x: startX, width: endX - startX, on: transition.s == 1))
            }
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
