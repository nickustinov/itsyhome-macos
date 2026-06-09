import XCTest
@testable import macOSBridge

final class AutomationStoreTests: XCTestCase {
    private func make(_ name: String) -> Automation {
        Automation(id: UUID(), name: name, enabled: true,
            trigger: .accessoryState(AccessoryStateTrigger(characteristicId: UUID(),
                accessoryName: "D", characteristicLabel: "C", comparator: .equal, value: 1)),
            conditions: [.duration(seconds: 900)], actions: [])
    }

    func test_crud_persists() {
        let d = UserDefaults(suiteName: "AutomationStoreTests")!
        d.removePersistentDomain(forName: "AutomationStoreTests")
        let store = AutomationStore(defaults: d)
        let r = make("A")
        store.upsert(r)
        XCTAssertEqual(AutomationStore(defaults: d).automations.count, 1)
        var edited = r; edited.name = "B"
        store.upsert(edited)
        XCTAssertEqual(store.automation(id: r.id)?.name, "B")
        store.remove(id: r.id)
        XCTAssertTrue(store.automations.isEmpty)
    }

    func test_setEnabled() {
        let d = UserDefaults(suiteName: "AutomationStoreTests2")!
        d.removePersistentDomain(forName: "AutomationStoreTests2")
        let store = AutomationStore(defaults: d)
        let r = make("A"); store.upsert(r)
        store.setEnabled(false, id: r.id)
        XCTAssertEqual(store.automation(id: r.id)?.enabled, false)
    }
}
