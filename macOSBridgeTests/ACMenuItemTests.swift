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

    // Saved temperature unit so the stepper tests can flip it without leaking
    // state into the other tests in this class (or the global formatter cache).
    private var savedUnit: String!

    override func setUp() {
        super.setUp()
        savedUnit = PreferencesManager.shared.temperatureUnit
    }

    override func tearDown() {
        PreferencesManager.shared.temperatureUnit = savedUnit
        super.tearDown()
    }

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
    //
    // Regression guard for the unit-aware stepper. ACMenuItem must drive the
    // target temperature through TemperatureFormatter.step(_:by:) (like
    // ThermostatMenuItem / HAClimateMenuItem) so that, in Fahrenheit mode, one
    // stepper click moves the *displayed* °F value by exactly one degree in the
    // correct direction (+ warms, − cools). Stepping the stored Celsius value
    // directly moves ~1.8 °F and skips degrees (72 → 74 on “+”).

    /// Collect every descendant of `view` of the given type.
    private func allControls<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        var result: [T] = []
        for subview in view.subviews {
            if let match = subview as? T { result.append(match) }
            result.append(contentsOf: allControls(type, in: subview))
        }
        return result
    }

    /// The single-temperature steppers are created at `.regular` size (20×20);
    /// the Auto-mode range steppers are `.mini` (11×11). Size therefore uniquely
    /// identifies the [−]/[+] pair. Within their shared container the minus
    /// button sits left of the plus button.
    private func singleSteppers(in menuItem: ACMenuItem) -> (minus: NSButton, plus: NSButton) {
        let regular = allControls(NSButton.self, in: menuItem.view!).filter {
            abs($0.bounds.width - 20) < 0.5 && abs($0.bounds.height - 20) < 0.5
        }
        let sorted = regular.sorted { $0.frame.minX < $1.frame.minX }
        return (sorted[0], sorted[1])
    }

    /// The label the user sees between [−] and [+] — it lives in the same
    /// container as the single steppers.
    private func singleTargetLabel(in menuItem: ACMenuItem) -> NSTextField {
        let (minus, _) = singleSteppers(in: menuItem)
        let fields = minus.superview!.subviews.compactMap { $0 as? NSTextField }
        return fields[0]
    }

    /// Cool-only service so the single (non-range) temperature control is shown.
    private func makeCoolOnlyAC(coolingId: UUID) -> ACMenuItem {
        let serviceData = createTestServiceData(
            targetHeaterCoolerStateId: UUID(),
            validTargetHeaterCoolerStates: [2],
            coolingThresholdTemperatureId: coolingId
        )
        return ACMenuItem(serviceData: serviceData, bridge: nil)
    }

    func testFahrenheitStepperWarmsAndCoolsExactlyOneDegree() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        let coolingId = UUID()
        let menuItem = makeCoolOnlyAC(coolingId: coolingId)
        // 22 °C → 71.6 °F → ceiling 72 °F.
        menuItem.updateValue(for: coolingId, value: 22.0)

        let label = singleTargetLabel(in: menuItem)
        let (minus, plus) = singleSteppers(in: menuItem)

        XCTAssertEqual(label.stringValue, "72°")

        // “+” warms by exactly one displayed degree: 72 → 73 (not ~74).
        plus.performClick(nil)
        XCTAssertEqual(label.stringValue, "73°")

        // “−” cools by exactly one displayed degree: 73 → 72 → 71.
        minus.performClick(nil)
        XCTAssertEqual(label.stringValue, "72°")
        minus.performClick(nil)
        XCTAssertEqual(label.stringValue, "71°")
    }

    func testCelsiusStepperStillStepsExactlyOneDegree() {
        // Anti-scope guard: Celsius mode must be untouched (one degree per click).
        PreferencesManager.shared.temperatureUnit = "celsius"

        let coolingId = UUID()
        let menuItem = makeCoolOnlyAC(coolingId: coolingId)
        menuItem.updateValue(for: coolingId, value: 22.0)

        let label = singleTargetLabel(in: menuItem)
        let (minus, plus) = singleSteppers(in: menuItem)

        XCTAssertEqual(label.stringValue, "22°")
        plus.performClick(nil)
        XCTAssertEqual(label.stringValue, "23°")
        minus.performClick(nil)
        XCTAssertEqual(label.stringValue, "22°")
    }
}
