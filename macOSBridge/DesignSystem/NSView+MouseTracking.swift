//
//  NSView+MouseTracking.swift
//  macOSBridge
//
//  Drag tracking for controls inside menu item rows
//

import AppKit

extension NSView {
    /// Follows a drag until mouse-up, consuming the events. Menus deliver mouse-up to
    /// whatever is under the cursor, so without this a release outside the view would
    /// reach the enclosing menu item row and trigger its action.
    func trackMouse(from event: NSEvent, handler: (NSEvent, _ isFinal: Bool) -> Void) {
        handler(event, false)
        guard let window = window else { return }

        while let next = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            if next.type == .leftMouseUp {
                handler(next, true)
                return
            }
            handler(next, false)
        }
    }

    /// Follows a press until mouse-up and returns whether it ended inside the view.
    func trackClick(from event: NSEvent) -> Bool {
        var releasedInside = false
        trackMouse(from: event) { next, isFinal in
            if isFinal {
                releasedInside = bounds.contains(convert(next.locationInWindow, from: nil))
            }
        }
        return releasedInside
    }
}
