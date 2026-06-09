//
//  AutomationStore.swift
//  macOSBridge
//
//  Persisted automations (UserDefaults JSON, the PreferencesManager
//  pattern, like VirtualDeviceStore).
//
import Foundation

final class AutomationStore {
    static let shared = AutomationStore()
    static let didChangeNotification = Notification.Name("AutomationStoreDidChange")
    private static let storageKey = "automationRules"

    private let defaults: UserDefaults
    private(set) var automations: [Automation]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Automation].self, from: data) {
            self.automations = decoded
        } else {
            self.automations = []
        }
    }

    func automation(id: UUID) -> Automation? { automations.first { $0.id == id } }

    /// Insert or replace by id.
    func upsert(_ automation: Automation) {
        if let idx = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[idx] = automation
        } else {
            automations.append(automation)
        }
        persist(); notifyChanged()
    }

    func remove(id: UUID) {
        automations.removeAll { $0.id == id }
        persist(); notifyChanged()
    }

    func setEnabled(_ enabled: Bool, id: UUID) {
        guard let idx = automations.firstIndex(where: { $0.id == id }) else { return }
        automations[idx].enabled = enabled
        persist(); notifyChanged()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(automations) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
    private func notifyChanged() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
