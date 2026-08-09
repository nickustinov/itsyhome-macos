//
//  ACMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for ACMenuItem including swing mode
//

import XCTest
import AppKit
@testable import macOSBridge

final class ACMenuItemTests: XCTestCase {

    // MARK: - Test helpers

    private func createTestServiceData(
        activeId: UUID? = UUID(),
        currentTemperatureId: UUID? = UUID(),
        currentHeaterCoolerStateId: UUID? = nil,
        targetHeaterCoolerStateId: UUID? = nil,
        validTargetHeaterCoolerStates: [Int]? = nil,
        coolingThresholdTemperatureId: UUID? = nil,
        heatingThresholdTemperatureId: UUID? = nil,
        swingModeId: UUID? = nil
    ) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: "Test AC",
            serviceType: ServiceTypes.heaterCooler,
            accessoryName: "Test Accessory",
            roomIdentifier: nil,
            currentTemperatureId: currentTemperatureId,
            activeId: activeId,
            currentHeaterCoolerStateId: currentHeaterCoolerStateId,
            targetHeaterCoolerStateId: targetHeaterCoolerStateId,
            validTargetHeaterCoolerStates: validTargetHeaterCoolerStates,
            coolingThresholdTemperatureId: coolingThresholdTemperatureId,
            heatingThresholdTemperatureId: heatingThresholdTemperatureId,
            swingModeId: swingModeId
        )
    }

    // MARK: - Initialisation tests

    func testInitSetsServiceData() {
        let serviceData = createTestServiceData()
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertEqual(menuItem.serviceData.name, "Test AC")
        XCTAssertEqual(menuItem.serviceData.serviceType, ServiceTypes.heaterCooler)
    }

    func testInitCreatesView() {
        let serviceData = createTestServiceData()
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Characteristic identifier tests

    func testCharacteristicIdentifiersContainsActiveId() {
        let activeId = UUID()
        let serviceData = createTestServiceData(activeId: activeId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(activeId))
    }

    func testCharacteristicIdentifiersContainsCurrentTemperatureId() {
        let tempId = UUID()
        let serviceData = createTestServiceData(currentTemperatureId: tempId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(tempId))
    }

    func testCharacteristicIdentifiersContainsTargetHeaterCoolerStateId() {
        let stateId = UUID()
        let serviceData = createTestServiceData(targetHeaterCoolerStateId: stateId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(stateId))
    }

    func testCharacteristicIdentifiersContainsCoolingThresholdId() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(coolingThresholdTemperatureId: thresholdId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(thresholdId))
    }

    func testCharacteristicIdentifiersContainsHeatingThresholdId() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(heatingThresholdTemperatureId: thresholdId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(thresholdId))
    }

    func testCharacteristicIdentifiersContainsSwingModeId() {
        let swingId = UUID()
        let serviceData = createTestServiceData(swingModeId: swingId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(swingId))
    }

    func testCharacteristicIdentifiersContainsAllWhenAllPresent() {
        let activeId = UUID()
        let tempId = UUID()
        let currentStateId = UUID()
        let targetStateId = UUID()
        let coolingId = UUID()
        let heatingId = UUID()
        let swingId = UUID()

        let serviceData = createTestServiceData(
            activeId: activeId,
            currentTemperatureId: tempId,
            currentHeaterCoolerStateId: currentStateId,
            targetHeaterCoolerStateId: targetStateId,
            coolingThresholdTemperatureId: coolingId,
            heatingThresholdTemperatureId: heatingId,
            swingModeId: swingId
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(activeId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(tempId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(currentStateId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(targetStateId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(coolingId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(heatingId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(swingId))
    }

    // MARK: - Value update tests

    func testUpdateActiveValue() {
        let activeId = UUID()
        let serviceData = createTestServiceData(activeId: activeId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: activeId, value: 1)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateCurrentTemperatureValue() {
        let tempId = UUID()
        let serviceData = createTestServiceData(currentTemperatureId: tempId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: tempId, value: 22.5)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateTargetHeaterCoolerStateValue() {
        let stateId = UUID()
        let serviceData = createTestServiceData(targetHeaterCoolerStateId: stateId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        // 0 = auto, 1 = heat, 2 = cool
        menuItem.updateValue(for: stateId, value: 2)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateCoolingThresholdValue() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(coolingThresholdTemperatureId: thresholdId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: thresholdId, value: 24.0)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateHeatingThresholdValue() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(heatingThresholdTemperatureId: thresholdId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: thresholdId, value: 20.0)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateSwingModeValue() {
        let swingId = UUID()
        let serviceData = createTestServiceData(swingModeId: swingId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        // 0 = DISABLED, 1 = ENABLED
        menuItem.updateValue(for: swingId, value: 1)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueIgnoresUnknownCharacteristicId() {
        let activeId = UUID()
        let unknownId = UUID()
        let serviceData = createTestServiceData(activeId: activeId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: unknownId, value: 50)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Mode selector visibility tests

    /// Recursively finds the first subview of a given type
    private func findSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        for subview in view.subviews {
            if let match = subview as? T { return match }
            if let found = findSubview(of: type, in: subview) { return found }
        }
        return nil
    }

    func testSingleModeHidesModeSelector() {
        let serviceData = createTestServiceData(
            targetHeaterCoolerStateId: UUID(),
            validTargetHeaterCoolerStates: [1],  // heat only
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        // Find ModeButtonGroup in view hierarchy – it should be hidden
        let modeGroup = findSubview(of: ModeButtonGroup.self, in: menuItem.view!)
        XCTAssertNotNil(modeGroup)
        XCTAssertTrue(modeGroup!.isHidden)
    }

    func testAllModesShowsModeSelector() {
        let serviceData = createTestServiceData(
            targetHeaterCoolerStateId: UUID(),
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        let modeGroup = findSubview(of: ModeButtonGroup.self, in: menuItem.view!)
        XCTAssertNotNil(modeGroup)
        XCTAssertFalse(modeGroup!.isHidden)
    }

    func testTwoModesShowsTwoButtons() {
        let serviceData = createTestServiceData(
            targetHeaterCoolerStateId: UUID(),
            validTargetHeaterCoolerStates: [1, 2],  // heat + cool
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        let modeGroup = findSubview(of: ModeButtonGroup.self, in: menuItem.view!)
        XCTAssertNotNil(modeGroup)
        XCTAssertFalse(modeGroup!.isHidden)
        // Should have exactly 2 ModeButton subviews
        let modeButtons = modeGroup!.subviews.compactMap { $0 as? ModeButton }
        XCTAssertEqual(modeButtons.count, 2)
    }

    // MARK: - Protocol conformance tests

    func testConformsToCharacteristicUpdatable() {
        let serviceData = createTestServiceData()
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicUpdatable)
    }

    func testConformsToCharacteristicRefreshable() {
        let serviceData = createTestServiceData()
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicRefreshable)
    }

    func testConformsToLocalChangeNotifiable() {
        let serviceData = createTestServiceData()
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is LocalChangeNotifiable)
    }

    // MARK: - Fahrenheit stepper direction & granularity
    // ACMenuItem used to step the raw Celsius value (±1), which in Fahrenheit
    // mode jumped the shown °F by ~1.8° (skipping degrees). It must instead use
    // the unit-aware TemperatureFormatter.step, like Thermostat/HAClimate items.

    /// Recursively collects every NSTextField stringValue in a view tree.
    private func displayedStrings(in view: NSView) -> [String] {
        var strings: [String] = []
        for subview in view.subviews {
            if let label = subview as? NSTextField {
                strings.append(label.stringValue)
            }
            strings.append(contentsOf: displayedStrings(in: subview))
        }
        return strings
    }

    /// Invokes a private @objc stepper action by selector name (e.g. "increaseTemp:").
    private func drive(_ selector: String, on item: ACMenuItem) {
        _ = item.perform(NSSelectorFromString(selector), with: NSButton())
    }

    /// A Cool-mode AC with both thresholds, seeded to `coolingCelsius`, wired to
    /// a capturing bridge. Returns the item and its cooling-threshold identifier.
    private func makeCoolAC(coolingCelsius: Double, bridge: Mac2iOS) -> (ACMenuItem, UUID) {
        let coolingId = UUID()
        let heatingId = UUID()
        let targetStateId = UUID()
        let serviceData = createTestServiceData(
            targetHeaterCoolerStateId: targetStateId,
            validTargetHeaterCoolerStates: [0, 1, 2],
            coolingThresholdTemperatureId: coolingId,
            heatingThresholdTemperatureId: heatingId
        )
        let item = ACMenuItem(serviceData: serviceData, bridge: bridge)
        item.updateValue(for: targetStateId, value: 2)  // Cool → reads the cooling threshold
        item.updateValue(for: coolingId, value: coolingCelsius)
        return (item, coolingId)
    }

    func testFahrenheitIncreaseAdvancesExactlyOneDisplayedDegreeUp() {
        let savedUnit = PreferencesManager.shared.temperatureUnit
        PreferencesManager.shared.temperatureUnit = "fahrenheit"
        defer { PreferencesManager.shared.temperatureUnit = savedUnit }

        let bridge = CapturingBridge()
        let (item, _) = makeCoolAC(coolingCelsius: 23.0, bridge: bridge)  // 23 °C → 74 °F

        drive("increaseTemp:", on: item)

        // + warms by exactly one shown °F: 74 → 75, not the 1.8 °F skip to 76.
        let labels = displayedStrings(in: item.view!)
        XCTAssertTrue(labels.contains("75°"), "Increase should show 75°; labels: \(labels)")
        XCTAssertFalse(labels.contains("76°"), "Increase must not skip to 76°; labels: \(labels)")
    }

    func testFahrenheitDecreaseAdvancesExactlyOneDisplayedDegreeDown() {
        let savedUnit = PreferencesManager.shared.temperatureUnit
        PreferencesManager.shared.temperatureUnit = "fahrenheit"
        defer { PreferencesManager.shared.temperatureUnit = savedUnit }

        let bridge = CapturingBridge()
        let (item, _) = makeCoolAC(coolingCelsius: 23.0, bridge: bridge)  // 74 °F

        drive("decreaseTemp:", on: item)

        // − cools by exactly one shown °F: 74 → 73, not the 1.8 °F skip to 72.
        let labels = displayedStrings(in: item.view!)
        XCTAssertTrue(labels.contains("73°"), "Decrease should show 73°; labels: \(labels)")
        XCTAssertFalse(labels.contains("72°"), "Decrease must not skip to 72°; labels: \(labels)")
    }

    func testStepperDirectionWarmsOnIncreaseCoolsOnDecrease() {
        // Direction is unit-independent: + always warms, − always cools. Verify
        // the value written to the bridge in both Celsius and Fahrenheit modes.
        for unit in ["celsius", "fahrenheit"] {
            let savedUnit = PreferencesManager.shared.temperatureUnit
            PreferencesManager.shared.temperatureUnit = unit
            defer { PreferencesManager.shared.temperatureUnit = savedUnit }

            let bridge = CapturingBridge()
            let (item, coolingId) = makeCoolAC(coolingCelsius: 23.0, bridge: bridge)

            drive("increaseTemp:", on: item)
            XCTAssertGreaterThan(bridge.valueAsDouble(for: coolingId), 23.0, "[\(unit)] + must warm")

            bridge.clear()
            item.updateValue(for: coolingId, value: 23.0)
            drive("decreaseTemp:", on: item)
            XCTAssertLessThan(bridge.valueAsDouble(for: coolingId), 23.0, "[\(unit)] − must cool")
        }
    }
}

/// Mac2iOS mock that records writeCharacteristic calls for stepper assertions.
private final class CapturingBridge: NSObject, Mac2iOS {
    var homes: [HomeInfo] = []
    var selectedHomeIdentifier: UUID?
    var rooms: [RoomInfo] = []
    var accessories: [AccessoryInfo] = []
    var scenes: [SceneInfo] = []
    var characteristicValues: [UUID: Any] = [:]

    private(set) var writes: [UUID: Any] = [:]

    func reloadHomeKit() {}
    func executeScene(identifier: UUID) {}
    func readCharacteristic(identifier: UUID) {}
    func writeCharacteristic(identifier: UUID, value: Any) {
        writes[identifier] = value
    }
    func getCharacteristicValue(identifier: UUID) -> Any? { characteristicValues[identifier] }
    func openCameraWindow() {}
    func closeCameraWindow() {}
    func setCameraWindowHidden(_ hidden: Bool) {}
    func getRawHomeKitDump() -> String? { nil }
    func getCameraDebugJSON(entityId: String?, completion: @escaping (String?) -> Void) { completion(nil) }

    func valueAsDouble(for id: UUID) -> Double {
        guard let value = writes[id] else { return .nan }
        if let d = value as? Double { return d }
        if let f = value as? Float { return Double(f) }
        if let i = value as? Int { return Double(i) }
        return .nan
    }

    func clear() { writes.removeAll() }
}
