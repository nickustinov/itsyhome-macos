//
//  HotkeyManager.swift
//  macOSBridge
//
//  Global hotkey manager using Carbon APIs
//

import AppKit
import Carbon

final class HotkeyManager {

    static let shared = HotkeyManager()

    /// Callback when a hotkey is triggered, passes the favourite ID
    var onHotkeyTriggered: ((String) -> Void)?

    private var registeredHotkeys: [UInt32: (id: EventHotKeyID, ref: EventHotKeyRef?, favouriteId: String)] = [:]
    private var nextHotkeyId: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        installEventHandler()
    }

    deinit {
        unregisterAllHotkeys()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }

    // MARK: - Public API

    /// Register all shortcuts from preferences
    func registerShortcuts() {
        unregisterAllHotkeys()

        let shortcuts = PreferencesManager.shared.shortcuts
        for (favouriteId, shortcut) in shortcuts {
            registerHotkey(shortcut, for: favouriteId)
        }
    }

    /// Unregister all hotkeys
    func unregisterAllHotkeys() {
        for (_, hotkey) in registeredHotkeys {
            if let ref = hotkey.ref {
                UnregisterEventHotKey(ref)
            }
        }
        registeredHotkeys.removeAll()
    }

    // MARK: - Private

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotKeyEvent(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // Use GetEventDispatcherTarget() for global hotkeys in menu bar apps
        InstallEventHandler(GetEventDispatcherTarget(), handlerCallback, 1, &eventType, selfPtr, &eventHandlerRef)
    }

    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else {
            return OSStatus(eventNotHandledErr)
        }

        var hotkeyId = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyId
        )

        guard status == noErr else {
            return status
        }

        if let hotkey = registeredHotkeys[hotkeyId.id] {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyTriggered?(hotkey.favouriteId)
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    private func registerHotkey(_ shortcut: PreferencesManager.ShortcutData, for favouriteId: String) {
        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        var carbonModifiers: UInt32 = 0
        if shortcut.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if shortcut.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if shortcut.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if shortcut.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let eventHotkeyId = EventHotKeyID(signature: OSType(0x4954_5359), id: hotkeyId)  // "ITSY"
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers,
            eventHotkeyId,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            registeredHotkeys[hotkeyId] = (id: eventHotkeyId, ref: hotkeyRef, favouriteId: favouriteId)
        }
    }
}
