//
//  DeeplinksSection.swift
//  macOSBridge
//
//  Deeplinks documentation section
//

import AppKit

class DeeplinksSection: SettingsCard {

    private let actions: [(action: String, format: String, example: String)] = [
        ("Toggle", "toggle/<Room>/<Device>", "toggle/Office/Spotlights"),
        ("Turn on", "on/<Room>/<Device>", "on/Kitchen/Light"),
        ("Turn off", "off/<Room>/<Device>", "off/Bedroom/Lamp"),
        ("Brightness", "brightness/<0-100>/<Room>/<Device>", "brightness/50/Office/Lamp"),
        ("Position", "position/<0-100>/<Room>/<Device>", "position/75/Living%20Room/Blinds"),
        ("Temperature", "temp/<degrees>/<Room>/<Device>", "temp/22/Hallway/Thermostat"),
        ("Color", "color/<hue>/<sat>/<Room>/<Device>", "color/120/100/Bedroom/Light"),
        ("Scene", "scene/<Scene%20Name>", "scene/Goodnight"),
        ("Lock", "lock/<Room>/<Device>", "lock/Front%20Door"),
        ("Unlock", "unlock/<Room>/<Device>", "unlock/Front%20Door"),
        ("Open", "open/<Room>/<Device>", "open/Garage/Door"),
        ("Close", "close/<Room>/<Device>", "close/Bedroom/Blinds")
    ]

    private let targetFormats: [(format: String, description: String)] = [
        ("Room/Device", "Device in specific room"),
        ("group.Name", "All devices in a group")
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        // Pro badge (only show if user doesn't have PRO)
        if !ProStatusCache.shared.isPro {
            let proBadge = createProBadge()
            stackView.addArrangedSubview(proBadge)
            proBadge.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Control your HomeKit devices from Shortcuts, Alfred, Raycast, Stream Deck, and other automation tools using URL schemes.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 16))

        // URL Format section
        let formatHeader = AccessorySectionHeader(title: "URL format")
        stackView.addArrangedSubview(formatHeader)
        formatHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        formatHeader.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let formatBox = createCardBox()
        let formatLabel = createLabel("itsyhome://<action>/<target>", style: .code)
        addContentToBox(formatBox, content: formatLabel)
        stackView.addArrangedSubview(formatBox)
        formatBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 12))

        // Actions section
        let actionsHeader = AccessorySectionHeader(title: "Actions")
        stackView.addArrangedSubview(actionsHeader)
        actionsHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        actionsHeader.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let actionsBox = createCardBox()
        let actionsContent = createActionsContent()
        addContentToBox(actionsBox, content: actionsContent)
        stackView.addArrangedSubview(actionsBox)
        actionsBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 12))

        // Target formats section
        let targetHeader = AccessorySectionHeader(title: "Target formats")
        stackView.addArrangedSubview(targetHeader)
        targetHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        targetHeader.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let targetBox = createCardBox()
        let targetContent = createTargetFormatsContent()
        addContentToBox(targetBox, content: targetContent)
        stackView.addArrangedSubview(targetBox)
        targetBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 8))

        // Tip
        let tipLabel = createLabel("Tip: Use %20 for spaces in room or device names.", style: .caption)
        tipLabel.textColor = .tertiaryLabelColor
        stackView.addArrangedSubview(tipLabel)

        stackView.addArrangedSubview(createSpacer(height: 16))
    }

    private func createProBadge() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.95, green: 0.92, blue: 1.0, alpha: 1.0).cgColor
        container.layer?.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .horizontal
        content.spacing = 8
        content.alignment = .centerY
        content.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Pro")
        iconView.contentTintColor = .systemPurple
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let label = NSTextField(labelWithString: "Itsyhome Pro feature")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor

        content.addArrangedSubview(iconView)
        content.addArrangedSubview(label)

        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }

    private func createActionsContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading

        for (action, _, example) in actions {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .centerY

            let actionLabel = NSTextField(labelWithString: action)
            actionLabel.font = .systemFont(ofSize: 11)
            actionLabel.textColor = .labelColor
            actionLabel.translatesAutoresizingMaskIntoConstraints = false
            actionLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true

            let exampleLabel = NSTextField(labelWithString: "itsyhome://\(example)")
            exampleLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            exampleLabel.textColor = .secondaryLabelColor
            exampleLabel.isSelectable = true
            exampleLabel.lineBreakMode = .byTruncatingTail

            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .mini
            copyButton.font = .systemFont(ofSize: 9)
            copyButton.toolTip = "itsyhome://\(example)"

            row.addArrangedSubview(actionLabel)
            row.addArrangedSubview(exampleLabel)
            row.addArrangedSubview(copyButton)

            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func createTargetFormatsContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading

        for (format, description) in targetFormats {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .centerY

            let formatLabel = NSTextField(labelWithString: format)
            formatLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            formatLabel.textColor = .labelColor
            formatLabel.translatesAutoresizingMaskIntoConstraints = false
            formatLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

            let descLabel = NSTextField(labelWithString: description)
            descLabel.font = .systemFont(ofSize: 11)
            descLabel.textColor = .secondaryLabelColor

            row.addArrangedSubview(formatLabel)
            row.addArrangedSubview(descLabel)

            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func createCardBox() -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(white: 0.97, alpha: 1.0).cgColor
        box.layer?.cornerRadius = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func addContentToBox(_ box: NSView, content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])
    }

    private func createSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    @objc private func copyURL(_ sender: NSButton) {
        guard let url = sender.toolTip else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)

        let originalTitle = sender.title
        sender.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.title = originalTitle
        }
    }
}
