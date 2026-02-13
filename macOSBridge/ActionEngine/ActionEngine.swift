//
//  ActionEngine.swift
//  macOSBridge
//
//  Unified API for executing HomeKit actions
//

import Foundation

// MARK: - Action types

enum Action: Equatable {
    // Power
    case toggle
    case turnOn
    case turnOff

    // Brightness (0-100)
    case setBrightness(Int)

    // Color
    case setColor(hue: Double, saturation: Double)
    case setColorTemp(mired: Int)

    // Position (blinds, 0-100)
    case setPosition(Int)

    // Thermostat
    case setTargetTemp(Double)
    case setMode(ThermostatMode)

    // Lock
    case lock
    case unlock

    // Scene
    case executeScene
}

enum ThermostatMode: Int {
    case off = 0
    case heat = 1
    case cool = 2
    case auto = 3
}

// MARK: - Result types

enum ActionResult: Equatable {
    case success
    case partial(succeeded: Int, failed: Int)
    case error(ActionError)
}

enum ActionError: Error, Equatable {
    case targetNotFound(String)
    case ambiguousTarget([String])
    case unsupportedAction(String)
    case bridgeUnavailable
    case executionFailed(String)
}

// MARK: - ActionEngine

class ActionEngine {

    weak var bridge: Mac2iOS?
    private(set) var menuData: MenuData?
    var onCharacteristicWrite: ((UUID, Any) -> Void)?

    init(bridge: Mac2iOS? = nil) {
        self.bridge = bridge
    }

    // MARK: - Public API

    func updateMenuData(_ data: MenuData) {
        self.menuData = data
    }

    func execute(target: String, action: Action) -> ActionResult {
        guard let bridge = bridge else {
            return .error(.bridgeUnavailable)
        }
        guard let data = menuData else {
            return .error(.bridgeUnavailable)
        }

        let resolved = DeviceResolver.resolve(target, in: data, groups: PreferencesManager.shared.deviceGroups)

        switch resolved {
        case .services(let services):
            return executeOnServices(services, action: action, bridge: bridge)
        case .scene(let scene):
            return executeScene(scene, bridge: bridge)
        case .notFound(let query):
            return .error(.targetNotFound(query))
        case .ambiguous(let options):
            return .error(.ambiguousTarget(options.map(\.name)))
        }
    }

    func executeMultiple(targets: [String], action: Action) -> ActionResult {
        guard bridge != nil else {
            return .error(.bridgeUnavailable)
        }
        guard menuData != nil else {
            return .error(.bridgeUnavailable)
        }

        var succeeded = 0
        var failed = 0

        for target in targets {
            let result = execute(target: target, action: action)
            switch result {
            case .success:
                succeeded += 1
            case .partial(let s, let f):
                succeeded += s
                failed += f
            case .error:
                failed += 1
            }
        }

        if failed == 0 {
            return .success
        } else if succeeded == 0 {
            return .error(.executionFailed("All targets failed"))
        } else {
            return .partial(succeeded: succeeded, failed: failed)
        }
    }

    // MARK: - Execution helpers

    private func executeOnServices(_ services: [ServiceData], action: Action, bridge: Mac2iOS) -> ActionResult {
        var succeeded = 0
        var failed = 0

        for service in services {
            if executeAction(action, on: service, bridge: bridge) {
                succeeded += 1
            } else {
                failed += 1
            }
        }

        if failed == 0 {
            return .success
        } else if succeeded == 0 {
            return .error(.executionFailed("Action not supported on any service"))
        } else {
            return .partial(succeeded: succeeded, failed: failed)
        }
    }

    private func executeScene(_ scene: SceneData, bridge: Mac2iOS) -> ActionResult {
        guard let uuid = UUID(uuidString: scene.uniqueIdentifier) else {
            return .error(.executionFailed("Invalid scene UUID"))
        }
        bridge.executeScene(identifier: uuid)
        return .success
    }

    private func executeAction(_ action: Action, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        switch action {
        case .toggle:
            return executeToggle(on: service, bridge: bridge)
        case .turnOn:
            return executePowerState(true, on: service, bridge: bridge)
        case .turnOff:
            return executePowerState(false, on: service, bridge: bridge)
        case .setBrightness(let value):
            return executeBrightness(value, on: service, bridge: bridge)
        case .setColor(let hue, let saturation):
            return executeColor(hue: hue, saturation: saturation, on: service, bridge: bridge)
        case .setColorTemp(let mired):
            return executeColorTemp(mired, on: service, bridge: bridge)
        case .setPosition(let value):
            return executePosition(value, on: service, bridge: bridge)
        case .setTargetTemp(let temp):
            return executeTargetTemp(temp, on: service, bridge: bridge)
        case .setMode(let mode):
            return executeThermostatMode(mode, on: service, bridge: bridge)
        case .lock:
            return executeLockState(locked: true, on: service, bridge: bridge)
        case .unlock:
            return executeLockState(locked: false, on: service, bridge: bridge)
        case .executeScene:
            return false // Scenes handled separately
        }
    }

    private func writeCharacteristic(identifier: UUID, value: Any, bridge: Mac2iOS) {
        bridge.writeCharacteristic(identifier: identifier, value: value)
        onCharacteristicWrite?(identifier, value)
    }

    // MARK: - Individual action executors

    private func executeToggle(on service: ServiceData, bridge: Mac2iOS) -> Bool {
        // Power state toggle (lights, switches, outlets)
        if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Bool ?? false
            writeCharacteristic(identifier: id, value: !current, bridge: bridge)
            return true
        }

        // Active toggle (AC, fans)
        if let idString = service.activeId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0, bridge: bridge)
            return true
        }

        // Lock toggle
        if let idString = service.lockTargetStateId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 1
            writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0, bridge: bridge)
            return true
        }

        // Blind toggle (open/close)
        if let idString = service.targetPositionId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current > 50 ? 0 : 100, bridge: bridge)
            return true
        }

        // Garage door toggle
        if let idString = service.targetDoorStateId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 1
            writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0, bridge: bridge)
            return true
        }

        // Thermostat toggle (off/auto)
        if let idString = service.targetHeatingCoolingStateId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current == 0 ? 3 : 0, bridge: bridge)
            return true
        }

        // Brightness toggle for dimmable lights without power state
        if let idString = service.brightnessId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current > 0 ? 0 : 100, bridge: bridge)
            return true
        }

        // Security system toggle (disarmed/stay armed)
        if let idString = service.securitySystemTargetStateId, let id = UUID(uuidString: idString) {
            let current = bridge.getCharacteristicValue(identifier: id) as? Int ?? 3
            writeCharacteristic(identifier: id, value: current == 3 ? 0 : 3, bridge: bridge)
            return true
        }

        return false
    }

    private func executePowerState(_ on: Bool, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: on, bridge: bridge)
            return true
        }

        if let idString = service.activeId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: on ? 1 : 0, bridge: bridge)
            return true
        }

        return false
    }

    private func executeBrightness(_ value: Int, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        guard let idString = service.brightnessId, let id = UUID(uuidString: idString) else {
            return false
        }
        let clampedValue = max(0, min(100, value))

        // Explicitly set power state to ensure light turns on/off with brightness
        // HomeKit spec leaves this behavior to the accessory, so we be explicit
        if let powerIdString = service.powerStateId, let powerId = UUID(uuidString: powerIdString) {
            writeCharacteristic(identifier: powerId, value: clampedValue > 0, bridge: bridge)
        }

        writeCharacteristic(identifier: id, value: clampedValue, bridge: bridge)
        return true
    }

    private func executeColor(hue: Double, saturation: Double, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        guard let hueIdString = service.hueId, let hueId = UUID(uuidString: hueIdString),
              let satIdString = service.saturationId, let satId = UUID(uuidString: satIdString) else {
            return false
        }
        let clampedHue = max(0, min(360, hue))
        let clampedSat = max(0, min(100, saturation))
        writeCharacteristic(identifier: hueId, value: clampedHue, bridge: bridge)
        writeCharacteristic(identifier: satId, value: clampedSat, bridge: bridge)
        return true
    }

    private func executeColorTemp(_ mired: Int, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        guard let idString = service.colorTemperatureId, let id = UUID(uuidString: idString) else {
            return false
        }
        var value = mired
        if let minMired = service.colorTemperatureMin {
            value = max(Int(minMired), value)
        }
        if let maxMired = service.colorTemperatureMax {
            value = min(Int(maxMired), value)
        }
        writeCharacteristic(identifier: id, value: value, bridge: bridge)
        return true
    }

    private func executePosition(_ value: Int, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        guard let idString = service.targetPositionId, let id = UUID(uuidString: idString) else {
            return false
        }
        let clampedValue = max(0, min(100, value))
        writeCharacteristic(identifier: id, value: clampedValue, bridge: bridge)
        return true
    }

    private func executeTargetTemp(_ temp: Double, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        // Standard thermostat
        if let idString = service.targetTemperatureId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: temp, bridge: bridge)
            return true
        }

        // HeaterCooler (AC) - set both cooling and heating thresholds
        var success = false
        if let idString = service.coolingThresholdTemperatureId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: temp, bridge: bridge)
            success = true
        }
        if let idString = service.heatingThresholdTemperatureId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: temp, bridge: bridge)
            success = true
        }

        return success
    }

    private func executeThermostatMode(_ mode: ThermostatMode, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        // Standard thermostat
        if let idString = service.targetHeatingCoolingStateId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: mode.rawValue, bridge: bridge)
            return true
        }

        // HeaterCooler (AC)
        if let idString = service.targetHeaterCoolerStateId, let id = UUID(uuidString: idString) {
            writeCharacteristic(identifier: id, value: mode.rawValue, bridge: bridge)
            return true
        }

        return false
    }

    private func executeLockState(locked: Bool, on service: ServiceData, bridge: Mac2iOS) -> Bool {
        guard let idString = service.lockTargetStateId, let id = UUID(uuidString: idString) else {
            return false
        }
        // 0 = unsecured (unlocked), 1 = secured (locked)
        writeCharacteristic(identifier: id, value: locked ? 1 : 0, bridge: bridge)
        return true
    }
}
