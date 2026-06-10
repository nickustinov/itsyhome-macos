//
//  HistorySample.swift
//  macOSBridge
//
//  Value types for sensor history series.
//

import Foundation

/// Numeric kinds (temperature, humidity) store measured samples; binary kinds
/// (contact, motion, ...) store only state transitions.
enum SeriesKind: String, Codable {
    case numeric
    case binary
}

/// One temperature/humidity reading at a point in time.
struct NumericSample: Codable, Equatable {
    let t: Date
    let v: Double
}

/// One binary state transition (s == 0 or 1) at a point in time.
struct BinaryTransition: Codable, Equatable {
    let t: Date
    let s: Int
}

/// A per-characteristic time series. Exactly one of `numeric`/`binary` is used,
/// determined by `kind`.
struct SensorSeries: Codable, Equatable {
    let characteristicId: UUID
    let kind: SeriesKind
    var numeric: [NumericSample]
    var binary: [BinaryTransition]

    init(characteristicId: UUID, kind: SeriesKind) {
        self.characteristicId = characteristicId
        self.kind = kind
        self.numeric = []
        self.binary = []
    }
}

/// What the capture layer needs to know about a tracked characteristic.
struct SensorMeta: Equatable {
    let seriesKind: SeriesKind
    let name: String
}

extension SensorKind {
    /// Temperature/humidity are numeric lines; all other kinds are binary timelines.
    var seriesKind: SeriesKind {
        isNumeric ? .numeric : .binary
    }
}
