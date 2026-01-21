//
//  AboutSettingsView.swift
//  macOSBridge
//
//  About tab showing version info and links
//

import AppKit

class AboutSettingsView: NSView {

    private let iconView: NSImageView
    private let titleLabel: NSTextField
    private let versionLabel: NSTextField
    private let descriptionLabel: NSTextField
    private let copyrightLabel: NSTextField
    private let websiteButton: NSButton
    private let githubButton: NSButton

    override init(frame frameRect: NSRect) {
        // App icon
        iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown

        // Title
        titleLabel = NSTextField(labelWithString: "Itsyhome")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = DS.Colors.foreground
        titleLabel.alignment = .center

        // Version
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.font = DS.Typography.label
        versionLabel.textColor = DS.Colors.mutedForeground
        versionLabel.alignment = .center

        // Description
        descriptionLabel = NSTextField(labelWithString: "A native macOS menu bar app for controlling\nyour HomeKit smart home devices.")
        descriptionLabel.font = DS.Typography.label
        descriptionLabel.textColor = DS.Colors.foreground
        descriptionLabel.alignment = .center
        descriptionLabel.maximumNumberOfLines = 2

        // Copyright
        copyrightLabel = NSTextField(labelWithString: "MIT License \u{00A9} 2026 Nick Ustinov")
        copyrightLabel.font = DS.Typography.labelSmall
        copyrightLabel.textColor = DS.Colors.mutedForeground
        copyrightLabel.alignment = .center

        // Website button
        websiteButton = NSButton(title: "Website", target: nil, action: nil)
        websiteButton.bezelStyle = .rounded

        // GitHub button
        githubButton = NSButton(title: "GitHub", target: nil, action: nil)
        githubButton.bezelStyle = .rounded

        super.init(frame: frameRect)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(versionLabel)
        addSubview(descriptionLabel)
        addSubview(copyrightLabel)
        addSubview(websiteButton)
        addSubview(githubButton)

        websiteButton.target = self
        websiteButton.action = #selector(openWebsite(_:))
        githubButton.target = self
        githubButton.action = #selector(openGitHub(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let centerX = bounds.width / 2
        let iconSize: CGFloat = 64
        let buttonWidth: CGFloat = 100
        let buttonHeight: CGFloat = 24
        let buttonSpacing: CGFloat = 12

        // Calculate total height needed and center vertically
        let totalContentHeight: CGFloat = iconSize + 8 + 28 + 4 + 17 + 16 + 34 + 16 + 14 + 24 + buttonHeight
        var y = (bounds.height + totalContentHeight) / 2

        // Icon at top
        y -= iconSize
        iconView.frame = NSRect(
            x: centerX - iconSize / 2,
            y: y,
            width: iconSize,
            height: iconSize
        )

        // Title below icon
        y -= 8
        titleLabel.sizeToFit()
        y -= titleLabel.frame.height
        titleLabel.frame = NSRect(
            x: 0,
            y: y,
            width: bounds.width,
            height: titleLabel.frame.height
        )

        // Version below title
        y -= 4
        versionLabel.sizeToFit()
        y -= versionLabel.frame.height
        versionLabel.frame = NSRect(
            x: 0,
            y: y,
            width: bounds.width,
            height: versionLabel.frame.height
        )

        // Description below version
        y -= 16
        descriptionLabel.sizeToFit()
        y -= descriptionLabel.frame.height
        descriptionLabel.frame = NSRect(
            x: 0,
            y: y,
            width: bounds.width,
            height: descriptionLabel.frame.height
        )

        // Copyright below description
        y -= 16
        copyrightLabel.sizeToFit()
        y -= copyrightLabel.frame.height
        copyrightLabel.frame = NSRect(
            x: 0,
            y: y,
            width: bounds.width,
            height: copyrightLabel.frame.height
        )

        // Buttons at bottom, centered
        y -= 24
        let totalButtonWidth = buttonWidth * 2 + buttonSpacing
        let buttonStartX = centerX - totalButtonWidth / 2

        websiteButton.frame = NSRect(
            x: buttonStartX,
            y: y - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )

        githubButton.frame = NSRect(
            x: buttonStartX + buttonWidth + buttonSpacing,
            y: y - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )
    }

    @objc private func openWebsite(_ sender: Any?) {
        if let url = URL(string: "https://itsyhome.app") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGitHub(_ sender: Any?) {
        if let url = URL(string: "https://github.com/nickustinov/itsyhome-macos") {
            NSWorkspace.shared.open(url)
        }
    }
}
