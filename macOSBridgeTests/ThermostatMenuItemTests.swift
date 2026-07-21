//
//  ThermostatMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for ThermostatMenuItem including Auto mode thresholds
//

import XCTest
import AppKit
@testable import macOSBridge

final class ThermostatMenuItemTests: XCTestCase {

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
        currentTemperatureId: UUID? = UUID(),
        targetTemperatureId: UUID? = UUID(),
        targetTemperatureStep: Double? = nil,
        targetTemperatureMin: Double? = nil,
        targetTemperatureMax: Double? = nil,
        heatingCoolingStateId: UUID? = nil,
        targetHeatingCoolingStateId: UUID? = nil,
        coolingThresholdTemperatureId: UUID? = nil,
        coolingThresholdStep: Double? = nil,
        coolingThresholdMin: Double? = nil,
        coolingThresholdMax: Double? = nil,
        heatingThresholdTemperatureId: UUID? = nil,
        heatingThresholdStep: Double? = nil,
        heatingThresholdMin: Double? = nil,
        heatingThresholdMax: Double? = nil
    ) -> ServiceData {
        ServiceData(
            uniqueIdentifier: UUID(),
            name: "Test Thermostat",
            serviceType: ServiceTypes.thermostat,
            accessoryName: "Test Accessory",
            roomIdentifier: nil,
            currentTemperatureId: currentTemperatureId,
            targetTemperatureId: targetTemperatureId,
            targetTemperatureStep: targetTemperatureStep,
            targetTemperatureMin: targetTemperatureMin,
            targetTemperatureMax: targetTemperatureMax,
            heatingCoolingStateId: heatingCoolingStateId,
            targetHeatingCoolingStateId: targetHeatingCoolingStateId,
            coolingThresholdTemperatureId: coolingThresholdTemperatureId,
            coolingThresholdStep: coolingThresholdStep,
            coolingThresholdMin: coolingThresholdMin,
            coolingThresholdMax: coolingThresholdMax,
            heatingThresholdTemperatureId: heatingThresholdTemperatureId,
            heatingThresholdStep: heatingThresholdStep,
            heatingThresholdMin: heatingThresholdMin,
            heatingThresholdMax: heatingThresholdMax
        )
    }

    /// Recursively collects every NSTextField string value in a view tree
    private func textFieldValues(in view: NSView) -> [String] {
        var values: [String] = []
        for subview in view.subviews {
            if let field = subview as? NSTextField {
                values.append(field.stringValue)
            }
            values.append(contentsOf: textFieldValues(in: subview))
        }
        return values
    }

    /// Recursively collects every NSTextField in a view tree
    private func textFields(in view: NSView) -> [NSTextField] {
        var fields: [NSTextField] = []
        for subview in view.subviews {
            if let field = subview as? NSTextField {
                fields.append(field)
            }
            fields.append(contentsOf: textFields(in: subview))
        }
        return fields
    }

    /// Recursively finds the first subview of a given type
    private func findSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        for subview in view.subviews {
            if let match = subview as? T { return match }
            if let found = findSubview(of: type, in: subview) { return found }
        }
        return nil
    }

    // MARK: - Initialisation tests

    func testInitSetsServiceData() {
        let serviceData = createTestServiceData()
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertEqual(menuItem.serviceData.name, "Test Thermostat")
        XCTAssertEqual(menuItem.serviceData.serviceType, ServiceTypes.thermostat)
    }

    func testInitCreatesView() {
        let serviceData = createTestServiceData()
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Characteristic identifier tests

    func testCharacteristicIdentifiersContainsCurrentTemperatureId() {
        let tempId = UUID()
        let serviceData = createTestServiceData(currentTemperatureId: tempId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(tempId))
    }

    func testCharacteristicIdentifiersContainsTargetTemperatureId() {
        let tempId = UUID()
        let serviceData = createTestServiceData(targetTemperatureId: tempId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(tempId))
    }

    func testCharacteristicIdentifiersContainsHeatingCoolingStateId() {
        let stateId = UUID()
        let serviceData = createTestServiceData(heatingCoolingStateId: stateId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(stateId))
    }

    func testCharacteristicIdentifiersContainsTargetHeatingCoolingStateId() {
        let stateId = UUID()
        let serviceData = createTestServiceData(targetHeatingCoolingStateId: stateId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(stateId))
    }

    func testCharacteristicIdentifiersContainsCoolingThresholdId() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(coolingThresholdTemperatureId: thresholdId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(thresholdId))
    }

    func testCharacteristicIdentifiersContainsHeatingThresholdId() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(heatingThresholdTemperatureId: thresholdId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(thresholdId))
    }

    func testCharacteristicIdentifiersContainsAllWhenAllPresent() {
        let currentTempId = UUID()
        let targetTempId = UUID()
        let currentStateId = UUID()
        let targetStateId = UUID()
        let coolingId = UUID()
        let heatingId = UUID()

        let serviceData = createTestServiceData(
            currentTemperatureId: currentTempId,
            targetTemperatureId: targetTempId,
            heatingCoolingStateId: currentStateId,
            targetHeatingCoolingStateId: targetStateId,
            coolingThresholdTemperatureId: coolingId,
            heatingThresholdTemperatureId: heatingId
        )
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(currentTempId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(targetTempId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(currentStateId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(targetStateId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(coolingId))
        XCTAssertTrue(menuItem.characteristicIdentifiers.contains(heatingId))
    }

    // MARK: - Value update tests

    func testUpdateCurrentTemperatureValue() {
        let tempId = UUID()
        let serviceData = createTestServiceData(currentTemperatureId: tempId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: tempId, value: 21.5)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateTargetTemperatureValue() {
        let tempId = UUID()
        let serviceData = createTestServiceData(targetTemperatureId: tempId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: tempId, value: 22.0)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateHeatingCoolingStateValue() {
        let stateId = UUID()
        let serviceData = createTestServiceData(heatingCoolingStateId: stateId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        // 0=off, 1=heating, 2=cooling
        menuItem.updateValue(for: stateId, value: 1)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateTargetHeatingCoolingStateValue() {
        let stateId = UUID()
        let serviceData = createTestServiceData(targetHeatingCoolingStateId: stateId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        // 0=off, 1=heat, 2=cool, 3=auto
        menuItem.updateValue(for: stateId, value: 3)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateCoolingThresholdValue() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(coolingThresholdTemperatureId: thresholdId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: thresholdId, value: 24.0)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateHeatingThresholdValue() {
        let thresholdId = UUID()
        let serviceData = createTestServiceData(heatingThresholdTemperatureId: thresholdId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: thresholdId, value: 18.0)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueIgnoresUnknownCharacteristicId() {
        let tempId = UUID()
        let unknownId = UUID()
        let serviceData = createTestServiceData(currentTemperatureId: tempId)
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: unknownId, value: 50)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Half-degree metadata tests

    func testInitWithHalfDegreeMetadataCreatesView() {
        let serviceData = createTestServiceData(
            targetTemperatureStep: 0.5,
            targetTemperatureMin: 7.0,
            targetTemperatureMax: 35.0,
            coolingThresholdTemperatureId: UUID(),
            coolingThresholdStep: 0.5,
            coolingThresholdMin: 18.3,
            coolingThresholdMax: 33.3,
            heatingThresholdTemperatureId: UUID(),
            heatingThresholdStep: 0.5,
            heatingThresholdMin: 7.2,
            heatingThresholdMax: 26.1
        )
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueAcceptsHalfDegreeSetpoints() {
        let targetId = UUID()
        let coolingId = UUID()
        let heatingId = UUID()
        let serviceData = createTestServiceData(
            targetTemperatureId: targetId,
            targetTemperatureStep: 0.5,
            coolingThresholdTemperatureId: coolingId,
            coolingThresholdStep: 0.5,
            heatingThresholdTemperatureId: heatingId,
            heatingThresholdStep: 0.5
        )
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: targetId, value: 21.5)
        menuItem.updateValue(for: heatingId, value: 18.5)
        menuItem.updateValue(for: coolingId, value: 24.5)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateTargetTemperatureDisplaysHalfDegreeInCelsius() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let targetId = UUID()
        let serviceData = createTestServiceData(
            targetTemperatureId: targetId,
            targetTemperatureStep: 0.5
        )
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: targetId, value: 21.5)

        // The setpoint label must keep the half degree visible, not ceil to 22°
        let labels = textFieldValues(in: menuItem.view!)
        XCTAssertTrue(labels.contains("21.5°"), "Expected a setpoint label reading 21.5°, got \(labels)")
    }

    func testConstructionPlaceholdersStayLiteralInFahrenheit() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        // Until a real characteristic value arrives the labels keep the
        // pre-metadata literals; converting them at construction would change
        // Fahrenheit behaviour, which the half-degree feature must not touch
        let labels = textFieldValues(in: menuItem.view!)
        XCTAssertTrue(labels.contains("20°"), "Expected the literal 20° placeholder, got \(labels)")
        XCTAssertTrue(labels.contains("18°"), "Expected the literal 18° placeholder, got \(labels)")
        XCTAssertTrue(labels.contains("24°"), "Expected the literal 24° placeholder, got \(labels)")
        XCTAssertFalse(labels.contains("68°"))
        XCTAssertFalse(labels.contains("65°"))
        XCTAssertFalse(labels.contains("76°"))
    }

    // MARK: - Range control layout tests

    func testRangeLabelsFitWidestHalfDegreeStringAndClearModeButtons() {
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        // The mini range labels (the height-14 fields) must hold "34.5°", the
        // widest realistic half-degree string; NSTextField eats about 3 pt of
        // a centred label's width in cell insets before glyphs clip
        let rangeLabels = textFields(in: menuItem.view!).filter { $0.frame.height == 14 }
        XCTAssertEqual(rangeLabels.count, 2)
        let required = ("34.5°" as NSString)
            .size(withAttributes: [.font: DS.Typography.labelSmall]).width
        for label in rangeLabels {
            XCTAssertGreaterThanOrEqual(label.frame.width - 3, required,
                                        "A \(label.frame.width) pt range label clips 34.5°")
        }

        // The widened control must still clear the 3-button mode group
        let modeGroup = findSubview(of: ModeButtonGroup.self, in: menuItem.view!)
        XCTAssertNotNil(modeGroup)
        let rangeContainer = rangeLabels[0].superview!
        XCTAssertGreaterThanOrEqual(rangeContainer.frame.minX, modeGroup!.frame.maxX + 2,
                                    "Range control overlaps the mode button group")
    }

    // MARK: - Protocol conformance tests

    func testConformsToCharacteristicUpdatable() {
        let serviceData = createTestServiceData()
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicUpdatable)
    }

    func testConformsToCharacteristicRefreshable() {
        let serviceData = createTestServiceData()
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is CharacteristicRefreshable)
    }

    func testConformsToLocalChangeNotifiable() {
        let serviceData = createTestServiceData()
        let menuItem = ThermostatMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertTrue(menuItem is LocalChangeNotifiable)
    }
}
