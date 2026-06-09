//
//  VirtualControl.swift
//  macOSBridge
//
//  Maps ItsyHome's control verbs onto a read-only virtual sensor's boolean
//  state, so virtual devices respond to the same on/off/toggle/open/close
//  endpoints as real accessories (no /virtual namespace).
//
import Foundation

enum VirtualControl {
    /// on -> true, off -> false, open (setPosition 100) -> true,
    /// close (setPosition 0) -> false, other positions -> >= 50.
    /// Returns nil for actions that do not apply to a binary sensor.
    static func boolean(for action: Action) -> Bool? {
        switch action {
        case .turnOn: return true
        case .turnOff: return false
        case .setPosition(let p): return p >= 50
        default: return nil
        }
    }

    static func nextState(forToggleFrom current: Bool) -> Bool { !current }

    /// Set a virtual device's state: update the store and push to HAP. Apple
    /// Home then notifies HomeKit clients (including ItsyHome), so the menu and
    /// events feed update via the round-trip. Used by both the webhook verbs
    /// and the Settings per-device toggle.
    static func setState(_ device: VirtualDevice, on: Bool) {
        VirtualDeviceStore.shared.setState(id: device.id, on: on)
        Task { await VirtualBridgeService.shared.setState(aid: device.aid, on: on) }
    }
}
