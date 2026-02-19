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
        ("Room/Device", String(localized: "settings.deeplinks.device_in_room", defaultValue: "Device in specific room", bundle: .macOSBridge)),
        ("Room/group.Name", String(localized: "settings.deeplinks.group_in_room", defaultValue: "Group scoped to a room", bundle: .macOSBridge)),
        ("group.Name", String(localized: "settings.deeplinks.global_group", defaultValue: "Global group (all rooms)", bundle: .macOSBridge))
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        // Pro banner (only shown for non-Pro users)
        if !ProStatusCache.shared.isPro {
            let banner = SettingsCard.createProBanner()
            stackView.addArrangedSubview(banner)
            banner.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            stackView.addArrangedSubview(createSpacer(height: 12))
        }

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Control your HomeKit devices from Shortcuts, Alfred, Raycast, Stream Deck, and other automation tools using URL schemes.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 4))

        // URL Format section
        let formatHeader = AccessorySectionHeader(title: String(localized: "settings.deeplinks.url_format", defaultValue: "URL format", bundle: .macOSBridge))
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
        let actionsHeader = AccessorySectionHeader(title: String(localized: "settings.deeplinks.actions", defaultValue: "Actions (examples)", bundle: .macOSBridge))
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
        let targetHeader = AccessorySectionHeader(title: String(localized: "settings.deeplinks.target_formats", defaultValue: "Target formats", bundle: .macOSBridge))
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

    private func createActionsContent() -> NSView {
        var rows: [[NSView]] = []

        for (action, _, example) in actions {
            let actionLabel = NSTextField(labelWithString: action)
            actionLabel.font = .systemFont(ofSize: 11)
            actionLabel.textColor = .labelColor
            actionLabel.alignment = .left
            actionLabel.setContentHuggingPriority(.required, for: .horizontal)
            actionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            let exampleLabel = NSTextField(labelWithString: "itsyhome://\(example)")
            exampleLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            exampleLabel.textColor = .secondaryLabelColor
            exampleLabel.isSelectable = true
            exampleLabel.lineBreakMode = .byTruncatingTail
            exampleLabel.setContentHuggingPriority(.init(1), for: .horizontal)

            let copyButton = NSButton(title: String(localized: "common.copy", defaultValue: "Copy", bundle: .macOSBridge), target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .mini
            copyButton.font = .systemFont(ofSize: 9)
            copyButton.toolTip = "itsyhome://\(example)"

            rows.append([actionLabel, exampleLabel, copyButton])
        }

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        grid.column(at: 2).xPlacement = .trailing
        return grid
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
            formatLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true

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
        let box = CardBoxView()
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
        sender.title = String(localized: "common.copied", defaultValue: "Copied!", bundle: .macOSBridge)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.title = originalTitle
        }
    }
}
