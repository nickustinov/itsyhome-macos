//
//  TemperatureFormatterTests.swift
//  macOSBridgeTests
//
//  Tests for temperature display and unit-aware stepping
//

import XCTest
@testable import macOSBridge

final class TemperatureFormatterTests: XCTestCase {

    private var savedUnit: String!

    override func setUp() {
        super.setUp()
        savedUnit = PreferencesManager.shared.temperatureUnit
    }

    override func tearDown() {
        PreferencesManager.shared.temperatureUnit = savedUnit
        super.tearDown()
    }

    // MARK: - Stepping in Fahrenheit (issue #137: 72 skipped to 70)

    func testFahrenheitStepDownHitsEveryDegree() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        // Nest at 72°F reports 22.0°C; stepping down must display 71, not 70
        var celsius = 22.0
        XCTAssertEqual(TemperatureFormatter.format(celsius), "72°")

        celsius = TemperatureFormatter.step(celsius, by: -1)
        XCTAssertEqual(TemperatureFormatter.format(celsius), "71°")

        celsius = TemperatureFormatter.step(celsius, by: -1)
        XCTAssertEqual(TemperatureFormatter.format(celsius), "70°")
    }

    func testFahrenheitStepUpHitsEveryDegree() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        var celsius = 21.0 // displays 70°F
        XCTAssertEqual(TemperatureFormatter.format(celsius), "70°")

        celsius = TemperatureFormatter.step(celsius, by: 1)
        XCTAssertEqual(TemperatureFormatter.format(celsius), "71°")

        celsius = TemperatureFormatter.step(celsius, by: 1)
        XCTAssertEqual(TemperatureFormatter.format(celsius), "72°")
    }

    func testFahrenheitStepFromHalfDegreeCelsius() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        // Devices snapping to 0.5°C grids must still step one displayed degree
        let celsius = 21.5 // 70.7°F, displays 71°
        XCTAssertEqual(TemperatureFormatter.format(celsius), "71°")

        let down = TemperatureFormatter.step(celsius, by: -1)
        XCTAssertEqual(TemperatureFormatter.format(down), "70°")

        let up = TemperatureFormatter.step(celsius, by: 1)
        XCTAssertEqual(TemperatureFormatter.format(up), "72°")
    }

    // MARK: - Stepping in Celsius (unchanged behaviour)

    func testCelsiusStepIsOneDegree() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        XCTAssertEqual(TemperatureFormatter.step(22.0, by: -1), 21.0)
        XCTAssertEqual(TemperatureFormatter.step(22.0, by: 1), 23.0)
    }

    // MARK: - Conversion round trip

    func testConversionRoundTrip() {
        let celsius = 21.11
        let roundTripped = TemperatureFormatter.fahrenheitToCelsius(TemperatureFormatter.celsiusToFahrenheit(celsius))
        XCTAssertEqual(roundTripped, celsius, accuracy: 0.0001)
    }
}
