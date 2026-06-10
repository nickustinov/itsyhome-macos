//
//  VirtualDeviceStore.swift
//  macOSBridge
//
//  Source of truth for virtual devices. Persists a list of VirtualDevice to
//  UserDefaults as JSON (the PreferencesManager pattern). AIDs start at 2 (the
//  HAP bridge itself is aid 1) and are never reused while another device is
//  live, so the published accessory layout stays stable.
//
import Foundation

final class VirtualDeviceStore {
    static let shared = VirtualDeviceStore()

    static let didChangeNotification = Notification.Name("VirtualDeviceStoreDidChange")
    private static let storageKey = "virtualDevices"
    private static let nextAidKey = "virtualDevicesNextAid"

    private let defaults: UserDefaults
    private(set) var devices: [VirtualDevice]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([VirtualDevice].self, from: data) {
            self.devices = decoded
        } else {
            self.devices = []
        }
    }

    enum StoreError: LocalizedError {
        case duplicateName(String)
        var errorDescription: String? {
            switch self {
            case .duplicateName(let n): return String(localized: "error.virtual_device.duplicate_name", defaultValue: "A device named \"\(n)\" already exists.", bundle: .macOSBridge)
            }
        }
    }

    // MARK: Queries

    func device(id: UUID) -> VirtualDevice? { devices.first { $0.id == id } }
    func device(key: String) -> VirtualDevice? { devices.first { $0.key == key } }

    /// Case-insensitive name match against virtual devices.
    func device(named name: String) -> VirtualDevice? {
        let q = name.lowercased()
        return devices.first { $0.name.lowercased() == q }
    }

    // MARK: Mutations

    @discardableResult
    func add(name: String, type: VirtualSensorType, role: ContactRole?, room: String?) throws -> VirtualDevice {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if devices.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            throw StoreError.duplicateName(trimmed)
        }
        let device = VirtualDevice(
            id: UUID(),
            key: uniqueKey(base: VirtualDevice.slug(from: trimmed)),
            name: trimmed,
            type: type,
            role: type == .contact ? (role ?? .generic) : nil,
            room: room,
            aid: nextAid(),
            state: false
        )
        devices.append(device)
        persist()
        notifyChanged()
        return device
    }

    func update(_ device: VirtualDevice) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx] = device
        persist()
        notifyChanged()
    }

    func remove(id: UUID) {
        devices.removeAll { $0.id == id }
        persist()
        notifyChanged()
    }

    /// State changes persist but do NOT post didChangeNotification - they don't
    /// alter the device list, so the Settings list shouldn't rebuild (which would
    /// flicker the row you just tapped).
    func setState(id: UUID, on: Bool) {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        guard devices[idx].state != on else { return }
        devices[idx].state = on
        persist()
    }

    // MARK: Helpers

    private func uniqueKey(base: String) -> String {
        let root = base.isEmpty ? "device" : base
        if !devices.contains(where: { $0.key == root }) { return root }
        var n = 2
        while devices.contains(where: { $0.key == "\(root)-\(n)" }) { n += 1 }
        return "\(root)-\(n)"
    }

    /// Monotonic aid counter persisted separately so removed aids are never reused.
    private func nextAid() -> UInt64 {
        let stored = UInt64(defaults.integer(forKey: Self.nextAidKey))
        let aid = max(stored, 2)
        defaults.set(Int(aid + 1), forKey: Self.nextAidKey)
        return aid
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
