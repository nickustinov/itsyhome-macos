//
//  ValueConversion.swift
//  macOSBridge
//
//  Utilities for converting HomeKit characteristic values between types
//

import Foundation

/// Utility for converting HomeKit characteristic values between types.
/// HomeKit values can come as Int, Double, Float, Bool, or NSNumber depending on
/// the characteristic type and how it was serialised.
enum ValueConversion {

    /// Converts any numeric value to Double, returning nil for non-numeric types.
    static func toDouble(_ value: Any) -> Double? {
        switch value {
        case let d as Double:
            return d
        case let i as Int:
            return Double(i)
        case let f as Float:
            return Double(f)
        case let b as Bool:
            return b ? 1.0 : 0.0
        case let n as NSNumber:
            return n.doubleValue
        default:
            return nil
        }
    }

    /// Converts any numeric value to Double, returning a default for non-numeric types.
    static func toDouble(_ value: Any, default defaultValue: Double) -> Double {
        toDouble(value) ?? defaultValue
    }

    /// Converts any numeric value to Int, returning nil for non-numeric types.
    static func toInt(_ value: Any) -> Int? {
        switch value {
        case let i as Int:
            return i
        case let d as Double:
            return Int(d)
        case let f as Float:
            return Int(f)
        case let b as Bool:
            return b ? 1 : 0
        case let n as NSNumber:
            return n.intValue
        default:
            return nil
        }
    }

    /// Converts any numeric value to Int, returning a default for non-numeric types.
    static func toInt(_ value: Any, default defaultValue: Int) -> Int {
        toInt(value) ?? defaultValue
    }

    /// Converts a value to Bool, returning nil for non-boolean/non-integer types.
    /// For integers: 0 = false, non-zero = true.
    static func toBool(_ value: Any) -> Bool? {
        switch value {
        case let b as Bool:
            return b
        case let i as Int:
            return i != 0
        default:
            return nil
        }
    }

    /// Converts a value to Bool, returning a default for invalid types.
    static func toBool(_ value: Any, default defaultValue: Bool) -> Bool {
        toBool(value) ?? defaultValue
    }
}
