//
//  ItsyhomeIOSSection.swift
//  macOSBridge
//
//  Promotes the iPhone/iPad companion included with Pro.
//

import AppKit

class ItsyhomeIOSSection: SettingsCard {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        stackView.spacing = 16

        let cardBox = CardBoxView()
        cardBox.translatesAutoresizingMaskIntoConstraints = false

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

        let imageView = NSImageView()
        imageView.image = Bundle(for: ItsyhomeIOSSection.self).image(forResource: "itsyhome-ios")
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 18
        imageView.layer?.masksToBounds = true
        hStack.addArrangedSubview(imageView)

        let imageAspectRatio: CGFloat = 2796.0 / 1419.0
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 160),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: imageAspectRatio)
        ])

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 8
        textStack.alignment = .leading
        hStack.addArrangedSubview(textStack)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY

        let titleLabel = createLabel(String(localized: "settings.itsyhome_ios.title", defaultValue: "Itsyhome for iOS", bundle: .macOSBridge), style: .sectionHeader)
        titleRow.addArrangedSubview(titleLabel)

        let badge = makeProBadge()
        titleRow.addArrangedSubview(badge)
        textStack.addArrangedSubview(titleRow)

        let descLabel = NSTextField(wrappingLabelWithString: String(localized: "settings.itsyhome_ios.description", defaultValue: "Itsyhome is also available for iPhone and iPad \u{2013} included with your Pro purchase. Control your HomeKit setup from anywhere, with the same fast native experience.", bundle: .macOSBridge))
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        textStack.addArrangedSubview(descLabel)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
        textStack.addArrangedSubview(spacer)

        let features = [
            String(localized: "settings.itsyhome_ios.feature_control", defaultValue: "Control lights, climate, locks, covers, cameras", bundle: .macOSBridge),
            String(localized: "settings.itsyhome_ios.feature_widgets", defaultValue: "Lock Screen controls", bundle: .macOSBridge),
            String(localized: "settings.itsyhome_ios.feature_shortcuts", defaultValue: "Shortcuts, scenes, and groups at your fingertips", bundle: .macOSBridge),
            String(localized: "settings.itsyhome_ios.feature_sync", defaultValue: "Same setup as macOS \u{2013} no extra configuration", bundle: .macOSBridge),
            String(localized: "settings.itsyhome_ios.feature_included", defaultValue: "Included with your Itsyhome Pro purchase", bundle: .macOSBridge)
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

        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        buttonSpacer.heightAnchor.constraint(equalToConstant: 4).isActive = true
        textStack.addArrangedSubview(buttonSpacer)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let learnMoreButton = NSButton(title: String(localized: "settings.itsyhome_ios.learn_more", defaultValue: "Learn more", bundle: .macOSBridge), target: self, action: #selector(openAppStore))
        learnMoreButton.bezelStyle = .rounded
        learnMoreButton.controlSize = .regular
        buttonRow.addArrangedSubview(learnMoreButton)

        textStack.addArrangedSubview(buttonRow)

        stackView.addArrangedSubview(cardBox)
        cardBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func makeProBadge() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 4
        container.layer?.backgroundColor = NSColor.systemBlue.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "PRO")
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 16)
        ])
        return container
    }

    @objc private func openAppStore() {
        if let url = URL(string: "https://itsyhome.app/ios") {
            NSWorkspace.shared.open(url)
        }
    }
}
