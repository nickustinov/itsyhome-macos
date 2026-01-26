//
//  DebugMockAccessories.swift
//  macOSBridge
//
//  Toggle this flag to show one of each accessory type at the top of the menu.
//  Useful for UI testing when you don't have all device types at home.
//

import AppKit

/// Set to true to show mock accessories in the menu for UI testing.
let DebugShowMockAccessories = true

enum DebugMockups {

    static func addMockItems(to menu: NSMenu, builder: MenuBuilder) {
        guard DebugShowMockAccessories else { return }

        let mocks = mockServices()
        for service in mocks {
            if let item = builder.createMenuItemForService(service) {
                menu.addItem(item)

                // Send initial mock values for characteristics that need them
                if let switchItem = item as? SwitchMenuItem,
                   let outletInUseIdStr = service.outletInUseId,
                   let outletInUseId = UUID(uuidString: outletInUseIdStr) {
                    // Mock outlet is "in use" (drawing power)
                    switchItem.updateValue(for: outletInUseId, value: true)
                }

                if let thermostatItem = item as? ThermostatMenuItem,
                   let currentTempIdStr = service.currentTemperatureId,
                   let currentTempId = UUID(uuidString: currentTempIdStr) {
                    thermostatItem.updateValue(for: currentTempId, value: 21.5)
                }

                if let acItem = item as? ACMenuItem,
                   let currentTempIdStr = service.currentTemperatureId,
                   let currentTempId = UUID(uuidString: currentTempIdStr) {
                    acItem.updateValue(for: currentTempId, value: 23.0)
                }

                if let humidifierItem = item as? HumidifierMenuItem {
                    if let humidityIdStr = service.humidityId,
                       let humidityId = UUID(uuidString: humidityIdStr) {
                        humidifierItem.updateValue(for: humidityId, value: 45.0)
                    }
                    if let waterLevelIdStr = service.waterLevelId,
                       let waterLevelId = UUID(uuidString: waterLevelIdStr) {
                        humidifierItem.updateValue(for: waterLevelId, value: 65.0)
                    }
                }
            }
        }
        menu.addItem(NSMenuItem.separator())
    }

    private static func mockServices() -> [ServiceData] {
        [
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Light (RGB)",
                serviceType: ServiceTypes.lightbulb,
                accessoryName: "Mock",
                roomIdentifier: nil,
                powerStateId: UUID(),
                brightnessId: UUID(),
                hueId: UUID(),
                saturationId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Light (CT)",
                serviceType: ServiceTypes.lightbulb,
                accessoryName: "Mock",
                roomIdentifier: nil,
                powerStateId: UUID(),
                brightnessId: UUID(),
                colorTemperatureId: UUID(),
                colorTemperatureMin: 153,
                colorTemperatureMax: 500
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Switch",
                serviceType: ServiceTypes.switch,
                accessoryName: "Mock",
                roomIdentifier: nil,
                powerStateId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Outlet (In Use)",
                serviceType: ServiceTypes.outlet,
                accessoryName: "Mock",
                roomIdentifier: nil,
                powerStateId: UUID(),
                outletInUseId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Thermostat",
                serviceType: ServiceTypes.thermostat,
                accessoryName: "Mock",
                roomIdentifier: nil,
                currentTemperatureId: UUID(),
                targetTemperatureId: UUID(),
                heatingCoolingStateId: UUID(),
                targetHeatingCoolingStateId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock AC",
                serviceType: ServiceTypes.heaterCooler,
                accessoryName: "Mock",
                roomIdentifier: nil,
                currentTemperatureId: UUID(),
                activeId: UUID(),
                currentHeaterCoolerStateId: UUID(),
                targetHeaterCoolerStateId: UUID(),
                coolingThresholdTemperatureId: UUID(),
                heatingThresholdTemperatureId: UUID(),
                swingModeId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Lock",
                serviceType: ServiceTypes.lock,
                accessoryName: "Mock",
                roomIdentifier: nil,
                lockCurrentStateId: UUID(),
                lockTargetStateId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Blind",
                serviceType: ServiceTypes.windowCovering,
                accessoryName: "Mock",
                roomIdentifier: nil,
                currentPositionId: UUID(),
                targetPositionId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Blind (Tilt)",
                serviceType: ServiceTypes.windowCovering,
                accessoryName: "Mock",
                roomIdentifier: nil,
                currentPositionId: UUID(),
                targetPositionId: UUID(),
                currentHorizontalTiltId: UUID(),
                targetHorizontalTiltId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Fan",
                serviceType: ServiceTypes.fan,
                accessoryName: "Mock",
                roomIdentifier: nil,
                activeId: UUID(),
                rotationSpeedId: UUID(),
                rotationSpeedMin: 0,
                rotationSpeedMax: 100,
                targetFanStateId: UUID(),
                currentFanStateId: UUID(),
                rotationDirectionId: UUID(),
                swingModeId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Garage Door",
                serviceType: ServiceTypes.garageDoorOpener,
                accessoryName: "Mock",
                roomIdentifier: nil,
                currentDoorStateId: UUID(),
                targetDoorStateId: UUID(),
                obstructionDetectedId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Humidifier",
                serviceType: ServiceTypes.humidifierDehumidifier,
                accessoryName: "Mock",
                roomIdentifier: nil,
                humidityId: UUID(),
                activeId: UUID(),
                swingModeId: UUID(),
                currentHumidifierDehumidifierStateId: UUID(),
                targetHumidifierDehumidifierStateId: UUID(),
                humidifierThresholdId: UUID(),
                waterLevelId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Air Purifier",
                serviceType: ServiceTypes.airPurifier,
                accessoryName: "Mock",
                roomIdentifier: nil,
                activeId: UUID(),
                swingModeId: UUID(),
                currentAirPurifierStateId: UUID(),
                targetAirPurifierStateId: UUID()
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Valve",
                serviceType: ServiceTypes.valve,
                accessoryName: "Mock",
                roomIdentifier: nil,
                activeId: UUID(),
                inUseId: UUID(),
                valveTypeValue: 1
            ),
            ServiceData(
                uniqueIdentifier: UUID(),
                name: "Mock Security",
                serviceType: ServiceTypes.securitySystem,
                accessoryName: "Mock",
                roomIdentifier: nil,
                securitySystemCurrentStateId: UUID(),
                securitySystemTargetStateId: UUID()
            ),
        ]
    }
}
