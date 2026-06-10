//
//  HistoryStoreTests.swift
//  macOSBridgeTests
//

import XCTest
@testable import macOSBridge

final class HistoryStoreTests: XCTestCase {

    func testFileStorageRoundTripsPerHome() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("history-test-\(UUID().uuidString)")
        let storage = FileHistoryStorage(baseDirectory: tmp)

        let id = UUID()
        var series = SensorSeries(characteristicId: id, kind: .numeric)
        series.numeric = [NumericSample(t: Date(timeIntervalSince1970: 1), v: 9.0)]

        storage.save(HistoryArchive(series: [id: series]), homeId: "home-A")
        // A different home must not see home-A's data.
        XCTAssertTrue(storage.load(homeId: "home-B").isEmpty)
        XCTAssertEqual(storage.load(homeId: "home-A").series[id], series)

        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Task 3: record + dedup

    // A store wired to in-memory storage, a controllable clock, and always-enabled.
    private func makeStore(now: @escaping () -> Date) -> HistoryStore {
        let store = HistoryStore(storage: InMemoryHistoryStorage(), now: now, isEnabled: { true })
        return store
    }

    func testNumericDedupSkipsUnchangedWithinInterval() {
        var clock = Date(timeIntervalSince1970: 1000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])

        store.record(id: id, value: 21.0)
        clock = clock.addingTimeInterval(10)   // < 60s, same value
        store.record(id: id, value: 21.0)

        XCTAssertEqual(store.series(for: id)?.numeric.count, 1)
    }

    func testNumericRecordsOnChangeOrAfterInterval() {
        var clock = Date(timeIntervalSince1970: 1000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])

        store.record(id: id, value: 21.0)
        clock = clock.addingTimeInterval(10)
        store.record(id: id, value: 22.0)        // changed -> records
        clock = clock.addingTimeInterval(120)
        store.record(id: id, value: 22.0)        // unchanged but > 60s -> records

        XCTAssertEqual(store.series(for: id)?.numeric.count, 3)
    }

    func testBinaryRecordsOnlyTransitions() {
        var clock = Date(timeIntervalSince1970: 1000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .binary, name: "Door")])

        store.record(id: id, value: 1)   // open
        clock = clock.addingTimeInterval(5)
        store.record(id: id, value: 1)   // still open -> skip
        clock = clock.addingTimeInterval(5)
        store.record(id: id, value: 0)   // closed -> records

        XCTAssertEqual(store.series(for: id)?.binary.map(\.s), [1, 0])
    }

    func testUnregisteredIdIsIgnored() {
        let store = makeStore(now: { Date() })
        store.configure(homeId: "h", registry: [:])
        store.record(id: UUID(), value: 21.0)
        // No registry entry -> nothing recorded, no crash.
        XCTAssertNil(store.series(for: UUID()))
    }

    func testDisabledStoreDoesNotRecord() {
        let store = HistoryStore(storage: InMemoryHistoryStorage(), now: { Date() }, isEnabled: { false })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])
        store.record(id: id, value: 21.0)
        XCTAssertNil(store.series(for: id))
    }

    // MARK: - Task 4: retention, caps, clearAll, debounced persistence

    func testRetentionDropsSamplesOlderThan30Days() {
        var clock = Date(timeIntervalSince1970: 2_000_000_000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])

        store.record(id: id, value: 10.0)                       // t0
        clock = clock.addingTimeInterval(31 * 24 * 60 * 60)     // +31 days
        store.record(id: id, value: 11.0)                       // triggers trim of t0

        let samples = store.series(for: id)?.numeric ?? []
        XCTAssertEqual(samples.map(\.v), [11.0])
    }

    func testClearAllEmptiesAndPersists() {
        let storage = InMemoryHistoryStorage()
        let store = HistoryStore(storage: storage, now: { Date(timeIntervalSince1970: 1) }, isEnabled: { true })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])
        store.record(id: id, value: 10.0)
        XCTAssertNotNil(store.series(for: id))

        store.clearAll()

        XCTAssertNil(store.series(for: id))
        XCTAssertTrue(storage.load(homeId: "h").isEmpty)
    }

    // MARK: - Capture coverage sessions

    func testRecordOpensAndExtendsSession() {
        var clock = Date(timeIntervalSince1970: 1000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])

        store.record(id: id, value: 21.0)
        clock = clock.addingTimeInterval(120)            // within tolerance
        store.record(id: id, value: 22.0)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.start, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(store.sessions.first?.end, Date(timeIntervalSince1970: 1120))
    }

    func testRecordAfterLongGapStartsNewSession() {
        var clock = Date(timeIntervalSince1970: 1000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])

        store.record(id: id, value: 21.0)
        clock = clock.addingTimeInterval(60 * 60)        // 1h silence > tolerance
        store.record(id: id, value: 22.0)

        XCTAssertEqual(store.sessions.count, 2)
    }

    func testDedupedRecordStillExtendsSession() {
        var clock = Date(timeIntervalSince1970: 1000)
        let store = makeStore(now: { clock })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])

        store.record(id: id, value: 21.0)
        clock = clock.addingTimeInterval(10)
        store.record(id: id, value: 21.0)                // deduped sample...

        XCTAssertEqual(store.series(for: id)?.numeric.count, 1)
        XCTAssertEqual(store.sessions.first?.end, Date(timeIntervalSince1970: 1010))  // ...but coverage extends
    }

    func testSessionsPersistAndReload() {
        let storage = InMemoryHistoryStorage()
        let id = UUID()
        let meta = SensorMeta(seriesKind: .numeric, name: "Temp")
        let store1 = HistoryStore(storage: storage, now: { Date(timeIntervalSince1970: 5) }, isEnabled: { true })
        store1.configure(homeId: "h", registry: [id: meta])
        store1.record(id: id, value: 21.0)
        store1.flush()

        let store2 = HistoryStore(storage: storage, now: { Date(timeIntervalSince1970: 6) }, isEnabled: { true })
        store2.configure(homeId: "h", registry: [id: meta])
        XCTAssertEqual(store2.sessions.count, 1)
    }

    func testClearAllClearsSessions() {
        let store = makeStore(now: { Date(timeIntervalSince1970: 1) })
        let id = UUID()
        store.configure(homeId: "h", registry: [id: SensorMeta(seriesKind: .numeric, name: "Temp")])
        store.record(id: id, value: 10.0)
        XCTAssertFalse(store.sessions.isEmpty)

        store.clearAll()
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testLegacyFileWithoutSessionsStillLoads() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("history-legacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let storage = FileHistoryStorage(baseDirectory: tmp)

        // Legacy format: a bare [SensorSeries] array, no sessions wrapper.
        let id = UUID()
        var series = SensorSeries(characteristicId: id, kind: .numeric)
        series.numeric = [NumericSample(t: Date(timeIntervalSince1970: 1), v: 9.0)]
        let data = try JSONEncoder().encode([series])
        try data.write(to: tmp.appendingPathComponent("h.json"))

        let archive = storage.load(homeId: "h")
        XCTAssertEqual(archive.series[id], series)
        XCTAssertTrue(archive.sessions.isEmpty)

        try? FileManager.default.removeItem(at: tmp)
    }

    func testRecordedDataReloadsFromStorageOnReconfigure() {
        let storage = InMemoryHistoryStorage()
        let id = UUID()
        let meta = SensorMeta(seriesKind: .numeric, name: "Temp")
        let store1 = HistoryStore(storage: storage, now: { Date(timeIntervalSince1970: 5) }, isEnabled: { true })
        store1.configure(homeId: "h", registry: [id: meta])
        store1.record(id: id, value: 21.0)
        store1.flush()

        // A fresh store with the same storage reloads the persisted series.
        let store2 = HistoryStore(storage: storage, now: { Date(timeIntervalSince1970: 6) }, isEnabled: { true })
        store2.configure(homeId: "h", registry: [id: meta])
        XCTAssertEqual(store2.series(for: id)?.numeric.map(\.v), [21.0])
    }
}
