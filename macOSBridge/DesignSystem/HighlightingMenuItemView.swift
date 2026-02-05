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
            options: [.mouseEnteredAndExited, .activeAlways],
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
        updateTextColors(highlighted: true)
        needsDisplay = true
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        updateTextColors(highlighted: false)
        needsDisplay = true
        onMouseExit?()
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

    override func mouseUp(with event: NSEvent) {
        guard let action = onAction else { return }

        // Don't trigger action if click was on a control that handles its own clicks
        let location = convert(event.locationInWindow, from: nil)
        if let hitView = hitTest(location),
           hitView is ToggleSwitch || hitView is ModernSlider || hitView is CoverControl ||
           hitView.superview is CoverControl {
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
