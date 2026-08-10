//
//  HAClimateMenuItemTests.swift
//  macOSBridgeTests
//
//  Tests for HAClimateMenuItem
//

import XCTest
import AppKit
@testable import macOSBridge

final class HAClimateMenuItemTests: XCTestCase {

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
        availableHVACModes: [String]? = ["off", "heat", "cool"],
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
            name: "Test Climate",
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
            availableHVACModes: availableHVACModes,
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

    /// Recursively collects StepperButton-created buttons by title and size,
    /// left to right (the width disambiguates the regular single-target
    /// steppers, 20 pt, from the small range steppers, 16 pt)
    private func stepperButtons(titled title: String, width: CGFloat, in view: NSView) -> [NSButton] {
        var buttons: [NSButton] = []
        for subview in view.subviews {
            if let button = subview as? NSButton, button.title == title, button.frame.width == width {
                buttons.append(button)
            }
            buttons.append(contentsOf: stepperButtons(titled: title, width: width, in: subview))
        }
        return buttons.sorted { $0.frame.origin.x < $1.frame.origin.x }
    }

    // MARK: - Initialisation tests

    func testInitSetsServiceData() {
        let serviceData = createTestServiceData()
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertEqual(menuItem.serviceData.name, "Test Climate")
        XCTAssertEqual(menuItem.serviceData.serviceType, ServiceTypes.thermostat)
    }

    func testInitCreatesView() {
        let serviceData = createTestServiceData()
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    func testInitCreatesViewWithStepMetadata() {
        let serviceData = createTestServiceData(
            targetTemperatureStep: 0.5,
            targetTemperatureMin: 7,
            targetTemperatureMax: 35
        )
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    func testInitCreatesViewWithThresholdStepMetadata() {
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            coolingThresholdStep: 0.5,
            heatingThresholdTemperatureId: UUID(),
            heatingThresholdStep: 0.5
        )
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    // MARK: - Value update tests

    func testUpdateTargetTemperatureHalfDegreeShowsHalf() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let tempId = UUID()
        let serviceData = createTestServiceData(targetTemperatureId: tempId)
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: tempId, value: 21.5)

        XCTAssertNotNil(menuItem.view)
        // A 21.5 setpoint must read 21.5°, not 22°
        XCTAssertTrue(textFieldValues(in: menuItem.view!).contains("21.5°"))
    }

    func testUpdateTargetTemperatureHalfDegreeWithStepMetadata() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let tempId = UUID()
        let serviceData = createTestServiceData(
            targetTemperatureId: tempId,
            targetTemperatureStep: 0.5,
            targetTemperatureMin: 7,
            targetTemperatureMax: 35
        )
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: tempId, value: 21.5)

        XCTAssertNotNil(menuItem.view)
        XCTAssertTrue(textFieldValues(in: menuItem.view!).contains("21.5°"))
    }

    func testConstructionPlaceholdersStayLiteralInFahrenheit() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

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

    // MARK: - Threshold clamp metadata tests

    func testHeatThresholdClicksClampToMetadataMax() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID(),
            heatingThresholdMax: 20.5
        )
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        // Heating starts at the 18 default; three whole-degree clicks walk
        // 19, 20, then clamp at the 20.5 metadata max instead of reaching 21
        let heatPlus = stepperButtons(titled: "+", width: 16, in: menuItem.view!).first
        XCTAssertNotNil(heatPlus)
        for _ in 0..<3 { heatPlus!.performClick(nil) }

        let labels = textFieldValues(in: menuItem.view!)
        XCTAssertTrue(labels.contains("20.5°"), "Expected the heat threshold clamped to 20.5°, got \(labels)")
        XCTAssertFalse(labels.contains("21°"))
    }

    func testCoolThresholdClicksClampToMetadataMin() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            coolingThresholdMin: 22.5,
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = HAClimateMenuItem(serviceData: serviceData, bridge: nil)

        // Cooling starts at the 24 default; three clicks down walk 23, then
        // clamp at the 22.5 metadata min instead of reaching 21
        let coolMinus = stepperButtons(titled: "−", width: 16, in: menuItem.view!).last
        XCTAssertNotNil(coolMinus)
        for _ in 0..<3 { coolMinus!.performClick(nil) }

        let labels = textFieldValues(in: menuItem.view!)
        XCTAssertTrue(labels.contains("22.5°"), "Expected the cool threshold clamped to 22.5°, got \(labels)")
        XCTAssertFalse(labels.contains("21°"))
    }
}
