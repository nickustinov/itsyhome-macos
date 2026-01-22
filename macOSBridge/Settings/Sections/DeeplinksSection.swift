//
//  DeeplinksSection.swift
//  macOSBridge
//
//  Deeplinks documentation section
//

import AppKit

class DeeplinksSection: SettingsCard {

    private let examples = [
        ("Toggle device", "itsyhome://toggle/Office/Lamp"),
        ("Turn on", "itsyhome://on/Kitchen/Light"),
        ("Set brightness", "itsyhome://brightness/50/Bedroom/Lamp"),
        ("Run scene", "itsyhome://scene/Goodnight")
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Control your HomeKit devices from Shortcuts, Alfred, Raycast, Stream Deck, and other automation tools using URL schemes.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // URL Format section
        let formatHeader = createLabel("URL FORMAT", style: .sectionHeader)
        stackView.addArrangedSubview(formatHeader)

        let formatBox = createGroupBox()
        let formatLabel = createLabel("itsyhome://<action>/<Room>/<Device>", style: .code)
        formatLabel.alignment = .center

        let formatStack = NSStackView(views: [formatLabel])
        formatStack.alignment = .centerX
        formatStack.translatesAutoresizingMaskIntoConstraints = false

        formatBox.contentView = formatStack
        NSLayoutConstraint.activate([
            formatStack.topAnchor.constraint(equalTo: formatBox.contentView!.topAnchor, constant: 12),
            formatStack.leadingAnchor.constraint(equalTo: formatBox.contentView!.leadingAnchor, constant: 12),
            formatStack.trailingAnchor.constraint(equalTo: formatBox.contentView!.trailingAnchor, constant: -12),
            formatStack.bottomAnchor.constraint(equalTo: formatBox.contentView!.bottomAnchor, constant: -12)
        ])

        stackView.addArrangedSubview(formatBox)
        formatBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Examples section
        let examplesHeader = createLabel("EXAMPLES", style: .sectionHeader)
        stackView.addArrangedSubview(examplesHeader)

        let examplesBox = createGroupBox()
        let examplesStack = NSStackView()
        examplesStack.orientation = .vertical
        examplesStack.spacing = 8
        examplesStack.alignment = .leading
        examplesStack.translatesAutoresizingMaskIntoConstraints = false

        for (label, url) in examples {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 8
            rowStack.alignment = .centerY

            let labelField = createLabel(label, style: .caption)
            labelField.translatesAutoresizingMaskIntoConstraints = false
            labelField.widthAnchor.constraint(equalToConstant: 80).isActive = true

            let urlField = createLabel(url, style: .code)
            urlField.isSelectable = true

            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.font = .systemFont(ofSize: 10)
            copyButton.toolTip = url

            rowStack.addArrangedSubview(labelField)
            rowStack.addArrangedSubview(urlField)
            rowStack.addArrangedSubview(copyButton)

            examplesStack.addArrangedSubview(rowStack)
        }

        examplesBox.contentView = examplesStack
        NSLayoutConstraint.activate([
            examplesStack.topAnchor.constraint(equalTo: examplesBox.contentView!.topAnchor, constant: 12),
            examplesStack.leadingAnchor.constraint(equalTo: examplesBox.contentView!.leadingAnchor, constant: 12),
            examplesStack.trailingAnchor.constraint(equalTo: examplesBox.contentView!.trailingAnchor, constant: -12),
            examplesStack.bottomAnchor.constraint(equalTo: examplesBox.contentView!.bottomAnchor, constant: -12)
        ])

        stackView.addArrangedSubview(examplesBox)
        examplesBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Supported actions
        let actionsHeader = createLabel("SUPPORTED ACTIONS", style: .sectionHeader)
        stackView.addArrangedSubview(actionsHeader)

        let actionsLabel = NSTextField(wrappingLabelWithString: "toggle, on, off, brightness, position, temp, color, scene, lock, unlock, open, close")
        actionsLabel.font = .systemFont(ofSize: 11)
        actionsLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(actionsLabel)
        actionsLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Tip
        let tipLabel = createLabel("Tip: Use %20 for spaces in room or device names.", style: .caption)
        tipLabel.textColor = .tertiaryLabelColor
        stackView.addArrangedSubview(tipLabel)
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
