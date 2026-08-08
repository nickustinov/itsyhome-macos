//
//  HueMath.swift
//  macOSBridge
//
//  Circular (angular) mean for averaging group-light hue values.
//

import Foundation

enum HueMath {

    /// Circular (angular) mean of hue values given in degrees.
    ///
    /// Hue lives on a wheel, so an arithmetic mean is wrong at the 0°/360°
    /// boundary — 350° and 10° are both near red but average to 180° (cyan).
    /// Converting each hue to a unit vector, averaging the vectors, and
    /// recovering the angle with `atan2` yields the perceptually correct
    /// ~0° (red). Result is normalized to [0, 360). When the vectors cancel
    /// out (e.g. evenly spaced 0°/120°/240°) the direction is undefined; the
    /// result stays finite and in range rather than becoming NaN.
    static func circularMean(of hues: [Double]) -> Double {
        guard !hues.isEmpty else { return 0 }
        var sumSin: Double = 0
        var sumCos: Double = 0
        for hue in hues {
            let radians = hue * .pi / 180
            sumSin += sin(radians)
            sumCos += cos(radians)
        }
        let count = Double(hues.count)
        let meanDegrees = atan2(sumSin / count, sumCos / count) * 180 / .pi
        // atan2 returns [-180, 180]; normalize to [0, 360).
        return meanDegrees < 0 ? meanDegrees + 360 : meanDegrees
    }
}
