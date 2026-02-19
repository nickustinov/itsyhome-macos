//
//  ItsytvSection.swift
//  macOSBridge
//
//  Companion app promotion panel for Itsytv
//

import AppKit

class ItsytvSection: SettingsCard {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        stackView.spacing = 16

        // Main card with image on left, text on right
        let cardBox = CardBoxView()
        cardBox.translatesAutoresizingMaskIntoConstraints = false

        // Horizontal layout: image | text
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 20
        hStack.alignment = .top
        hStack.translatesAutoresizingMaskIntoConstraints = false
        cardBox.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: cardBox.topAnchor, constant: 16),
            hStack.leadingAnchor.constraint(equalTo: cardBox.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: cardBox.trailingAnchor, constant: -16),
            hStack.bottomAnchor.constraint(equalTo: cardBox.bottomAnchor, constant: -16)
        ])

        // Remote image (452x1600 @2x = 226x800pt logical)
        let imageView = NSImageView()
        imageView.image = Bundle(for: ItsytvSection.self).image(forResource: "itsytv-remote")
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        hStack.addArrangedSubview(imageView)

        let imageAspectRatio: CGFloat = 1600.0 / 452.0
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: imageAspectRatio)
        ])

        // Text content on the right
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 8
        textStack.alignment = .leading
        hStack.addArrangedSubview(textStack)

        let titleLabel = createLabel("Itsytv", style: .sectionHeader)
        textStack.addArrangedSubview(titleLabel)

        let descLabel = NSTextField(wrappingLabelWithString: String(localized: "settings.itsytv.description", defaultValue: "A free companion app for controlling Apple TV from your Mac menu bar. Full remote control, now playing widget, app launcher, and keyboard shortcuts \u{2013} all running natively on macOS.", bundle: .macOSBridge))
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        textStack.addArrangedSubview(descLabel)

        // Features list
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
        textStack.addArrangedSubview(spacer)

        let features = [
            String(localized: "settings.itsytv.feature_remote", defaultValue: "Full remote with D-pad and playback controls", bundle: .macOSBridge),
            String(localized: "settings.itsytv.feature_now_playing", defaultValue: "Now playing with live progress tracking", bundle: .macOSBridge),
            String(localized: "settings.itsytv.feature_apps", defaultValue: "Browse and launch Apple TV apps", bundle: .macOSBridge),
            String(localized: "settings.itsytv.feature_keyboard", defaultValue: "Keyboard shortcuts for quick control", bundle: .macOSBridge),
            String(localized: "settings.itsytv.feature_multiple", defaultValue: "Works with multiple Apple TVs", bundle: .macOSBridge)
        ]

        for feature in features {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            row.alignment = .firstBaseline

            let bullet = NSTextField(labelWithString: "\u{2022}")
            bullet.font = .systemFont(ofSize: 13)
            bullet.textColor = .secondaryLabelColor
            bullet.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(bullet)

            let label = NSTextField(wrappingLabelWithString: feature)
            label.font = .systemFont(ofSize: 13)
            label.textColor = .secondaryLabelColor
            row.addArrangedSubview(label)

            textStack.addArrangedSubview(row)
        }

        // Learn more button
        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        buttonSpacer.heightAnchor.constraint(equalToConstant: 4).isActive = true
        textStack.addArrangedSubview(buttonSpacer)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let learnMoreButton = NSButton(title: String(localized: "settings.itsytv.learn_more", defaultValue: "Learn more", bundle: .macOSBridge), target: self, action: #selector(openWebsite))
        learnMoreButton.bezelStyle = .rounded
        learnMoreButton.controlSize = .regular
        buttonRow.addArrangedSubview(learnMoreButton)

        let freeLabel = createLabel(String(localized: "settings.itsytv.free_open_source", defaultValue: "Free and open source", bundle: .macOSBridge), style: .caption)
        buttonRow.addArrangedSubview(freeLabel)

        textStack.addArrangedSubview(buttonRow)

        stackView.addArrangedSubview(cardBox)
        cardBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://itsytv.app") {
            NSWorkspace.shared.open(url)
        }
    }
}
