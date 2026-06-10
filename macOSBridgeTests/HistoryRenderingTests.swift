//
//  HistoryRenderingTests.swift
//  macOSBridgeTests
//

import XCTest
import CoreGraphics
@testable import macOSBridge

final class HistoryRenderingTests: XCTestCase {

    private let since = Date(timeIntervalSince1970: 0)
    private let now = Date(timeIntervalSince1970: 100)

    func testNumericPointsMapTimeToXAndValueToInvertedY() {
        let samples = [
            NumericSample(t: Date(timeIntervalSince1970: 0), v: 10),
            NumericSample(t: Date(timeIntervalSince1970: 50), v: 20),
            NumericSample(t: Date(timeIntervalSince1970: 100), v: 30),
        ]
        let points = HistoryRendering.numericPoints(samples, width: 100, height: 10, since: since, now: now)

        XCTAssertEqual(points.count, 3)
        // x maps left-to-right across the window.
        XCTAssertEqual(points[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(points[1].x, 50, accuracy: 0.001)
        XCTAssertEqual(points[2].x, 100, accuracy: 0.001)
        // y is inverted: min value -> bottom (height), max value -> top (0).
        XCTAssertEqual(points[0].y, 10, accuracy: 0.001)
        XCTAssertEqual(points[2].y, 0, accuracy: 0.001)
    }

    func testNumericPointsFlatLineWhenAllEqual() {
        let samples = [
            NumericSample(t: Date(timeIntervalSince1970: 0), v: 21),
            NumericSample(t: Date(timeIntervalSince1970: 100), v: 21),
        ]
        let points = HistoryRendering.numericPoints(samples, width: 100, height: 10, since: since, now: now)
        // Equal values render mid-height, not NaN.
        XCTAssertEqual(points[0].y, 5, accuracy: 0.001)
        XCTAssertEqual(points[1].y, 5, accuracy: 0.001)
    }

    func testNumericPointsEmptyForNoSamples() {
        XCTAssertTrue(HistoryRendering.numericPoints([], width: 100, height: 10, since: since, now: now).isEmpty)
    }

    func testNumericPointsClampsSmallVariationToMinRange() {
        // Values vary by 1 but minRange is 10: the data should occupy ~10% of the
        // height, centred, rather than filling it (the anti-sawtooth behaviour).
        let samples = [
            NumericSample(t: Date(timeIntervalSince1970: 0), v: 20),
            NumericSample(t: Date(timeIntervalSince1970: 100), v: 21),
        ]
        let pts = HistoryRendering.numericPoints(samples, width: 100, height: 100,
                                                 since: since, now: now, minRange: 10)
        // mid = 20.5, effectiveRange = 10, lo = 15.5 -> 20 maps to 0.45, 21 to 0.55.
        XCTAssertEqual(pts[0].y, 55, accuracy: 0.01)
        XCTAssertEqual(pts[1].y, 45, accuracy: 0.01)
    }

    func testBinarySegmentsSpanWindowByState() {
        // Open at t=0, closed at t=50; window is [0,100].
        let transitions = [
            BinaryTransition(t: Date(timeIntervalSince1970: 0), s: 1),
            BinaryTransition(t: Date(timeIntervalSince1970: 50), s: 0),
        ]
        let segments = HistoryRendering.binarySegments(transitions, width: 100, since: since, now: now)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(segments[0].width, 50, accuracy: 0.001)
        XCTAssertTrue(segments[0].on)
        XCTAssertEqual(segments[1].x, 50, accuracy: 0.001)
        XCTAssertEqual(segments[1].width, 50, accuracy: 0.001)
        XCTAssertFalse(segments[1].on)
    }

    func testBinarySegmentsSeedsStateWhenLastTransitionPredatesWindow() {
        // Door opened before the window and held open: no transition inside
        // [since, now], so the whole window must read as a single "on" bar.
        let transitions = [BinaryTransition(t: Date(timeIntervalSince1970: -10), s: 1)]
        let segments = HistoryRendering.binarySegments(transitions, width: 100, since: since, now: now)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(segments[0].width, 100, accuracy: 0.001)
        XCTAssertTrue(segments[0].on)
    }

    func testBinarySegmentsInfersPriorStateWhenCaptureBeganInsideWindow() {
        // First-ever sample is an "open" inside the window: before it, the sensor
        // must have been closed, so the lead-in segment fills as "off".
        let transitions = [BinaryTransition(t: Date(timeIntervalSince1970: 80), s: 1)]
        let segments = HistoryRendering.binarySegments(transitions, width: 100, since: since, now: now)

        XCTAssertEqual(segments.count, 2)
        XCTAssertFalse(segments[0].on)                       // inferred closed lead-in
        XCTAssertEqual(segments[0].width, 80, accuracy: 0.001)
        XCTAssertTrue(segments[1].on)                        // the open period to now
        XCTAssertEqual(segments[1].width, 20, accuracy: 0.001)
    }

    func testStatsReturnsMinNowMax() {
        let samples = [
            NumericSample(t: Date(timeIntervalSince1970: 0), v: 18),
            NumericSample(t: Date(timeIntervalSince1970: 50), v: 23),
            NumericSample(t: Date(timeIntervalSince1970: 100), v: 21),
        ]
        let stats = HistoryRendering.stats(samples)
        XCTAssertEqual(stats?.min, 18)
        XCTAssertEqual(stats?.max, 23)
        XCTAssertEqual(stats?.now, 21)   // last sample
        XCTAssertNil(HistoryRendering.stats([]))
    }

    func testSparklineViewAcceptsNumericAndBinarySeriesWithoutCrash() {
        let frame = CGRect(x: 0, y: 0, width: 48, height: 16)

        var numeric = SensorSeries(characteristicId: UUID(), kind: .numeric)
        numeric.numeric = [NumericSample(t: Date(timeIntervalSince1970: 0), v: 20)]
        let v1 = SparklineView(frame: frame)
        v1.update(series: numeric, kind: .numeric, now: Date(timeIntervalSince1970: 10))

        var binary = SensorSeries(characteristicId: UUID(), kind: .binary)
        binary.binary = [BinaryTransition(t: Date(timeIntervalSince1970: 0), s: 1)]
        let v2 = SparklineView(frame: frame)
        v2.update(series: binary, kind: .binary, now: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(v1.frame.width, 48)
        XCTAssertEqual(v2.frame.width, 48)
    }
}
