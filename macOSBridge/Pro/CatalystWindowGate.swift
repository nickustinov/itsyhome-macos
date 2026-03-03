//
//  CatalystWindowGate.swift
//  macOSBridge
//
//  Controls whether the hidden 1×1 Catalyst window is allowed to order
//  into the window list. Kept false by default so tiling window managers
//  (AeroSpace, yabai, etc.) and Mission Control never see it. Set to true
//  briefly when StoreKit needs to present a purchase sheet.
//

import AppKit

enum CatalystWindowGate {
    @MainActor static var allowOrdering = false

    /// Find the hidden 1×1 Catalyst window and order it front so StoreKit
    /// has a presentation context. Only works when `allowOrdering` is true.
    @MainActor static func orderCatalystWindow() {
        for window in NSApplication.shared.windows where window.frame.size.width <= 1 || window.frame.size.height <= 1 {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    /// Order the Catalyst window out of the window list after a purchase.
    @MainActor static func hideCatalystWindow() {
        for window in NSApplication.shared.windows where window.frame.size.width <= 1 || window.frame.size.height <= 1 {
            window.orderOut(nil)
            return
        }
    }
}
