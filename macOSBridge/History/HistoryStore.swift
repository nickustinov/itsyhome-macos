//
//  HistoryStore.swift
//  macOSBridge
//
//  Captures sensor history opportunistically off the characteristic chokepoint
//  and persists it per home. Pro-gated; see ProManager.
//

import Foundation

final class HistoryStore {

    static let shared = HistoryStore()

    static let didChangeNotification = Notification.Name("HistoryStoreDidChange")

    // Tunables (see spec).
    private let retention: TimeInterval = 30 * 24 * 60 * 60
    private let dedupInterval: TimeInterval = 60
    private let numericCap = 20_000
    private let binaryCap = 5_000

    private let storage: HistoryStorage
    private let now: () -> Date
    private let isEnabled: () -> Bool

    private var homeId = "default"
    private var registry: [UUID: SensorMeta] = [:]
    private var series: [UUID: SensorSeries] = [:]

    init(storage: HistoryStorage = FileHistoryStorage(),
         now: @escaping () -> Date = { Date() },
         isEnabled: @escaping () -> Bool = { ProStatusCache.shared.isPro && PreferencesManager.shared.historyEnabled }) {
        self.storage = storage
        self.now = now
        self.isEnabled = isEnabled
    }

    /// Called from rebuildMenu: sets the active home + characteristic registry and
    /// loads that home's persisted series.
    func configure(homeId: String, registry: [UUID: SensorMeta]) {
        // Cancel any in-flight debounced save so it cannot write the previous
        // home's series to the new home's file after we swap state below.
        flushWorkItem?.cancel()
        self.homeId = homeId
        self.registry = registry
        self.series = storage.load(homeId: homeId)
    }

    func series(for id: UUID) -> SensorSeries? {
        series[id]
    }

    /// Capture entry point. No-op when disabled or the id is not a tracked sensor.
    func record(id: UUID, value: Any) {
        guard isEnabled(), let meta = registry[id] else { return }
        let timestamp = now()
        switch meta.seriesKind {
        case .numeric:
            guard let v = ValueConversion.toDouble(value) else { return }
            recordNumeric(id: id, v: v, at: timestamp)
        case .binary:
            guard let s = ValueConversion.toInt(value) else { return }
            recordBinary(id: id, s: s, at: timestamp)
        }
    }

    private func recordNumeric(id: UUID, v: Double, at timestamp: Date) {
        var s = series[id] ?? SensorSeries(characteristicId: id, kind: .numeric)
        if let last = s.numeric.last,
           last.v == v,
           timestamp.timeIntervalSince(last.t) < dedupInterval {
            return
        }
        s.numeric.append(NumericSample(t: timestamp, v: v))
        trimNumeric(&s, now: timestamp)
        series[id] = s
        markChanged()
    }

    private func recordBinary(id: UUID, s state: Int, at timestamp: Date) {
        var s = series[id] ?? SensorSeries(characteristicId: id, kind: .binary)
        if let last = s.binary.last, last.s == state { return }
        s.binary.append(BinaryTransition(t: timestamp, s: state))
        trimBinary(&s, now: timestamp)
        series[id] = s
        markChanged()
    }

    private func trimNumeric(_ s: inout SensorSeries, now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        s.numeric.removeAll { $0.t < cutoff }
        if s.numeric.count > numericCap {
            s.numeric.removeFirst(s.numeric.count - numericCap)
        }
    }

    private func trimBinary(_ s: inout SensorSeries, now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        s.binary.removeAll { $0.t < cutoff }
        if s.binary.count > binaryCap {
            s.binary.removeFirst(s.binary.count - binaryCap)
        }
    }

    func clearAll() {
        flushWorkItem?.cancel()
        series = [:]
        storage.save(series, homeId: homeId)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    // MARK: - Debounced persistence

    private var flushWorkItem: DispatchWorkItem?

    private func markChanged() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        scheduleFlush()
    }

    private func scheduleFlush() {
        flushWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        flushWorkItem = work
        // 2s debounce: chatty bridges produce one write, not one-per-sample.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// Writes the current series to storage immediately. Exposed for tests and
    /// for app-termination flushes.
    func flush() {
        storage.save(series, homeId: homeId)
    }
}
