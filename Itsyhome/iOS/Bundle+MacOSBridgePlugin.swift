//
//  Bundle+MacOSBridgePlugin.swift
//  Itsyhome
//
//  The macOSBridge plugin bundle, for loading it and for Catalyst-side strings
//

import Foundation

extension Bundle {
    /// The macOSBridge plugin in Contents/PlugIns, or nil if it's missing.
    static let macOSBridgePlugin: Bundle? = Bundle.main.builtInPlugInsURL
        .flatMap { Bundle(url: $0.appendingPathComponent("macOSBridge.bundle")) }

    /// The plugin owns Localizable.xcstrings, so Catalyst-side user-facing
    /// strings localize through it. Falls back to the main bundle (English
    /// default values) if the plugin is missing.
    static let macOSBridge: Bundle = macOSBridgePlugin ?? .main
}
