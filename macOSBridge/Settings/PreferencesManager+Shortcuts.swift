//
//  PreferencesManager+Shortcuts.swift
//  macOSBridge
//
//  Keyboard shortcuts management
//

import AppKit
import Foundation

extension PreferencesManager {

    // MARK: - Shortcuts (per-home)

    /// Shortcut data: keyCode (UInt16) and modifiers (UInt)
    struct ShortcutData: Codable, Equatable {
        let keyCode: UInt16
        let modifiers: UInt  // NSEvent.ModifierFlags.rawValue

        var modifierFlags: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(rawValue: modifiers)
        }

        init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifiers = modifiers.rawValue
        }
    }

    private var shortcutsKey: String {
        homeKey("shortcuts")
    }

    /// Get all shortcuts for current home
    var shortcuts: [String: ShortcutData] {
        get {
            guard let data = defaults.data(forKey: shortcutsKey),
                  let dict = try? JSONDecoder().decode([String: ShortcutData].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: shortcutsKey)
                postNotification()
            }
        }
    }

    func shortcut(for favouriteId: String) -> ShortcutData? {
        shortcuts[favouriteId]
    }

    func setShortcut(_ shortcut: ShortcutData?, for favouriteId: String) {
        var current = shortcuts
        current[favouriteId] = shortcut
        shortcuts = current
    }

    func removeShortcut(for favouriteId: String) {
        setShortcut(nil, for: favouriteId)
    }

    /// Find favourite ID by shortcut (for lookup when hotkey triggered)
    func favouriteId(for shortcut: ShortcutData) -> String? {
        shortcuts.first { $0.value == shortcut }?.key
    }
}
