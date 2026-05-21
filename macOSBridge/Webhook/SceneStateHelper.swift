//
//  SceneStateHelper.swift
//  macOSBridge
//
//  Shared scene state computation + reverse logic. Extracted from
//  SceneMenuItem so the webhook layer can answer "is this scene currently
//  active?" and "deactivate this scene" without duplicating the rules.
//
//  - `isActive(scene:bridge:)` reads each action's target characteristic
//    via `bridge.getCharacteristicValue` and returns true iff every action
//    matches (with the same per-characteristic tolerance the menu UI
//    uses). Returns nil when a scene has no actions — e.g. HA snapshot
//    scenes — so clients can fall back to fire-only behaviour instead of
//    rendering a misleading "off" state.
//
//  - `reverse(scene:bridge:)` mirrors Apple Home's deactivate semantics:
//    only the characteristic types in `reversibleTypes` are touched, and
//    only when the scene's target value actually turned them on (e.g. a
//    scene that closes blinds does nothing when "deactivated" — Apple
//    Home never opens things on deactivate).
//

import Foundation

enum SceneStateHelper {

    /// Characteristic types we'll consider when reversing a scene.
    /// Speakers, alarms, etc. fall outside this set and are left untouched.
    static let reversibleTypes: Set<String> = [
        CharacteristicTypes.powerState,
        CharacteristicTypes.brightness,
        CharacteristicTypes.targetPosition,
        CharacteristicTypes.lockTargetState,
        CharacteristicTypes.targetDoorState,
        CharacteristicTypes.active,
        CharacteristicTypes.rotationSpeed,
    ]

    /// Per-characteristic tolerance when comparing current vs target value.
    /// Brightness / position / fan speed report floats that quantise on the
    /// way back from the device, so strict equality would routinely report
    /// scenes as "not active" right after they fired.
    static func tolerance(for characteristicType: String) -> Double {
        switch characteristicType {
        case CharacteristicTypes.targetPosition,
             CharacteristicTypes.currentPosition,
             CharacteristicTypes.brightness,
             CharacteristicTypes.rotationSpeed:
            return 5.0
        default:
            return 0.01
        }
    }

    /// True iff every action's target matches the device's current value
    /// within tolerance. Returns nil when the scene has no actions at all
    /// (HA snapshot scenes lack a granular action list), so the webhook
    /// can omit the state field and the client falls back to fire-only.
    static func isActive(scene: SceneData, bridge: Mac2iOS?) -> Bool? {
        guard !scene.actions.isEmpty else { return nil }
        guard let bridge = bridge else { return nil }

        for action in scene.actions {
            guard let charId = UUID(uuidString: action.characteristicId),
                  let raw = bridge.getCharacteristicValue(identifier: charId),
                  let current = ValueConversion.toDouble(raw) else {
                // Missing or unreadable value → can't claim the scene is
                // active. Treat as inactive rather than nil so a single
                // unreadable action doesn't suppress state for the whole
                // scene; the user can still re-fire to converge.
                return false
            }
            if abs(current - action.targetValue) >= tolerance(for: action.characteristicType) {
                return false
            }
        }
        return true
    }

    /// Deactivate a scene by writing off-values to each reversible action.
    /// Apple Home behaviour: never opens things on deactivate.
    static func reverse(scene: SceneData, bridge: Mac2iOS?) {
        guard let bridge = bridge else { return }
        for action in scene.actions {
            guard let charId = UUID(uuidString: action.characteristicId),
                  reversibleTypes.contains(action.characteristicType),
                  let offValue = offValue(for: action) else {
                continue
            }
            bridge.writeCharacteristic(identifier: charId, value: offValue)
        }
    }

    /// The "off" value for a single scene action, or nil if reversing it
    /// would be a no-op (scene already had it at the off state) or unsafe
    /// (locks: never unlock; doors: only close if the scene opened).
    static func offValue(for action: SceneActionData) -> Any? {
        let charType = action.characteristicType
        let target = action.targetValue

        switch charType {
        case CharacteristicTypes.powerState, CharacteristicTypes.active:
            return target > 0.5 ? false : nil
        case CharacteristicTypes.brightness, CharacteristicTypes.rotationSpeed:
            return target > 0.5 ? 0 : nil
        case CharacteristicTypes.targetPosition:
            // position > 50 means open; only close if the scene opened.
            return target > 50 ? 0 : nil
        case CharacteristicTypes.lockTargetState:
            // Never unlock as part of a scene deactivate.
            return nil
        case CharacteristicTypes.targetDoorState:
            // 0 = open, 1 = closed. Only close if the scene opened.
            return target < 0.5 ? 1 : nil
        default:
            return target > 0.5 ? 0 : nil
        }
    }
}
