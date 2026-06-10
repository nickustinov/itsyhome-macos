//
//  HistoryStorage.swift
//  macOSBridge
//
//  Persistence backend for sensor history. The protocol seam lets a future
//  iCloud-file backend drop in without touching capture or rendering.
//

import Foundation

protocol HistoryStorage {
    func load(homeId: String) -> [UUID: SensorSeries]
    func save(_ series: [UUID: SensorSeries], homeId: String)
}

/// Stores one JSON file per home under Application Support.
final class FileHistoryStorage: HistoryStorage {

    private let baseDirectory: URL
    private let fileManager = FileManager.default

    init(baseDirectory: URL = FileHistoryStorage.defaultDirectory()) {
        self.baseDirectory = baseDirectory
    }

    static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("Itsyhome", isDirectory: true)
            .appendingPathComponent("history", isDirectory: true)
    }

    private func fileURL(homeId: String) -> URL {
        // Home ids are UUID strings; still sanitise to a safe filename.
        let safe = homeId.replacingOccurrences(of: "/", with: "_")
        return baseDirectory.appendingPathComponent("\(safe).json")
    }

    func load(homeId: String) -> [UUID: SensorSeries] {
        guard let data = try? Data(contentsOf: fileURL(homeId: homeId)),
              let decoded = try? JSONDecoder().decode([SensorSeries].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.characteristicId, $0) })
    }

    func save(_ series: [UUID: SensorSeries], homeId: String) {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(Array(series.values)) else { return }
        try? data.write(to: fileURL(homeId: homeId), options: .atomic)
    }
}

/// In-memory backend for tests.
final class InMemoryHistoryStorage: HistoryStorage {
    private var stores: [String: [UUID: SensorSeries]] = [:]

    func load(homeId: String) -> [UUID: SensorSeries] {
        stores[homeId] ?? [:]
    }

    func save(_ series: [UUID: SensorSeries], homeId: String) {
        stores[homeId] = series
    }
}
