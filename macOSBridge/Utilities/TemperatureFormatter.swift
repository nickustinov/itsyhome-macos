//
//  TemperatureFormatter.swift
//  macOSBridge
//
//  Utility for formatting temperatures respecting user's locale settings
//  HomeKit always returns temperatures in Celsius
//

import Foundation

enum TemperatureFormatter {

    /// Whether the user's locale uses Fahrenheit
    static var usesFahrenheit: Bool {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale.current
        let temp = Measurement(value: 0, unit: UnitTemperature.celsius)
        let formatted = formatter.string(from: temp)
        return formatted.contains("°F")
    }

    /// Format a temperature value (in Celsius from HomeKit) for display
    /// - Parameters:
    ///   - celsius: Temperature in Celsius
    ///   - decimals: Number of decimal places (default 0)
    /// - Returns: Formatted string with degree symbol (e.g., "72°" or "22°")
    static func format(_ celsius: Double, decimals: Int = 0) -> String {
        let displayTemp = usesFahrenheit ? celsiusToFahrenheit(celsius) : celsius
        if decimals == 0 {
            // Use ceiling to avoid 19.5 and 20.5 both showing as 20
            return "\(Int(ceil(displayTemp)))°"
        }
        let format = "%.\(decimals)f°"
        return String(format: format, displayTemp)
    }

    /// Format an optional temperature, returning "--°" if nil
    static func format(_ celsius: Double?, decimals: Int = 0) -> String {
        guard let celsius = celsius else { return "--°" }
        return format(celsius, decimals: decimals)
    }

    /// Convert Celsius to Fahrenheit
    static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9.0 / 5.0 + 32.0
    }

    /// Convert Fahrenheit to Celsius
    static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        (fahrenheit - 32.0) * 5.0 / 9.0
    }
}
