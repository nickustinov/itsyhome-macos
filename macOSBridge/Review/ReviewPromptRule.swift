//
//  ReviewPromptRule.swift
//  macOSBridge
//
//  When Itsyhome asks for an App Store rating – Itsytv for Mac's rule (`ReviewPromptRule` in
//  itsytv-macos), for a menu bar app that launches once and runs for weeks: days the menu was
//  opened count instead of launch days. Asked once:
//  - the menu was opened on at least `minDaysUsed` different days
//  - the current version was first used `versionGrace` ago or more
//  - the last ask was `cooldown` ago or more
//

import Foundation

struct ReviewPromptRule {
    static let minDaysUsed = 3
    static let versionGrace: TimeInterval = 48 * 3600
    static let cooldown: TimeInterval = 120 * 86_400

    private enum Key {
        static let daysUsed = "review.daysUsed"
        static let lastUseDay = "review.lastUseDay"
        static let lastSeenVersion = "review.lastSeenVersion"
        static let versionFirstSeen = "review.versionFirstSeen"
        static let lastPrompt = "review.lastPrompt"
    }

    let defaults: UserDefaults
    var calendar: Calendar = .current

    func recordUse(on date: Date, version: String) {
        let day = calendar.startOfDay(for: date)
        if (defaults.object(forKey: Key.lastUseDay) as? Date) != day {
            defaults.set(day, forKey: Key.lastUseDay)
            defaults.set(defaults.integer(forKey: Key.daysUsed) + 1, forKey: Key.daysUsed)
        }
        if defaults.string(forKey: Key.lastSeenVersion) != version {
            defaults.set(version, forKey: Key.lastSeenVersion)
            defaults.set(date, forKey: Key.versionFirstSeen)
        }
    }

    func shouldPrompt(now: Date) -> Bool {
        guard defaults.integer(forKey: Key.daysUsed) >= Self.minDaysUsed else { return false }
        if let firstSeen = defaults.object(forKey: Key.versionFirstSeen) as? Date,
           now.timeIntervalSince(firstSeen) < Self.versionGrace { return false }
        if let last = defaults.object(forKey: Key.lastPrompt) as? Date,
           now.timeIntervalSince(last) < Self.cooldown { return false }
        return true
    }

    func recordPrompt(now: Date) {
        defaults.set(now, forKey: Key.lastPrompt)
    }
}
