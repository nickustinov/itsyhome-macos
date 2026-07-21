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
        coolingThresholdStep: Double? = nil,
        coolingThresholdMin: Double? = nil,
        coolingThresholdMax: Double? = nil,
        heatingThresholdTemperatureId: UUID? = nil,
        heatingThresholdStep: Double? = nil,
        heatingThresholdMin: Double? = nil,
        heatingThresholdMax: Double? = nil,
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
            coolingThresholdStep: coolingThresholdStep,
            coolingThresholdMin: coolingThresholdMin,
            coolingThresholdMax: coolingThresholdMax,
            heatingThresholdTemperatureId: heatingThresholdTemperatureId,
            heatingThresholdStep: heatingThresholdStep,
            heatingThresholdMin: heatingThresholdMin,
            heatingThresholdMax: heatingThresholdMax,
            swingModeId: swingModeId
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

    /// Recursively collects StepperButton-created buttons by title and size,
    /// left to right (the width disambiguates the regular single-target
    /// steppers, 20 pt, from the mini range steppers, 11 pt)
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

    // MARK: - Half-degree metadata tests

    func testInitWithHalfDegreeMetadataCreatesView() {
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            coolingThresholdStep: 0.5,
            coolingThresholdMin: 16.0,
            coolingThresholdMax: 30.0,
            heatingThresholdTemperatureId: UUID(),
            heatingThresholdStep: 0.5,
            heatingThresholdMin: 16.0,
            heatingThresholdMax: 30.0
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateValueAcceptsHalfDegreeSetpoints() {
        let coolingId = UUID()
        let heatingId = UUID()
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: coolingId,
            coolingThresholdStep: 0.5,
            heatingThresholdTemperatureId: heatingId,
            heatingThresholdStep: 0.5
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: heatingId, value: 20.5)
        menuItem.updateValue(for: coolingId, value: 24.5)

        XCTAssertNotNil(menuItem.view)
    }

    func testUpdateCoolingThresholdDisplaysHalfDegreeInCelsius() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let coolingId = UUID()
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: coolingId,
            coolingThresholdStep: 0.5
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: coolingId, value: 22.5)

        // The setpoint label must keep the half degree visible, not ceil to 23°
        let labels = textFieldValues(in: menuItem.view!)
        XCTAssertTrue(labels.contains("22.5°"), "Expected a setpoint label reading 22.5°, got \(labels)")
    }

    // MARK: - Fahrenheit stepping regression (AC unification)

    func testFahrenheitSingleTargetClickMovesOneDisplayedDegree() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        // Cooling-only device: the single-target control drives the cooling
        // threshold, so clicking its steppers exercises the real increase and
        // decrease handlers, not just the formatter they delegate to
        let coolingId = UUID()
        let serviceData = createTestServiceData(coolingThresholdTemperatureId: coolingId)
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: coolingId, value: 22.0)
        XCTAssertTrue(textFieldValues(in: menuItem.view!).contains("72°"))

        let minusButtons = stepperButtons(titled: "−", width: 20, in: menuItem.view!)
        let plusButtons = stepperButtons(titled: "+", width: 20, in: menuItem.view!)
        XCTAssertEqual(minusButtons.count, 1)
        XCTAssertEqual(plusButtons.count, 1)

        // One click moves exactly one displayed °F; the pre-unification raw
        // −1 °C stepping jumped 1.8 °F and skipped 71° entirely
        minusButtons[0].performClick(nil)
        XCTAssertTrue(textFieldValues(in: menuItem.view!).contains("71°"),
                      "A stepper click must move one displayed °F")

        plusButtons[0].performClick(nil)
        XCTAssertTrue(textFieldValues(in: menuItem.view!).contains("72°"))
    }

    func testCelsiusSingleTargetClickHonoursHalfDegreeStep() {
        PreferencesManager.shared.temperatureUnit = "celsius"

        let coolingId = UUID()
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: coolingId,
            coolingThresholdStep: 0.5
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        menuItem.updateValue(for: coolingId, value: 22.0)

        let plusButtons = stepperButtons(titled: "+", width: 20, in: menuItem.view!)
        XCTAssertEqual(plusButtons.count, 1)

        plusButtons[0].performClick(nil)
        XCTAssertTrue(textFieldValues(in: menuItem.view!).contains("22.5°"),
                      "A 0.5 °C device must step the setpoint by half a degree")
    }

    func testConstructionPlaceholdersStayLiteralInFahrenheit() {
        PreferencesManager.shared.temperatureUnit = "fahrenheit"

        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

        // Until a real characteristic value arrives the labels keep the
        // pre-metadata literals; converting them at construction would change
        // Fahrenheit behaviour, which the half-degree feature must not touch
        let labels = textFieldValues(in: menuItem.view!)
        XCTAssertTrue(labels.contains("24°"), "Expected the literal 24° placeholder, got \(labels)")
        XCTAssertTrue(labels.contains("20°"), "Expected the literal 20° placeholder, got \(labels)")
        XCTAssertFalse(labels.contains("76°"))
        XCTAssertFalse(labels.contains("68°"))
    }

    // MARK: - Range control layout tests

    func testRangeLabelsFitWidestHalfDegreeStringAndClearModeButtons() {
        let serviceData = createTestServiceData(
            coolingThresholdTemperatureId: UUID(),
            heatingThresholdTemperatureId: UUID()
        )
        let menuItem = ACMenuItem(serviceData: serviceData, bridge: nil)

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
}
