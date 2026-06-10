//
//  HistoryStorage.swift
//  macOSBridge
//
//  Persistence backend for sensor history. The protocol seam lets a future
//  iCloud-file backend drop in without touching capture or rendering.
//

import Foundation

protocol HistoryStorage {
    func load(homeId: String) -> HistoryArchive
    func save(_ archive: HistoryArchive, homeId: String)
}

/// Stores one JSON file per home under Application Support.
final class FileHistoryStorage: HistoryStorage {

    /// On-disk shape. Series are stored as an array (UUID-keyed dictionaries
    /// encode as flat pair arrays in JSON, which is harder to inspect).
    private struct HistoryFile: Codable {
        var sessions: [CaptureSession]
        var series: [SensorSeries]
    }

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

    func load(homeId: String) -> HistoryArchive {
        guard let data = try? Data(contentsOf: fileURL(homeId: homeId)) else { return HistoryArchive() }
        if let decoded = try? JSONDecoder().decode(HistoryFile.self, from: data) {
            return HistoryArchive(
                sessions: decoded.sessions,
                series: Dictionary(uniqueKeysWithValues: decoded.series.map { ($0.characteristicId, $0) }))
        }
        // Legacy format (pre-sessions): a bare [SensorSeries] array.
        if let decoded = try? JSONDecoder().decode([SensorSeries].self, from: data) {
            return HistoryArchive(
                series: Dictionary(uniqueKeysWithValues: decoded.map { ($0.characteristicId, $0) }))
        }
        return HistoryArchive()
    }

    func save(_ archive: HistoryArchive, homeId: String) {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let file = HistoryFile(sessions: archive.sessions, series: Array(archive.series.values))
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL(homeId: homeId), options: .atomic)
    }
}

/// In-memory backend for tests.
final class InMemoryHistoryStorage: HistoryStorage {
    private var stores: [String: HistoryArchive] = [:]

    func load(homeId: String) -> HistoryArchive {
        stores[homeId] ?? HistoryArchive()
    }

    func save(_ archive: HistoryArchive, homeId: String) {
        stores[homeId] = archive
    }
}
