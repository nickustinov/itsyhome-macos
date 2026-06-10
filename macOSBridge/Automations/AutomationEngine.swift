//
//  AutomationEngine.swift
//  macOSBridge
//
//  Evaluates automations. Taps the characteristic-change chokepoint
//  (MacOSController.updateMenuItems), arms per-automation duration timers, and on
//  activation drives a virtual sensor via VirtualControl with a re-pulse loop.
//  The pure decision (desiredPhase) is split out for testing; timers + actions
//  wrap it. Main-thread confined.
//
import Foundation

/// What a automation wants to do in response to a characteristic value. Pure +
/// testable; the engine maps these onto timers/actions.
enum AutomationPhase: Equatable {
    case idle                  // trigger not satisfied
    case arming(seconds: Int)  // satisfied, wait for the duration
    case activeNow             // satisfied, no duration -> activate immediately
}

enum AutomationEvaluation {
    /// nil = this characteristic is irrelevant to the automation (leave it as-is).
    static func desiredPhase(for automation: Automation, characteristic id: UUID, value: Any) -> AutomationPhase? {
        guard automation.enabled else { return .idle }
        guard case .accessoryState(let t) = automation.trigger, t.characteristicId == id else { return nil }
        guard t.isSatisfied(by: value) else { return .idle }
        if let seconds = automation.durationSeconds { return .arming(seconds: seconds) }
        return .activeNow
    }
}

final class AutomationEngine {
    static let shared = AutomationEngine()

    /// Reads a characteristic's current value (set from MacOSController) so
    /// automations whose trigger is already true at launch arm correctly.
    var valueProvider: ((UUID) -> Any?)?

    /// Test seam: how an active/inactive automation drives its action. Production
    /// default sets the target virtual sensor's state via VirtualControl.
    private let applyActive: (SetVirtualSensorAction, Bool) -> Void

    /// Test seam: whether a target virtual sensor still exists.
    private let deviceExists: (UUID) -> Bool

    private var automations: [Automation] = []
    private var runtimes: [UUID: Runtime] = [:]
    private var started = false

    init(applyActive: @escaping (SetVirtualSensorAction, Bool) -> Void = AutomationEngine.defaultApply,
         deviceExists: @escaping (UUID) -> Bool = AutomationEngine.defaultDeviceExists) {
        self.applyActive = applyActive
        self.deviceExists = deviceExists
    }

    private final class Runtime {
        var armTimer: Timer?
        var pulseTimer: Timer?
        var active = false
        var armedUntil: Date?
    }

    // MARK: Lifecycle

    func startIfEnabled() {
        onMain {
            guard !self.started else { return }
            // Automations drive virtual HAP sensors, which only work via the
            // Apple Home round-trip in HomeKit mode - inert in Home Assistant mode.
            guard PlatformManager.shared.selectedPlatform == .homeKit else { return }
            guard ProStatusCache.shared.isPro else { return }
            self.started = true
            self.load(AutomationStore.shared.automations)
        }
    }

    // MARK: Runtime state (for the UI)

    enum AutomationRuntimeState: Equatable { case idle, armed, active }

    /// When each automation last activated (in-memory; resets on restart).
    private(set) var lastActivated: [UUID: Date] = [:]

    func runtimeState(automationId: UUID) -> AutomationRuntimeState {
        guard let rt = runtimes[automationId] else { return .idle }
        if rt.active { return .active }
        if rt.armTimer != nil { return .armed }
        return .idle
    }

    /// Seconds until an armed automation fires, or nil if not arming.
    func armedRemaining(automationId: UUID) -> Int? {
        guard let rt = runtimes[automationId], rt.armTimer != nil, let until = rt.armedUntil else { return nil }
        return max(0, Int(until.timeIntervalSinceNow.rounded()))
    }

    func reload() { onMain { if self.started { self.load(AutomationStore.shared.automations) } } }

    func stop() {
        onMain {
            for (_, rt) in self.runtimes { rt.armTimer?.invalidate(); rt.pulseTimer?.invalidate() }
            self.runtimes.removeAll()
            self.started = false
        }
    }

    /// Reset all runtimes and (re)evaluate current values so already-true
    /// triggers arm. Internal so tests can drive it directly.
    func load(_ automations: [Automation]) {
        onMain {
            for (_, rt) in self.runtimes { rt.armTimer?.invalidate(); rt.pulseTimer?.invalidate() }
            self.runtimes.removeAll()
            self.automations = automations
            for automation in automations where automation.enabled {
                self.runtimes[automation.id] = Runtime()
                if case .accessoryState(let t) = automation.trigger,
                   let current = self.valueProvider?(t.characteristicId) {
                    self.evaluate(automation: automation, value: current)
                }
            }
        }
    }

    // MARK: Change handling

    func handleCharacteristicChange(id: UUID, value: Any) {
        onMain {
            for automation in self.automations where automation.enabled {
                if case .accessoryState(let t) = automation.trigger, t.characteristicId == id {
                    self.evaluate(automation: automation, value: value)
                }
            }
        }
    }

    private func evaluate(automation: Automation, value: Any) {
        guard let rt = runtimes[automation.id] else { return }
        // Skip automations whose target virtual sensor no longer exists - they can't run.
        if case .setVirtualSensor(let a)? = automation.actions.first, !deviceExists(a.deviceId) {
            rt.armTimer?.invalidate(); rt.armTimer = nil; rt.armedUntil = nil
            if rt.active { deactivate(automation: automation, rt: rt) }
            return
        }
        switch AutomationEvaluation.desiredPhase(for: automation, characteristic: triggerCharId(automation), value: value) {
        case .idle, .none:
            rt.armTimer?.invalidate(); rt.armTimer = nil; rt.armedUntil = nil
            if rt.active { deactivate(automation: automation, rt: rt) }
        case .arming(let seconds):
            guard !rt.active, rt.armTimer == nil else { return }
            rt.armedUntil = Date().addingTimeInterval(max(0.01, Double(seconds)))
            rt.armTimer = Timer.scheduledTimer(withTimeInterval: max(0.01, Double(seconds)), repeats: false) { [weak self, weak rt] _ in
                guard let self, let rt else { return }
                rt.armTimer = nil; rt.armedUntil = nil
                self.activate(automation: automation, rt: rt)
            }
        case .activeNow:
            if !rt.active { activate(automation: automation, rt: rt) }
        }
    }

    private func triggerCharId(_ automation: Automation) -> UUID {
        if case .accessoryState(let t) = automation.trigger { return t.characteristicId }
        return UUID()
    }

    // MARK: Activation

    private func activate(automation: Automation, rt: Runtime) {
        rt.active = true
        lastActivated[automation.id] = Date()
        for action in automation.actions {
            if case .setVirtualSensor(let a) = action {
                applyActive(a, true)
                if a.rePulse.enabled { startPulse(action: a, rt: rt) }
            }
        }
    }

    private func deactivate(automation: Automation, rt: Runtime) {
        rt.active = false
        rt.pulseTimer?.invalidate(); rt.pulseTimer = nil
        for action in automation.actions {
            if case .setVirtualSensor(let a) = action { applyActive(a, false) }
        }
    }

    /// Momentary OFF duration of a re-pulse "blip". Apple Home automations fire
    /// on a change, not a held state, so each pulse drives the sensor OFF then
    /// back ON after this delay to produce a fresh edge. Kept short so it reads
    /// as a transient blip, not a real "cleared" state.
    private static let pulseBlipSeconds: TimeInterval = 1

    private func startPulse(action: SetVirtualSensorAction, rt: Runtime) {
        rt.pulseTimer?.invalidate()
        // Clamp the interval so a full OFF -> (blip) -> ON cycle always finishes
        // before the next pulse fires. Without this, an interval shorter than the
        // blip would interleave the off/on writes and could leave the sensor in
        // the wrong state.
        let interval = max(Self.pulseBlipSeconds + 1, Double(action.rePulse.intervalSeconds))
        rt.pulseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Blip: OFF now, back ON after pulseBlipSeconds, so Apple Home sees a fresh edge.
            self.applyActive(action, false)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.pulseBlipSeconds) { self.applyActive(action, true) }
        }
    }

    // MARK: Helpers

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    static func defaultApply(_ action: SetVirtualSensorAction, _ on: Bool) {
        guard let device = VirtualDeviceStore.shared.device(id: action.deviceId) else { return }
        VirtualControl.setState(device, on: on)
    }

    static func defaultDeviceExists(_ id: UUID) -> Bool {
        VirtualDeviceStore.shared.device(id: id) != nil
    }
}
