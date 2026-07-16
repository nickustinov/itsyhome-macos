//
//  HighlightingMenuItemView.swift
//  macOSBridge
//
//  Container view for custom menu items that draws the standard
//  menu selection highlight when the mouse hovers over the item.
//

import AppKit

class HighlightingMenuItemView: NSView {

    var onAction: (() -> Void)?
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var closesMenuOnAction: Bool = true

    /// Whether the menu item is currently highlighted (mouse inside)
    private(set) var isHighlighted: Bool = false

    private var isMouseInside = false
    private var trackingArea: NSTrackingArea?
    private var originalTextColors: [ObjectIdentifier: NSColor] = [:]
    private var originalTintColors: [ObjectIdentifier: NSColor] = [:]

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            // enabledDuringMouseDrag gives native menu behaviour for the
            // press–drag–release gesture: rows highlight under a pressed
            // pointer (including a press that started on the status item).
            options: [.mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Reset highlight state when menu closes (window becomes nil)
        // or when menu reopens (window changes)
        if isMouseInside {
            isMouseInside = false
            updateTextColors(highlighted: false)
            needsDisplay = true
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        isHighlighted = true
        updateTextColors(highlighted: true)
        needsDisplay = true
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        isHighlighted = false
        updateTextColors(highlighted: false)
        needsDisplay = true
        onMouseExit?()
    }

    /// Call this after updating text labels to re-apply highlight colors if needed
    func refreshHighlightColors() {
        if isHighlighted {
            // First restore all colors to originals (so labels not touched by updateUI get restored)
            updateTextColors(highlighted: false)
            // Clear cached colors so they get re-captured with new values
            originalTextColors.removeAll()
            originalTintColors.removeAll()
            // Re-apply highlighting with fresh captures
            updateTextColors(highlighted: true)
        }
    }

    private func updateTextColors(highlighted: Bool) {
        updateSubviewColors(in: self, highlighted: highlighted)
    }

    private func updateSubviewColors(in view: NSView, highlighted: Bool) {
        for subview in view.subviews {
            // Skip controls that manage their own appearance
            if subview is ToggleSwitch || subview is ModernSlider || subview is CoverControl {
                continue
            }

            if let modeButton = subview as? ModeButton {
                modeButton.isMenuHighlighted = highlighted
            } else if let textField = subview as? NSTextField {
                let key = ObjectIdentifier(textField)
                if highlighted {
                    if originalTextColors[key] == nil {
                        originalTextColors[key] = textField.textColor
                    }
                    textField.textColor = .selectedMenuItemTextColor
                } else if let original = originalTextColors[key] {
                    textField.textColor = original
                }
            } else if let imageView = subview as? NSImageView {
                let key = ObjectIdentifier(imageView)
                if highlighted {
                    if originalTintColors[key] == nil {
                        originalTintColors[key] = imageView.contentTintColor
                    }
                    imageView.contentTintColor = .selectedMenuItemTextColor
                } else if let original = originalTintColors[key] {
                    imageView.contentTintColor = original
                }
            } else if let button = subview as? NSButton {
                let key = ObjectIdentifier(button)
                if highlighted {
                    if originalTintColors[key] == nil {
                        originalTintColors[key] = button.contentTintColor
                    }
                    button.contentTintColor = .selectedMenuItemTextColor
                } else if let original = originalTintColors[key] {
                    button.contentTintColor = original
                }
            }

            // Recurse into child views
            if !(subview is NSControl) || subview is ModeButton {
                updateSubviewColors(in: subview, highlighted: highlighted)
            }
        }
    }

    /// The item highlighted by a press–drag gesture. Coordinated statically
    /// because AppKit delivers mouseDragged only to the view that received
    /// the mouseDown – the tracking areas of the rows being dragged over
    /// never hear about the pointer.
    private static weak var dragHighlightedItem: HighlightingMenuItemView?

    override func mouseDragged(with event: NSEvent) {
        Self.updateDragHighlight(to: Self.itemView(at: NSEvent.mouseLocation))
    }

    private static func updateDragHighlight(to target: HighlightingMenuItemView?) {
        guard dragHighlightedItem !== target else { return }
        dragHighlightedItem?.setDragHighlight(false)
        dragHighlightedItem = target
        target?.setDragHighlight(true)
    }

    private func setDragHighlight(_ on: Bool) {
        guard isMouseInside != on else { return }
        isMouseInside = on
        isHighlighted = on
        updateTextColors(highlighted: on)
        needsDisplay = true
        on ? onMouseEnter?() : onMouseExit?()
    }

    override func mouseUp(with event: NSEvent) {
        Self.dragHighlightedItem = nil
        // Native menu semantics: the item under the pointer at release is
        // the one that activates, even when the press started on another
        // item (press–drag–release). AppKit delivers mouseUp to the view
        // that received the mouseDown, so route to the view actually under
        // the pointer – possibly in another window (submenus). Releasing
        // over no item does nothing, also matching native menus.
        Self.itemView(at: NSEvent.mouseLocation)?.performRelease(atScreenPoint: NSEvent.mouseLocation)
    }

    /// The menu item view under a screen point, searching front-to-back
    /// across the app's windows (each open submenu is its own window).
    private static func itemView(at screenPoint: NSPoint) -> HighlightingMenuItemView? {
        var candidates = NSApp.orderedWindows
        // Menu windows aren't always part of orderedWindows – ask the window
        // server for the topmost window at the point as well.
        let number = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0)
        if let top = NSApp.window(withWindowNumber: number) {
            candidates.insert(top, at: 0)
        }
        for window in candidates where window.isVisible && window.frame.contains(screenPoint) {
            guard let frameView = window.contentView?.superview ?? window.contentView else { continue }
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            var view = frameView.hitTest(frameView.convert(windowPoint, from: nil))
            while let current = view {
                if let item = current as? HighlightingMenuItemView { return item }
                view = current.superview
            }
        }
        return nil
    }

    private func performRelease(atScreenPoint screenPoint: NSPoint) {
        guard let action = onAction, let window = window else { return }

        // Don't trigger the row action if the release was on a control that
        // handles its own clicks
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let location = convert(windowPoint, from: nil)
        if let hitView = hitTest(location),
           hitView is ToggleSwitch || hitView is ModernSlider || hitView is CoverControl ||
           hitView is ClickableColorCircleView || hitView.superview is CoverControl {
            return
        }

        if closesMenuOnAction {
            isMouseInside = false
            updateTextColors(highlighted: false)
            needsDisplay = true
            enclosingMenuItem?.menu?.cancelTracking()
            action()
        } else {
            // Restore original colors, perform action, then re-save post-action colors
            updateTextColors(highlighted: false)
            action()
            originalTextColors.removeAll()
            originalTintColors.removeAll()
            updateTextColors(highlighted: true)
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isMouseInside {
            let rect = bounds.insetBy(dx: 4, dy: 0)
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        }
    }
}
