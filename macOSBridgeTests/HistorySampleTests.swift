//
//  HistorySampleTests.swift
//  macOSBridgeTests
//

import XCTest
@testable import macOSBridge

final class HistorySampleTests: XCTestCase {

    func testSensorKindMapsToSeriesKind() {
        XCTAssertEqual(SensorKind.temperature.seriesKind, .numeric)
        XCTAssertEqual(SensorKind.humidity.seriesKind, .numeric)
        for binary in [SensorKind.contact, .motion, .occupancy, .leak, .smoke, .carbonMonoxide, .carbonDioxide] {
            XCTAssertEqual(binary.seriesKind, .binary, "\(binary) should be binary")
        }
    }

    func testSensorSeriesJSONRoundTrip() throws {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        var series = SensorSeries(characteristicId: UUID(), kind: .numeric)
        series.numeric = [NumericSample(t: t, v: 21.4)]
        let data = try JSONEncoder().encode(series)
        let decoded = try JSONDecoder().decode(SensorSeries.self, from: data)
        XCTAssertEqual(decoded, series)
    }
}
