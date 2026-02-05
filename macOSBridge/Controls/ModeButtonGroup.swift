//
//  ModeButtonGroup.swift
//  macOSBridge
//
//  A pill-shaped container for grouping ModeButtons with proper dark/light mode support
//

import AppKit

class ModeButtonGroup: NSView {

    private let containerPadding: CGFloat = 2
    private var buttons: [ModeButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bgAlpha: CGFloat = isDark ? 0.2 : 0.08
        layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(bgAlpha).cgColor
        layer?.cornerRadius = bounds.height / 2
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    /// Add a text-based mode button
    func addButton(title: String, color: NSColor = DS.Colors.success, tag: Int = 0) -> ModeButton {
        let btn = ModeButton(title: title, color: color)
        btn.tag = tag
        addButtonInternal(btn)
        return btn
    }

    /// Add an icon-based mode button (SF Symbol)
    func addButton(icon: String, color: NSColor = DS.Colors.success, tag: Int = 0) -> ModeButton {
        let btn = ModeButton(icon: icon, color: color)
        btn.tag = tag
        addButtonInternal(btn)
        return btn
    }

    /// Add an icon-based mode button (Phosphor icon)
    func addButton(phosphorIcon: String, color: NSColor = DS.Colors.success, tag: Int = 0) -> ModeButton {
        let btn = ModeButton(phosphorIcon: phosphorIcon, color: color)
        btn.tag = tag
        addButtonInternal(btn)
        return btn
    }

    /// Add an icon-based mode button (custom image)
    func addButton(image: NSImage, color: NSColor = DS.Colors.success, tag: Int = 0) -> ModeButton {
        let btn = ModeButton(image: image, color: color)
        btn.tag = tag
        addButtonInternal(btn)
        return btn
    }

    private func addButtonInternal(_ button: ModeButton) {
        buttons.append(button)
        addSubview(button)
        layoutButtons()
    }

    private func layoutButtons() {
        guard !buttons.isEmpty else { return }

        let buttonHeight = bounds.height - containerPadding * 2
        let buttonWidth = (bounds.width - containerPadding * 2) / CGFloat(buttons.count)

        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(
                x: containerPadding + CGFloat(index) * buttonWidth,
                y: containerPadding,
                width: buttonWidth,
                height: buttonHeight
            )
        }
    }

    /// Calculate the required width for a given number of buttons
    static func widthForButtons(count: Int, buttonWidth: CGFloat = 36) -> CGFloat {
        return CGFloat(count) * buttonWidth + 4 // 2px padding on each side
    }

    /// Calculate the required width for icon buttons (narrower)
    static func widthForIconButtons(count: Int, buttonWidth: CGFloat = 28) -> CGFloat {
        return CGFloat(count) * buttonWidth + 4
    }
}
