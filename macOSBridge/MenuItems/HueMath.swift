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

    /// Shortest on-wheel distance between two hue values given in degrees,
    /// in [0, 180]. Hue wraps at the 0°/360° boundary, so the plain absolute
    /// difference is wrong there: 359° and 1° are 2° apart on the wheel, not
    /// 358°. Used wherever two hue values must be compared (e.g. deciding
    /// whether a colour scene is active), mirroring `circularMean`'s
    /// angular treatment.
    static func shortestDistance(_ a: Double, _ b: Double) -> Double {
        let raw = abs(a - b).truncatingRemainder(dividingBy: 360)
        return raw > 180 ? 360 - raw : raw
    }
}
