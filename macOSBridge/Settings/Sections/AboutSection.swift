//
//  AboutSection.swift
//  macOSBridge
//
//  About section
//

import AppKit

class AboutSection: SettingsCard {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        stackView.alignment = .centerX
        stackView.spacing = 12

        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)

        // App icon
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        stackView.addArrangedSubview(iconView)

        // App name
        let nameLabel = createLabel("Itsyhome", style: .title)
        nameLabel.alignment = .center
        stackView.addArrangedSubview(nameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = createLabel("Version \(version) (\(build))", style: .subtitle)
        versionLabel.alignment = .center
        stackView.addArrangedSubview(versionLabel)

        // Description
        let descLabel = createLabel("A lightweight HomeKit controller for your menu bar", style: .subtitle)
        descLabel.alignment = .center
        stackView.addArrangedSubview(descLabel)

        // Spacer
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer2)

        // Links
        let linksStack = NSStackView()
        linksStack.orientation = .horizontal
        linksStack.spacing = 16

        let websiteButton = createLinkButton(title: "Website", url: "https://itsyhome.app")
        let githubButton = createLinkButton(title: "GitHub", url: "https://github.com/nickustinov/itsyhome")

        linksStack.addArrangedSubview(websiteButton)
        linksStack.addArrangedSubview(githubButton)

        stackView.addArrangedSubview(linksStack)

        // Spacer
        let spacer3 = NSView()
        spacer3.translatesAutoresizingMaskIntoConstraints = false
        spacer3.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer3)

        // Footer
        let footerLabel = createLabel("Made with ❤️ by Nick Ustinov", style: .caption)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.alignment = .center
        stackView.addArrangedSubview(footerLabel)
    }

    private func createLinkButton(title: String, url: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        button.bezelStyle = .inline
        button.toolTip = url
        return button
    }

    @objc private func openLink(_ sender: NSButton) {
        guard let urlString = sender.toolTip, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
