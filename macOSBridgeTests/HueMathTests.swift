//
//  HueMathTests.swift
//  macOSBridgeTests
//
//  Regression tests for the circular (angular) mean used to average group-light
//  hue. Hue is an angle on a wheel, so an arithmetic mean is wrong at the
//  0°/360° boundary: lights at 350° and 10° are both near red, yet their
//  arithmetic mean is 180° (cyan). The circular mean recovers ~0° (red).
//
//  Because hue is circular, 0° and 360° name the same point. Floating-point
//  noise at that boundary can yield either ~0° or ~359.9999°, so hue results
//  are compared by the shortest angular distance around the wheel, not by
//  direct equality.
//

import XCTest
@testable import macOSBridge

final class HueMathTests: XCTestCase {

    /// Shortest angular distance between two hues, in [0, 180].
    private func circularDistance(_ a: Double, _ b: Double) -> Double {
        let raw = abs(a - b).truncatingRemainder(dividingBy: 360)
        return raw > 180 ? 360 - raw : raw
    }

    // MARK: - Wraparound across the 0°/360° boundary (the bug)

    func testCircularMeanAcrossZeroBoundaryIsRedNotCyan() {
        // Arithmetic mean of 350 and 10 is 180° (cyan) — the failure this fixes.
        let arithmetic = [350.0, 10.0].reduce(0, +) / 2
        XCTAssertEqual(arithmetic, 180, accuracy: 0.001)

        // Circular mean lands at ~0° (red), the perceptually correct average.
        let mean = HueMath.circularMean(of: [350, 10])
        XCTAssertLessThanOrEqual(circularDistance(mean, 0), 1.0,
                                 "expected ~0° (red), got \(mean)°")
    }

    func testCircularMeanOf359And1IsNearZero() {
        let mean = HueMath.circularMean(of: [359, 1])
        XCTAssertLessThanOrEqual(circularDistance(mean, 0), 1.0,
                                 "expected ~0° (red), got \(mean)°")
    }

    func testCircularMeanOfThreeValueWraparoundCluster() {
        // A group usually holds more than two bulbs — exercise the multi-element
        // path across the 0°/360° seam. Cluster is symmetric around red → ~0°.
        let mean = HueMath.circularMean(of: [350, 0, 10])
        XCTAssertLessThanOrEqual(circularDistance(mean, 0), 1.0,
                                 "expected ~0° (red), got \(mean)°")
    }

    // MARK: - Non-wraparound clusters match the arithmetic mean (no regression)

    func testNonWrappingClusterMatchesArithmetic() {
        let hues = [10.0, 20.0, 30.0]
        let arithmetic = hues.reduce(0, +) / Double(hues.count)
        let mean = HueMath.circularMean(of: hues)
        XCTAssertLessThanOrEqual(circularDistance(mean, arithmetic), 0.5,
                                 "expected ~\(arithmetic)°, got \(mean)°")
    }

    func testTwoCloseHuesAverageToMidpoint() {
        // 40° and 60° average to 50° under both means.
        let mean = HueMath.circularMean(of: [40, 60])
        XCTAssertLessThanOrEqual(circularDistance(mean, 50), 1.0,
                                 "expected ~50°, got \(mean)°")
    }

    // MARK: - Edge cases

    func testEmptyReturnsZero() {
        XCTAssertEqual(HueMath.circularMean(of: []), 0, accuracy: 0.001)
    }

    func testSingleValueReturnsItself() {
        XCTAssertEqual(HueMath.circularMean(of: [137]), 137, accuracy: 0.001)
    }

    func testEvenlySpacedHuesAreFiniteInRange() {
        // 0°/120°/240° cancel out (mean vector ~origin); the result is undefined
        // in direction but must be finite and within [0, 360).
        let mean = HueMath.circularMean(of: [0, 120, 240])
        XCTAssertTrue(mean.isFinite)
        XCTAssertGreaterThanOrEqual(mean, 0)
        XCTAssertLessThan(mean, 360)
    }

    // MARK: - shortestDistance (hue comparison across the 0°/360° boundary)

    func testShortestDistanceAcrossZeroBoundary() {
        // 359° and 1° are 2° apart on the wheel, not 358°.
        XCTAssertEqual(HueMath.shortestDistance(359, 1), 2, accuracy: 0.001)
        XCTAssertEqual(HueMath.shortestDistance(1, 359), 2, accuracy: 0.001)
    }

    func testShortestDistanceWithinRangeMatchesAbsoluteDifference() {
        XCTAssertEqual(HueMath.shortestDistance(40, 60), 20, accuracy: 0.001)
        XCTAssertEqual(HueMath.shortestDistance(180, 0), 180, accuracy: 0.001)
    }

    func testShortestDistanceIsBoundedBy180() {
        // The result is the shorter way around the wheel.
        XCTAssertLessThanOrEqual(HueMath.shortestDistance(0, 359), 1.0)
        XCTAssertLessThanOrEqual(HueMath.shortestDistance(90, 270), 180.0)
    }
}
