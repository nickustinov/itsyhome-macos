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

    /// Color when selected (defaults to green)
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

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds

        // Pill shape (fully rounded)
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)

        // Fill background
        if isSelected {
            selectedColor.setFill()
        } else {
            NSColor.clear.setFill()
        }
        path.fill()

        // Draw title
        let textColor: NSColor = isSelected ? .white : .tertiaryLabelColor
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
