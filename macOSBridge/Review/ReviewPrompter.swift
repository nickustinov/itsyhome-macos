//
//  ReviewPrompter.swift
//  macOSBridge
//
//  Asks for an App Store rating when the menu closes after the user changed something in it, if
//  `ReviewPromptRule` allows. Every day the menu is opened counts as a day of use.
//
//  The menu is an NSMenu, which has no view controller for `AppStore.requestReview(in:)`
//  (FB14887376), so the prompt uses `SKStoreReviewController.requestReview()` – deprecated in
//  macOS 15, but the only request that needs none. The app is activated first: since macOS 14 a
//  prompt from an app that isn't active can open behind other windows.
//

import AppKit
import StoreKit

final class ReviewPrompter {
    private let rule: ReviewPromptRule
    private let version: String
    private let present: () -> Void
    private var changedInMenu = false

    init(rule: ReviewPromptRule = ReviewPromptRule(defaults: .standard),
         version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
         present: @escaping () -> Void = ReviewPrompter.askAppStore) {
        self.rule = rule
        self.version = version
        self.present = present
    }

    func menuWillOpen(now: Date = Date()) {
        changedInMenu = false
        rule.recordUse(on: now, version: version)
    }

    /// A menu item changed an accessory (`.characteristicDidChangeLocally`). Only changes made
    /// between `menuWillOpen` and `menuDidClose` lead to a prompt.
    func userChangedSomething() {
        changedInMenu = true
    }

    func menuDidClose(now: Date = Date()) {
        guard changedInMenu else { return }
        changedInMenu = false
        guard rule.shouldPrompt(now: now) else { return }
        rule.recordPrompt(now: now)
        present()
    }

    /// Half a second later, once the menu has gone.
    static func askAppStore() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            NSApp.activate()
            SKStoreReviewController.requestReview()
        }
    }
}
