import XCTest
@testable import macOSBridge

final class VirtualDeviceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: VirtualDeviceStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "VirtualDeviceStoreTests")!
        defaults.removePersistentDomain(forName: "VirtualDeviceStoreTests")
        store = VirtualDeviceStore(defaults: defaults)
    }

    func test_add_assignsKeyAidAndPersists() throws {
        let d = try store.add(name: "Front Door", type: .contact, role: .door, room: "Hall")
        XCTAssertEqual(d.key, "front-door")
        XCTAssertEqual(d.aid, 2)            // first device gets aid 2 (1 is reserved by the bridge)
        // Reload from the same defaults -> persisted.
        let store2 = VirtualDeviceStore(defaults: defaults)
        XCTAssertEqual(store2.devices.count, 1)
        XCTAssertEqual(store2.devices.first?.name, "Front Door")
    }

    func test_add_rejectsDuplicateName() throws {
        _ = try store.add(name: "Front Door", type: .contact, role: .door, room: nil)
        XCTAssertThrowsError(try store.add(name: "front door", type: .motion, role: nil, room: nil))
    }

    func test_aids_areUniqueAndStableAcrossRemoval() throws {
        let a = try store.add(name: "A", type: .contact, role: nil, room: nil)
        let b = try store.add(name: "B", type: .motion, role: nil, room: nil)
        XCTAssertNotEqual(a.aid, b.aid)
        store.remove(id: a.id)
        let c = try store.add(name: "C", type: .leak, role: nil, room: nil)
        XCTAssertNotEqual(c.aid, b.aid)    // never reuse a live aid
    }

    func test_setState_persistsAndReports() throws {
        let d = try store.add(name: "Leak", type: .leak, role: nil, room: nil)
        store.setState(id: d.id, on: true)
        XCTAssertEqual(store.device(id: d.id)?.state, true)
        XCTAssertEqual(VirtualDeviceStore(defaults: defaults).device(id: d.id)?.state, true)
    }
}
