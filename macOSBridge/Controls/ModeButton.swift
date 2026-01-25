//
//  ModeButton.swift
//  macOSBridge
//
//  A pill-shaped button for mode selection with customizable color
//

import AppKit

class ModeButton: NSButton {

    var isSelected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    var isMenuHighlighted: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    var isDisabled: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    var selectedColor: NSColor = DS.Colors.success {
        didSet {
            needsDisplay = true
        }
    }

    init(title: String, color: NSColor = DS.Colors.success) {
        self.selectedColor = color
        super.init(frame: .zero)

        self.title = title
        self.isBordered = false
        self.bezelStyle = .inline
        self.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        self.setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isDisabled else { return }
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Pill shape
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)

        // Background
        if isSelected && !isDisabled {
            selectedColor.setFill()
        } else {
            NSColor.clear.setFill()
        }
        path.fill()

        // Text color
        let dimmedAlpha: CGFloat = isDisabled ? 0.5 : 1.0
        let textColor: NSColor
        if isSelected && !isDisabled {
            textColor = .white
        } else if isMenuHighlighted {
            textColor = NSColor.white.withAlphaComponent(0.9)
        } else {
            textColor = isDark
                ? NSColor(white: 0.9, alpha: dimmedAlpha)
                : NSColor(white: 0.4, alpha: dimmedAlpha)
        }

        // Draw text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let titleSize = title.size(withAttributes: attributes)
        let titleRect = NSRect(
            x: (bounds.width - titleSize.width) / 2,
            y: (bounds.height - titleSize.height) / 2,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: attributes)
    }
}
