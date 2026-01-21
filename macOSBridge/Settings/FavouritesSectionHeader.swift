//
//  FavouritesSectionHeader.swift
//  macOSBridge
//
//  Section header view for favourites dialog
//

import AppKit

class FavouritesSectionHeader: NSView {

    private let titleLabel: NSTextField
    private let eyeButton: NSButton?

    private static let headerHeight: CGFloat = 32

    var onVisibilityToggled: (() -> Void)?

    init(title: String, icon: NSImage?, isHidden: Bool = false, showEyeButton: Bool = false) {
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DS.Typography.bodyMedium
        titleLabel.textColor = isHidden ? DS.Colors.mutedForeground : DS.Colors.foreground
        titleLabel.alphaValue = isHidden ? 0.5 : 1.0

        if showEyeButton {
            let button = NSButton(frame: .zero)
            button.bezelStyle = .inline
            button.isBordered = false
            button.isEnabled = true
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
            let symbolName = isHidden ? "eye.slash" : "eye"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            button.contentTintColor = isHidden ? DS.Colors.mutedForeground : DS.Colors.foreground
            eyeButton = button
        } else {
            eyeButton = nil
        }

        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: Self.headerHeight))

        addSubview(titleLabel)
        if let eyeButton = eyeButton {
            addSubview(eyeButton)
            eyeButton.target = self
            eyeButton.action = #selector(eyeClicked)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func eyeClicked() {
        onVisibilityToggled?()
    }

    override func layout() {
        super.layout()

        let buttonSize = FavouritesRowLayout.buttonSize
        let leftPadding = FavouritesRowLayout.iconStartX

        // Eye button on the left (aligned with eye buttons in rows)
        if let eyeButton = eyeButton {
            let eyeX = FavouritesRowLayout.leftPadding + buttonSize + FavouritesRowLayout.spacing
            eyeButton.frame = NSRect(
                x: eyeX,
                y: (bounds.height - buttonSize) / 2,
                width: buttonSize,
                height: buttonSize
            )
        }

        titleLabel.frame = NSRect(
            x: leftPadding,
            y: (bounds.height - FavouritesRowLayout.labelHeight) / 2,
            width: bounds.width - leftPadding - 8,
            height: FavouritesRowLayout.labelHeight
        )
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.headerHeight)
    }
}
