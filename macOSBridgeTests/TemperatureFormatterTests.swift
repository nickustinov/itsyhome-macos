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

    // MARK: - UI step derivation from characteristic metadata

    func testUIStepDefaultsToWholeDegreeWithoutMetadata() {
        XCTAssertEqual(TemperatureFormatter.uiStep(nil), 1.0)
        XCTAssertEqual(TemperatureFormatter.uiStep(0), 1.0)
        XCTAssertEqual(TemperatureFormatter.uiStep(-1), 1.0)
    }

    func testUIStepRoundsUpToNearestHalfDegree() {
        // HomeKit's spec default step is 0.1°C; clicking in 0.1° increments
        // is unusable, so anything below 0.5 floors to 0.5
        XCTAssertEqual(TemperatureFormatter.uiStep(0.1), 0.5)
        XCTAssertEqual(TemperatureFormatter.uiStep(0.5), 0.5)
        XCTAssertEqual(TemperatureFormatter.uiStep(0.6), 1.0)
        XCTAssertEqual(TemperatureFormatter.uiStep(1.0), 1.0)
        XCTAssertEqual(TemperatureFormatter.uiStep(2.0), 2.0)
    }

    // MARK: - Stepping in Celsius on a half-degree grid

    func testCelsiusHalfDegreeStepFromOnGridValue() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        XCTAssertEqual(TemperatureFormatter.step(21.0, by: 1, step: 0.5), 21.5)
        XCTAssertEqual(TemperatureFormatter.step(21.0, by: -1, step: 0.5), 20.5)
    }

    func testCelsiusHalfDegreeStepSnapsOffGridValueToGrid() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        // An off-grid 21.3°C lands on the next grid line, not 21.8/20.8
        XCTAssertEqual(TemperatureFormatter.step(21.3, by: 1, step: 0.5), 21.5)
        XCTAssertEqual(TemperatureFormatter.step(21.3, by: -1, step: 0.5), 21.0)
    }

    func testCelsiusHalfDegreeStepAbsorbsFloatNoise() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        // Float noise just under 21.0°C must step as if it were on grid
        XCTAssertEqual(TemperatureFormatter.step(20.9999999999, by: 1, step: 0.5), 21.5)
    }

    func testCelsiusDefaultStepStaysOneDegree() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        // Explicit step 1.0 matches testCelsiusStepIsOneDegree's semantics
        XCTAssertEqual(TemperatureFormatter.step(22.0, by: -1, step: 1.0), 21.0)
        XCTAssertEqual(TemperatureFormatter.step(22.0, by: 1, step: 1.0), 23.0)
    }

    // MARK: - Stepping in Fahrenheit ignores the Celsius step grid

    func testFahrenheitStepWithHalfDegreeGridStillMovesOneDisplayedDegree() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        // Mirrors testFahrenheitStepDownHitsEveryDegree with a 0.5°C device
        // grid present; Fahrenheit stepping stays one displayed degree
        var celsius = 22.0
        XCTAssertEqual(TemperatureFormatter.format(celsius), "72°")

        celsius = TemperatureFormatter.step(celsius, by: -1, step: 0.5)
        XCTAssertEqual(TemperatureFormatter.format(celsius), "71°")

        celsius = TemperatureFormatter.step(celsius, by: -1, step: 0.5)
        XCTAssertEqual(TemperatureFormatter.format(celsius), "70°")
    }

    // MARK: - Setpoint display keeps half degrees visible in Celsius

    func testFormatSetpointCelsiusWholeAndHalfDegrees() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        XCTAssertEqual(TemperatureFormatter.formatSetpoint(21.0), "21°")
        XCTAssertEqual(TemperatureFormatter.formatSetpoint(21.5), "21.5°")
        // Values within 0.05 of a whole number render without decimals
        XCTAssertEqual(TemperatureFormatter.formatSetpoint(20.999999999), "21°")
    }

    func testFormatSetpointCelsiusNegativeHalfDegree() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        XCTAssertEqual(TemperatureFormatter.formatSetpoint(-0.5), "-0.5°")
    }

    func testFormatSetpointFahrenheitDelegatesToWholeDegreeCeil() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        // 21.5°C is 70.7°F; Fahrenheit setpoints keep format's ceil
        XCTAssertEqual(TemperatureFormatter.formatSetpoint(21.5), TemperatureFormatter.format(21.5))
        XCTAssertEqual(TemperatureFormatter.formatSetpoint(21.5), "71°")
    }
}
