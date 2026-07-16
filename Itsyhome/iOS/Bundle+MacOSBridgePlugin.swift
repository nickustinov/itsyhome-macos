//
//  Bundle+MacOSBridgePlugin.swift
//  Itsyhome
//
//  Localization bundle for Catalyst-side user-facing strings
//

import Foundation

extension Bundle {
    /// The macOSBridge plugin bundle – it owns Localizable.xcstrings, so
    /// Catalyst-side user-facing strings localize through it. Checked in the
    /// same two locations as AppDelegate.loadMacOSPlugin (xcodegen places the
    /// bundle in Resources in some configurations). Falls back to the main
    /// bundle (English default values) if the plugin isn't found.
    static let macOSBridge: Bundle = {
        let bundleFileName = "macOSBridge.bundle"
        for base in [Bundle.main.builtInPlugInsURL, Bundle.main.resourceURL] {
            if let url = base?.appendingPathComponent(bundleFileName),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return .main
    }()
}
