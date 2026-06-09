//
//  VirtualBridgeService.swift
//  macOSBridge
//
//  Publishes the VirtualDeviceStore's devices over HAP (acumen-dev/hap-swift)
//  as bridged accessories. State is driven by webhooks/rules via setState; the
//  identity triad (deviceID, identity, pairings) persists so pairings survive
//  restarts. See docs/superpowers/specs/2026-06-08-virtual-device-framework-design.md.
//
import Foundation
import HAPCore
import HAPSwift
import HAPApple
import os.log

// `macOSBridge` has its own `AccessoryInfo`, so the HAP one is referred to as
// `HAPCore.AccessoryInfo` to disambiguate.
private typealias HAPInfo = HAPCore.AccessoryInfo

final class VirtualBridgeService {

    static let shared = VirtualBridgeService()

    static let statusChangedNotification = Notification.Name("virtualBridgeStatusChanged")

    enum Status: Equatable { case stopped, running, error(String) }
    private(set) var status: Status = .stopped {
        didSet { NotificationCenter.default.post(name: Self.statusChangedNotification, object: nil) }
    }

    private let logger = os.Logger(subsystem: "com.nickustinov.itsyhome.macOSBridge", category: "HAP")
    private let store: VirtualDeviceStore

    // A fresh bridge is built per start() so enable/disable cycles never collide
    // on already-registered accessory IDs.
    private var bridge: HAPBridge?
    private var service: AppleHAPService?
    private var started = false

    /// aid -> resolved detected-characteristic iid (filled after addAccessory).
    private var stateIIDs: [UInt64: UInt64] = [:]

    private init(store: VirtualDeviceStore = .shared) {
        self.store = store
    }

    /// The user-facing setup code (XXX-XX-XXX), persisted; shown in Settings.
    var setupCode: String { PreferencesManager.shared.virtualBridgeSetupCode }

    // MARK: Lifecycle

    /// Start only when the user enabled the bridge (and Pro is active). Wired
    /// into ProManager and the Settings toggle.
    func startIfEnabled() {
        guard ProStatusCache.shared.isPro, PreferencesManager.shared.virtualBridgeEnabled else { return }
        Task { await start() }
    }

    /// Publish all current devices and start advertising. Idempotent. No-op if
    /// the store is empty (an accessory-less bridge is pointless) - publishing
    /// begins when the first device is added via `addDevice`.
    func start() async {
        guard !started else { return }
        guard !store.devices.isEmpty else { return }
        started = true

        let bridge = HAPBridge(info: HAPInfo(
            name: "Itsyhome Bridge", manufacturer: "Itsyhome",
            model: "VirtualBridge", serialNumber: "VB-0001", firmwareRevision: "1.0"))
        self.bridge = bridge

        do {
            for device in store.devices { await publish(device, on: bridge) }

            let service = AppleHAPService(
                bridge: bridge,
                setupCode: setupCode,
                deviceID: Self.stableDeviceID(),
                identity: Self.stableIdentity(),
                pairingStore: FilePairingStore(fileURL: Self.supportDir().appendingPathComponent("pairings.json")))
            self.service = service
            try await service.start()
            status = .running
            logger.info("HAP bridge started, \(self.store.devices.count) device(s)")
        } catch {
            started = false
            self.bridge = nil
            self.service = nil
            status = .error(error.localizedDescription)
            logger.error("HAP bridge failed to start: \(error.localizedDescription)")
        }
    }

    func stop() async {
        await service?.stop()
        service = nil
        bridge = nil
        stateIIDs.removeAll()
        started = false
        status = .stopped
    }

    /// Add a device live (or boot the bridge if this is the first one).
    func addDevice(_ device: VirtualDevice) async {
        guard started, let bridge else { await start(); return }
        await publish(device, on: bridge)
    }

    func removeDevice(aid: UInt64) async {
        guard let bridge else { return }
        await bridge.removeAccessory(aid: aid)   // triggers re-advertise via change handler
        stateIIDs[aid] = nil
    }

    /// Re-publish a device after an edit (name/type/role changed): remove the
    /// old accessory at its aid and add it back with the same aid.
    func updateDevice(_ device: VirtualDevice) async {
        guard started, let bridge else { return }
        await bridge.removeAccessory(aid: device.aid)
        stateIIDs[device.aid] = nil
        await publish(device, on: bridge)
    }

    /// Full reset: stop, wipe the persisted identity triad + setup code, then
    /// start fresh so the bridge advertises as a brand-new, unpaired accessory.
    /// The user then removes the stale tile in Apple Home and re-adds it.
    func resetPairing() async {
        await stop()
        Self.deletePersistentState()
        PreferencesManager.shared.resetVirtualBridgeSetupCode()
        await start()
    }

    // MARK: State

    /// Push a device's state outward to Apple Home. The store is updated by the
    /// caller (ActionEngine); this only mirrors it onto HAP.
    func setState(aid: UInt64, on: Bool) async {
        guard let bridge, let iid = stateIIDs[aid] else { return }
        await bridge.updateCharacteristic(aid: aid, iid: iid, value: .uint8(on ? 1 : 0))
    }

    // MARK: Publishing

    private func publish(_ device: VirtualDevice, on bridge: HAPBridge) async {
        let info = HAPInfo(
            name: device.name, manufacturer: "Itsyhome",
            model: "Virtual-\(device.type.rawValue)", serialNumber: "VD-\(device.key)",
            firmwareRevision: "1.0")
        let aid = await bridge.addAccessory(
            info: info,
            services: [device.type.makeHAPService(startIID: 2)],
            aid: device.aid)
        if let iid = await Self.detectedIID(in: bridge, aid: aid, type: device.type) {
            stateIIDs[aid] = iid
            await bridge.updateCharacteristic(aid: aid, iid: iid, value: .uint8(device.state ? 1 : 0))
        }
    }

    /// Find the detected-characteristic IID after addAccessory renumbers IIDs.
    /// Exposed (static) for testing.
    static func detectedIID(in bridge: HAPBridge, aid: UInt64, type: VirtualSensorType) async -> UInt64? {
        for acc in await bridge.accessoryDatabase() where acc.aid == aid {
            for svc in acc.services {
                for char in svc.characteristics where char.type == type.detectedCharacteristic {
                    return char.iid
                }
            }
        }
        return nil
    }

    // MARK: Persistence (identity triad)

    private static func stableDeviceID() -> String {
        let url = supportDir().appendingPathComponent("deviceID")
        if let data = try? Data(contentsOf: url),
           let id = String(data: data, encoding: .utf8), !id.isEmpty { return id }
        let id = (0..<6).map { _ in String(format: "%02X", Int.random(in: 0...255)) }.joined(separator: ":")
        try? Data(id.utf8).write(to: url, options: .atomic)
        return id
    }

    private static func stableIdentity() -> HAPIdentity {
        let url = supportDir().appendingPathComponent("identity")
        if let data = try? Data(contentsOf: url), let identity = try? HAPIdentity(privateKeyData: data) {
            return identity
        }
        let identity = HAPIdentity()
        try? identity.privateKeyData.write(to: url, options: .atomic)
        return identity
    }

    private static func deletePersistentState() {
        let dir = supportDir()
        for name in ["deviceID", "identity", "pairings.json"] {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
        }
    }

    private static func supportDir() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Itsyhome/hap", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
