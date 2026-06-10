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

/// A continuous interval during which capture was running. Chart regions not
/// covered by any session render as gaps, so "the app wasn't recording" is
/// distinguishable from "the value held steady" (capture is change-driven, so
/// sample silence alone cannot tell the two apart).
struct CaptureSession: Codable, Equatable {
    var start: Date
    var end: Date
}

/// Everything persisted for one home: capture coverage plus per-sensor series.
struct HistoryArchive: Equatable {
    var sessions: [CaptureSession] = []
    var series: [UUID: SensorSeries] = [:]
    var isEmpty: Bool { sessions.isEmpty && series.isEmpty }
}

extension SensorKind {
    /// Temperature/humidity are numeric lines; all other kinds are binary timelines.
    var seriesKind: SeriesKind {
        isNumeric ? .numeric : .binary
    }
}
