//
//  ModeButton.swift
//  macOSBridge
//
//  A pill-shaped button for mode selection with customizable color
//  Supports both text labels and SF Symbol icons
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

    private var iconName: String?
    private var usePhosphorIcon: Bool = false
    private var customImage: NSImage?

    /// Create a text-based mode button
    init(title: String, color: NSColor = DS.Colors.success) {
        self.selectedColor = color
        super.init(frame: .zero)

        self.title = title
        self.isBordered = false
        self.bezelStyle = .inline
        self.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        self.setButtonType(.momentaryChange)
    }

    /// Create an icon-based mode button using SF Symbol
    init(icon: String, color: NSColor = DS.Colors.success) {
        self.selectedColor = color
        self.iconName = icon
        super.init(frame: .zero)

        self.title = ""
        self.isBordered = false
        self.bezelStyle = .inline
        self.setButtonType(.momentaryChange)
    }

    /// Create an icon-based mode button using Phosphor icon
    init(phosphorIcon: String, color: NSColor = DS.Colors.success) {
        self.selectedColor = color
        self.iconName = phosphorIcon
        self.usePhosphorIcon = true
        super.init(frame: .zero)

        self.title = ""
        self.isBordered = false
        self.bezelStyle = .inline
        self.setButtonType(.momentaryChange)
    }

    /// Create an icon-based mode button using custom image
    init(image: NSImage, color: NSColor = DS.Colors.success) {
        self.selectedColor = color
        self.customImage = image
        self.customImage?.isTemplate = true  // Enable tinting
        super.init(frame: .zero)

        self.title = ""
        self.isBordered = false
        self.bezelStyle = .inline
        self.setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Update the icon (for toggling between states like clockwise/counter-clockwise)
    func setIcon(_ name: String) {
        self.iconName = name
        needsDisplay = true
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

        // Content color
        let dimmedAlpha: CGFloat = isDisabled ? 0.5 : 1.0
        let contentColor: NSColor
        if isSelected && !isDisabled {
            contentColor = .white
        } else if isMenuHighlighted {
            contentColor = NSColor.white.withAlphaComponent(0.9)
        } else {
            contentColor = isDark
                ? NSColor(white: 0.9, alpha: dimmedAlpha)
                : NSColor(white: 0.4, alpha: dimmedAlpha)
        }

        if let customImage = customImage {
            // Draw custom image with tinting
            let tintedImage = customImage.copy() as! NSImage
            tintedImage.lockFocus()
            contentColor.set()
            NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
            tintedImage.unlockFocus()

            // Scale to fit
            let targetSize: CGFloat = 14
            let scale = targetSize / max(tintedImage.size.width, tintedImage.size.height)
            let scaledWidth = tintedImage.size.width * scale
            let scaledHeight = tintedImage.size.height * scale

            let imageRect = NSRect(
                x: (bounds.width - scaledWidth) / 2,
                y: (bounds.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
            tintedImage.draw(in: imageRect)
        } else if let iconName = iconName {
            // Draw icon
            let image: NSImage?
            if usePhosphorIcon {
                image = PhosphorIcon.regular(iconName)
            } else {
                image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            }

            if let baseImage = image {
                let configuredImage: NSImage
                if usePhosphorIcon {
                    // Phosphor icons - resize to fit
                    configuredImage = baseImage
                } else {
                    // SF Symbols - use symbol configuration
                    let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
                    configuredImage = baseImage.withSymbolConfiguration(config) ?? baseImage
                }

                // Tint the image
                let tintedImage = configuredImage.copy() as! NSImage
                tintedImage.lockFocus()
                contentColor.set()
                NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
                tintedImage.unlockFocus()

                // Scale for Phosphor icons
                let targetSize: CGFloat = usePhosphorIcon ? 14 : tintedImage.size.width
                let scale = targetSize / max(tintedImage.size.width, tintedImage.size.height)
                let scaledWidth = tintedImage.size.width * scale
                let scaledHeight = tintedImage.size.height * scale

                let imageRect = NSRect(
                    x: (bounds.width - scaledWidth) / 2,
                    y: (bounds.height - scaledHeight) / 2,
                    width: scaledWidth,
                    height: scaledHeight
                )
                tintedImage.draw(in: imageRect)
            }
        } else {
            // Draw text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: contentColor,
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
}
