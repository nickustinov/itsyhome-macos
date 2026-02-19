//
//  ShortcutButton.swift
//  macOSBridge
//
//  Button for recording keyboard shortcuts
//

import AppKit

class ShortcutButton: NSButton {

    var isRecording = false {
        didSet { updateAppearance() }
    }

    var shortcut: PreferencesManager.ShortcutData? {
        didSet { updateAppearance() }
    }

    var onShortcutRecorded: ((PreferencesManager.ShortcutData?) -> Void)?

    private var localMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .inline
        isBordered = false
        focusRingType = .none
        font = NSFont.systemFont(ofSize: 11)
        alignment = .right
        target = self
        action = #selector(clicked)
        updateAppearance()
    }

    override func rightMouseDown(with event: NSEvent) {
        if shortcut != nil {
            shortcut = nil
            onShortcutRecorded?(nil)
        }
    }

    private func updateAppearance() {
        if isRecording {
            title = "Press shortcut..."
            contentTintColor = DS.Colors.primary
        } else if let shortcut = shortcut {
            title = shortcut.displayString
            contentTintColor = DS.Colors.foreground
        } else {
            title = String(localized: "shortcut.add", defaultValue: "Add shortcut", bundle: .macOSBridge)
            contentTintColor = DS.Colors.mutedForeground
        }
    }

    @objc private func clicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Escape cancels
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        // Delete/Backspace clears shortcut
        if event.keyCode == 51 || event.keyCode == 117 {
            stopRecording()
            shortcut = nil
            onShortcutRecorded?(nil)
            return
        }

        // Require at least one modifier (Cmd, Ctrl, Option)
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty {
            NSSound.beep()
            return
        }

        let newShortcut = PreferencesManager.ShortcutData(keyCode: event.keyCode, modifiers: modifiers)
        stopRecording()
        shortcut = newShortcut
        onShortcutRecorded?(newShortcut)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }

    override var acceptsFirstResponder: Bool { true }
}

// MARK: - ShortcutData display extension

extension PreferencesManager.ShortcutData {
    var displayString: String {
        var result = ""

        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }

        result += keyCodeToString(keyCode)
        return result
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
            51: "⌫", 53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2",
            120: "F1", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "?"
    }
}
