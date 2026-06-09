//
//  AutomationDraft.swift
//  macOSBridge
//
//  Mutable builder backing the WHEN/FOR/THEN form; validates and produces an Automation.
//
import Foundation

struct AutomationDraft {
    var id: UUID?            // nil = new automation
    var name: String
    var trigger: AccessoryStateTrigger?
    var durationSeconds: Int
    var actionDeviceId: UUID?
    var rePulseEnabled: Bool
    var rePulseInterval: Int

    init(id: UUID? = nil, name: String, trigger: AccessoryStateTrigger?,
         durationSeconds: Int, actionDeviceId: UUID?,
         rePulseEnabled: Bool = true, rePulseInterval: Int = 300) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.durationSeconds = durationSeconds
        self.actionDeviceId = actionDeviceId
        self.rePulseEnabled = rePulseEnabled
        self.rePulseInterval = rePulseInterval
    }

    func validationError() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Name is required." }
        if trigger == nil { return "Choose a trigger." }
        if actionDeviceId == nil { return "Choose a virtual sensor to drive." }
        return nil
    }

    /// Assumes a valid draft (call after validationError() == nil).
    func build() -> Automation {
        let actions: [AutomationAction] = actionDeviceId.map {
            [.setVirtualSensor(SetVirtualSensorAction(
                deviceId: $0, rePulse: .init(enabled: rePulseEnabled, intervalSeconds: rePulseInterval)))]
        } ?? []
        let t = trigger ?? AccessoryStateTrigger(
            characteristicId: UUID(), accessoryName: "", characteristicLabel: "", comparator: .equal, value: 1)
        return Automation(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled: true,
            trigger: .accessoryState(t),
            conditions: durationSeconds > 0 ? [.duration(seconds: durationSeconds)] : [],
            actions: actions)
    }
}
