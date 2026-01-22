//
//  WebhooksSection.swift
//  macOSBridge
//
//  Webhooks/CLI settings section for configuring the built-in HTTP server
//

import AppKit

class WebhooksSection: SettingsCard {

    private let enableSwitch = NSSwitch()
    private var statusLabel: NSTextField!
    private var addressLabel: NSTextField!
    private var portField: NSTextField!

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
        ("Unlock", "unlock/<Room>/<Device>", "unlock/Front%20Door")
    ]

    private let readEndpoints: [(name: String, path: String)] = [
        ("Home status", "status"),
        ("List rooms", "list/rooms"),
        ("List devices", "list/devices"),
        ("List scenes", "list/scenes"),
        ("List groups", "list/groups"),
        ("Device info", "info/<Room>/<Device>")
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        updateUI()
        observeStatusChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Run a local HTTP server to control and query your HomeKit devices via GET requests. Use from any device on your network, or install the itsyhome CLI tool (brew install nickustinov/tap/itsyhome).")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // CLI repo link
        let linkButton = NSButton(title: "CLI documentation & source", target: self, action: #selector(openCLIRepo))
        linkButton.bezelStyle = .inline
        linkButton.isBordered = false
        linkButton.contentTintColor = .controlAccentColor
        linkButton.font = .systemFont(ofSize: 12)
        linkButton.alignment = .left
        stackView.addArrangedSubview(linkButton)

        stackView.addArrangedSubview(createSpacer(height: 4))

        // Enable toggle box
        let enableBox = createCardBox()
        let enableRow = createEnableRow()
        addContentToBox(enableBox, content: enableRow)
        stackView.addArrangedSubview(enableBox)
        enableBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 8))

        // Status box
        let statusBox = createCardBox()
        let statusContent = createStatusContent()
        addContentToBox(statusBox, content: statusContent)
        stackView.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 12))

        // URL format section
        let formatHeader = AccessorySectionHeader(title: "URL format")
        stackView.addArrangedSubview(formatHeader)
        formatHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        formatHeader.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let formatBox = createCardBox()
        let formatLabel = createLabel("http://<ip>:<port>/<action>/<target>", style: .code)
        addContentToBox(formatBox, content: formatLabel)
        stackView.addArrangedSubview(formatBox)
        formatBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 12))

        // Control actions section
        let actionsHeader = AccessorySectionHeader(title: "Control actions (examples)")
        stackView.addArrangedSubview(actionsHeader)
        actionsHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        actionsHeader.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let actionsBox = createCardBox()
        let actionsContent = createActionsContent()
        addContentToBox(actionsBox, content: actionsContent)
        stackView.addArrangedSubview(actionsBox)
        actionsBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 12))

        // Read endpoints section
        let readHeader = AccessorySectionHeader(title: "Query endpoints")
        stackView.addArrangedSubview(readHeader)
        readHeader.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        readHeader.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let readBox = createCardBox()
        let readContent = createReadEndpointsContent()
        addContentToBox(readBox, content: readContent)
        stackView.addArrangedSubview(readBox)
        readBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        stackView.addArrangedSubview(createSpacer(height: 8))

        // CLI tip
        let tipLabel = createLabel("Install CLI: brew install itsyhome — then run itsyhome config to connect.", style: .caption)
        tipLabel.textColor = .tertiaryLabelColor
        stackView.addArrangedSubview(tipLabel)

        stackView.addArrangedSubview(createSpacer(height: 16))
    }

    // MARK: - Enable row

    private func createEnableRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .horizontal
        labelStack.spacing = 6
        labelStack.alignment = .centerY
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let labelField = createLabel("Enable server", style: .body)
        labelStack.addArrangedSubview(labelField)

        enableSwitch.controlSize = .mini
        enableSwitch.target = self
        enableSwitch.action = #selector(enableSwitchChanged)
        enableSwitch.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelStack)
        container.addSubview(enableSwitch)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 36),
            labelStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: enableSwitch.leadingAnchor, constant: -16),
            enableSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            enableSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    // MARK: - Status content

    private func createStatusContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading

        // Status row
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .centerY

        let labelWidth: CGFloat = 60

        let statusTitle = createLabel("Status:", style: .body)
        statusTitle.translatesAutoresizingMaskIntoConstraints = false
        statusTitle.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        statusLabel = createLabel("Stopped", style: .body)
        statusRow.addArrangedSubview(statusTitle)
        statusRow.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(statusRow)

        // Address row
        let addressRow = NSStackView()
        addressRow.orientation = .horizontal
        addressRow.spacing = 6
        addressRow.alignment = .centerY

        let addressTitle = createLabel("Address:", style: .body)
        addressTitle.translatesAutoresizingMaskIntoConstraints = false
        addressTitle.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        addressLabel = NSTextField(labelWithString: "—")
        addressLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        addressLabel.textColor = .secondaryLabelColor
        addressLabel.isSelectable = true
        addressRow.addArrangedSubview(addressTitle)
        addressRow.addArrangedSubview(addressLabel)

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyAddress))
        copyButton.bezelStyle = .inline
        copyButton.controlSize = .mini
        copyButton.font = .systemFont(ofSize: 9)
        addressRow.addArrangedSubview(copyButton)

        stack.addArrangedSubview(addressRow)

        // Port row
        let portRow = NSStackView()
        portRow.orientation = .horizontal
        portRow.spacing = 6
        portRow.alignment = .centerY

        let portTitle = createLabel("Port:", style: .body)
        portTitle.translatesAutoresizingMaskIntoConstraints = false
        portTitle.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        portField = NSTextField()
        portField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        portField.placeholderString = "\(WebhookServer.defaultPort)"
        portField.stringValue = "\(WebhookServer.configuredPort)"
        portField.translatesAutoresizingMaskIntoConstraints = false
        portField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        portField.target = self
        portField.action = #selector(portChanged)

        portRow.addArrangedSubview(portTitle)
        portRow.addArrangedSubview(portField)
        stack.addArrangedSubview(portRow)

        return stack
    }

    // MARK: - Actions content

    private func createActionsContent() -> NSView {
        let baseURL = addressString()
        var rows: [[NSView]] = []

        for (action, _, example) in actions {
            let actionLabel = NSTextField(labelWithString: action)
            actionLabel.font = .systemFont(ofSize: 11)
            actionLabel.textColor = .labelColor
            actionLabel.alignment = .left

            let exampleLabel = NSTextField(labelWithString: "\(baseURL)/\(example)")
            exampleLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            exampleLabel.textColor = .secondaryLabelColor
            exampleLabel.isSelectable = true
            exampleLabel.lineBreakMode = .byTruncatingTail

            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .mini
            copyButton.font = .systemFont(ofSize: 9)
            copyButton.toolTip = "\(baseURL)/\(example)"

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

    // MARK: - Read endpoints content

    private func createReadEndpointsContent() -> NSView {
        let baseURL = addressString()
        var rows: [[NSView]] = []

        for (name, path) in readEndpoints {
            let nameLabel = NSTextField(labelWithString: name)
            nameLabel.font = .systemFont(ofSize: 11)
            nameLabel.textColor = .labelColor
            nameLabel.alignment = .left

            let pathLabel = NSTextField(labelWithString: "\(baseURL)/\(path)")
            pathLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            pathLabel.textColor = .secondaryLabelColor
            pathLabel.isSelectable = true
            pathLabel.lineBreakMode = .byTruncatingTail

            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .mini
            copyButton.font = .systemFont(ofSize: 9)
            copyButton.toolTip = "\(baseURL)/\(path)"

            rows.append([nameLabel, pathLabel, copyButton])
        }

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        grid.column(at: 2).xPlacement = .trailing
        return grid
    }

    // MARK: - UI helpers

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

    private func addressString() -> String {
        let ip = WebhookServer.localIPAddress() ?? "localhost"
        return "http://\(ip):\(WebhookServer.configuredPort)"
    }

    // MARK: - State management

    private func updateUI() {
        let isPro = ProStatusCache.shared.isPro
        let isEnabled = UserDefaults.standard.bool(forKey: WebhookServer.enabledKey)

        enableSwitch.isEnabled = isPro
        enableSwitch.state = isEnabled ? .on : .off

        // Ensure server is running if enabled
        if isPro && isEnabled && WebhookServer.shared.state == .stopped {
            WebhookServer.shared.start()
        }

        updateStatusDisplay()
    }

    private func updateStatusDisplay() {
        let state = WebhookServer.shared.state

        switch state {
        case .stopped:
            statusLabel.stringValue = "Stopped"
            statusLabel.textColor = .secondaryLabelColor
            addressLabel.stringValue = "—"
        case .running:
            statusLabel.stringValue = "Running"
            statusLabel.textColor = .systemGreen
            addressLabel.stringValue = addressString()
        case .error(let message):
            statusLabel.stringValue = "Error: \(message)"
            statusLabel.textColor = .systemRed
            addressLabel.stringValue = "—"
        }
    }

    private func observeStatusChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusDidChange),
            name: WebhookServer.statusChangedNotification,
            object: nil
        )
    }

    // MARK: - Actions

    @objc private func enableSwitchChanged(_ sender: NSSwitch) {
        let enabled = sender.state == .on
        UserDefaults.standard.set(enabled, forKey: WebhookServer.enabledKey)

        if enabled {
            WebhookServer.shared.start()
        } else {
            WebhookServer.shared.stop()
        }
    }

    @objc private func portChanged(_ sender: NSTextField) {
        guard let port = UInt16(sender.stringValue), port > 0 else {
            sender.stringValue = "\(WebhookServer.configuredPort)"
            return
        }
        UserDefaults.standard.set(Int(port), forKey: WebhookServer.portKey)

        // Restart server with new port if running
        if WebhookServer.shared.state == .running {
            WebhookServer.shared.stop()
            // Recreate shared instance with new port (requires app restart for full effect)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                WebhookServer.shared.start()
            }
        }
    }

    @objc private func statusDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusDisplay()
        }
    }

    @objc private func copyAddress() {
        let address = addressString()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
    }

    @objc private func openCLIRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/nickustinov/itsyhome-cli")!)
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
