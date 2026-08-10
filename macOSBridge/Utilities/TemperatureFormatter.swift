//
//  TemperatureFormatter.swift
//  macOSBridge
//
//  Utility for formatting temperatures respecting user's locale settings
//  HomeKit always returns temperatures in Celsius
//

import Foundation

enum TemperatureFormatter {

    /// Whether temperatures should display in Fahrenheit
    static var usesFahrenheit: Bool {
        switch PreferencesManager.shared.temperatureUnit {
        case "celsius":
            return false
        case "fahrenheit":
            return true
        default:
            let formatter = MeasurementFormatter()
            formatter.locale = Locale.current
            let temp = Measurement(value: 0, unit: UnitTemperature.celsius)
            let formatted = formatter.string(from: temp)
            return formatted.contains("°F")
        }
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

    /// Format a setpoint value (in Celsius from HomeKit) for display,
    /// keeping half degrees visible in Celsius mode: a 21.5 setpoint must
    /// read "21.5°", not "22°". Fahrenheit mode delegates to format's
    /// whole-degree ceil, unchanged.
    static func formatSetpoint(_ celsius: Double) -> String {
        guard !usesFahrenheit else { return format(celsius) }
        let nearestWhole = celsius.rounded()
        if abs(celsius - nearestWhole) < 0.05 {
            // Within 0.05 of a whole number counts as whole (e.g. "21°")
            return "\(Int(nearestWhole))°"
        }
        return String(format: "%.1f°", celsius)
    }

    /// Convert Celsius to Fahrenheit
    static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9.0 / 5.0 + 32.0
    }

    /// Convert Fahrenheit to Celsius
    static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        (fahrenheit - 32.0) * 5.0 / 9.0
    }

    /// UI stepping increment derived from a characteristic's metadata step.
    /// nil or non-positive metadata falls back to whole degrees; anything
    /// else rounds UP to the nearest 0.5 °C with a floor of 0.5 °C, because
    /// HomeKit's spec default step of 0.1 °C is unusable one click at a time.
    static func uiStep(_ metadataStep: Double?) -> Double {
        guard let metadataStep = metadataStep, metadataStep > 0 else { return 1.0 }
        // The epsilon keeps 0.5 from becoming 1.0 through float noise
        return max(0.5, ceil(metadataStep / 0.5 - 1e-9) * 0.5)
    }

    /// One user-facing degree step from a Celsius value, in the current
    /// display unit. In Fahrenheit mode the step moves the displayed °F
    /// integer by exactly one degree – stepping the Celsius value directly
    /// moves 1.8 °F and skips displayed degrees (72 → 70) – and the Celsius
    /// step grid is ignored. In Celsius mode the value snaps to the next
    /// line of the step grid, so an off-grid 21.3 steps to 21.5 or 21.0.
    static func step(_ celsius: Double, by direction: Double, step: Double = 1.0) -> Double {
        guard usesFahrenheit else {
            // Epsilons keep on-grid values (and float noise around them)
            // from double-stepping or standing still.
            let next = direction > 0
                ? (floor(celsius / step + 1e-9) + 1) * step
                : (ceil(celsius / step - 1e-9) - 1) * step
            // Round the result onto the grid to kill float noise
            return (next / step).rounded() * step
        }
        // Mirror format(decimals: 0)'s ceil so the result lands exactly one
        // displayed degree away from what the label currently shows.
        let displayed = ceil(celsiusToFahrenheit(celsius))
        return fahrenheitToCelsius(displayed + direction)
    }
}
