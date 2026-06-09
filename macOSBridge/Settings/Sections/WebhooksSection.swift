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
    private var bindPopup: NSPopUpButton!
    private var applyButton: NSButton!

    /// Example URL fields ("<base>/<suffix>") refreshed whenever the bound
    /// address changes, so every example below reflects the live endpoint.
    private var exampleFields: [(field: NSTextField, copy: NSButton, suffix: String)] = []

    /// Menu sentinel for the "Custom…" item in the Bind picker.
    private static let customBindSentinel = "__custom__"

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
        ("Device info", "info/<Room>/<Device>"),
        ("Event stream (SSE)", "events")
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
        // Pro banner (only shown for non-Pro users)
        if !ProStatusCache.shared.isPro {
            let banner = SettingsCard.createProBanner()
            stackView.addArrangedSubview(banner)
            banner.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            stackView.addArrangedSubview(createSpacer(height: 12))
        }

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
        addContentToBox(enableBox, content: createEnableRow())
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
        let formatHeader = AccessorySectionHeader(title: String(localized: "settings.webhooks.url_format", defaultValue: "URL format", bundle: .macOSBridge))
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
        let actionsHeader = AccessorySectionHeader(title: String(localized: "settings.webhooks.control_actions", defaultValue: "Control actions (examples)", bundle: .macOSBridge))
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
        let readHeader = AccessorySectionHeader(title: String(localized: "settings.webhooks.query_endpoints", defaultValue: "Query endpoints", bundle: .macOSBridge))
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
        let tipLabel = createLabel("Install CLI: brew install nickustinov/tap/itsyhome — then run itsyhome config to connect.", style: .caption)
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

        let labelField = createLabel(String(localized: "settings.webhooks.enable_server", defaultValue: "Enable server", bundle: .macOSBridge), style: .body)
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
        // Uniform row height so label-only rows and control rows share the same
        // vertical rhythm (the popup/field are taller than a bare label).
        let rowHeight: CGFloat = 26

        let statusTitle = createLabel(String(localized: "settings.webhooks.status_label", defaultValue: "Status:", bundle: .macOSBridge), style: .body)
        statusTitle.translatesAutoresizingMaskIntoConstraints = false
        statusTitle.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        statusLabel = createLabel(String(localized: "settings.webhooks.stopped", defaultValue: "Stopped", bundle: .macOSBridge), style: .body)
        statusRow.addArrangedSubview(statusTitle)
        statusRow.addArrangedSubview(statusLabel)
        statusRow.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
        stack.addArrangedSubview(statusRow)

        // Address row
        let addressRow = NSStackView()
        addressRow.orientation = .horizontal
        addressRow.spacing = 6
        addressRow.alignment = .centerY

        let addressTitle = createLabel(String(localized: "settings.webhooks.address_label", defaultValue: "Address:", bundle: .macOSBridge), style: .body)
        addressTitle.translatesAutoresizingMaskIntoConstraints = false
        addressTitle.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        addressLabel = NSTextField(labelWithString: "—")
        addressLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        addressLabel.textColor = .secondaryLabelColor
        addressLabel.isSelectable = true
        addressRow.addArrangedSubview(addressTitle)
        addressRow.addArrangedSubview(addressLabel)

        let copyButton = NSButton(title: String(localized: "common.copy", defaultValue: "Copy", bundle: .macOSBridge), target: self, action: #selector(copyAddress))
        copyButton.bezelStyle = .inline
        copyButton.controlSize = .mini
        copyButton.font = .systemFont(ofSize: 9)
        addressRow.addArrangedSubview(copyButton)
        addressRow.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        stack.addArrangedSubview(addressRow)

        // Port row
        let portRow = NSStackView()
        portRow.orientation = .horizontal
        portRow.spacing = 6
        portRow.alignment = .centerY

        let portTitle = createLabel(String(localized: "settings.webhooks.port_label", defaultValue: "Port:", bundle: .macOSBridge), style: .body)
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
        portRow.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
        stack.addArrangedSubview(portRow)

        // Bind address row
        let bindRow = NSStackView()
        bindRow.orientation = .horizontal
        bindRow.spacing = 6
        bindRow.alignment = .centerY

        let bindTitle = createLabel(String(localized: "settings.webhooks.bind_label", defaultValue: "Bind:", bundle: .macOSBridge), style: .body)
        bindTitle.translatesAutoresizingMaskIntoConstraints = false
        bindTitle.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        bindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        bindPopup.translatesAutoresizingMaskIntoConstraints = false
        bindPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        bindPopup.target = self
        bindPopup.action = #selector(bindPopupChanged)

        applyButton = NSButton(title: String(localized: "settings.webhooks.apply", defaultValue: "Apply", bundle: .macOSBridge), target: self, action: #selector(applyTapped))
        applyButton.bezelStyle = .rounded
        applyButton.controlSize = .small

        bindRow.addArrangedSubview(bindTitle)
        bindRow.addArrangedSubview(bindPopup)
        bindRow.addArrangedSubview(applyButton)
        bindRow.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
        stack.addArrangedSubview(bindRow)

        rebuildBindMenu()

        let hint = createLabel(String(localized: "settings.webhooks.bind_hint", defaultValue: "Limit which network the server listens on. Changes take effect when you click Apply.", bundle: .macOSBridge), style: .caption)
        hint.textColor = .tertiaryLabelColor
        stack.addArrangedSubview(hint)

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

            let copyButton = NSButton(title: String(localized: "common.copy", defaultValue: "Copy", bundle: .macOSBridge), target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .mini
            copyButton.font = .systemFont(ofSize: 9)
            copyButton.toolTip = "\(baseURL)/\(example)"

            exampleFields.append((field: exampleLabel, copy: copyButton, suffix: example))
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

            let copyButton = NSButton(title: String(localized: "common.copy", defaultValue: "Copy", bundle: .macOSBridge), target: self, action: #selector(copyURL(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .mini
            copyButton.font = .systemFont(ofSize: 9)
            copyButton.toolTip = "\(baseURL)/\(path)"

            exampleFields.append((field: pathLabel, copy: copyButton, suffix: path))
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

    private func addressString() -> String {
        let port = WebhookServer.configuredPort
        let host: String
        if let bind = WebhookServer.configuredBindAddress {
            // Bracket IPv6 literals for a valid URL.
            host = bind.contains(":") ? "[\(bind)]" : bind
        } else {
            host = WebhookServer.localIPAddress() ?? "localhost"
        }
        return "http://\(host):\(port)"
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
            statusLabel.stringValue = String(localized: "settings.webhooks.stopped", defaultValue: "Stopped", bundle: .macOSBridge)
            statusLabel.textColor = .secondaryLabelColor
            addressLabel.stringValue = "—"
        case .running:
            statusLabel.stringValue = String(localized: "settings.webhooks.running", defaultValue: "Running", bundle: .macOSBridge)
            statusLabel.textColor = .systemGreen
            addressLabel.stringValue = addressString()
        case .error(let message):
            statusLabel.stringValue = String(localized: "settings.webhooks.error", defaultValue: "Error: \(message)", bundle: .macOSBridge)
            statusLabel.textColor = .systemRed
            addressLabel.stringValue = "—"
        }

        refreshExampleURLs()
        refreshApplyState()
    }

    /// Rewrite every example URL to the current endpoint so they track the
    /// bound address (e.g. switch from the LAN IP to 127.0.0.1).
    private func refreshExampleURLs() {
        let base = addressString()
        for entry in exampleFields {
            let url = "\(base)/\(entry.suffix)"
            entry.field.stringValue = url
            entry.copy.toolTip = url
        }
    }

    /// Enable Apply only when the persisted config differs from what the server
    /// is currently running (or when it errored, so the user can retry).
    private func refreshApplyState() {
        guard let applyButton, let bindPopup else { return }
        let isPro = ProStatusCache.shared.isPro
        let isEnabled = UserDefaults.standard.bool(forKey: WebhookServer.enabledKey)
        let server = WebhookServer.shared
        let changed = server.port != WebhookServer.configuredPort
            || server.bindAddress != WebhookServer.configuredBindAddress
        let errored: Bool = { if case .error = server.state { return true } else { return false } }()
        bindPopup.isEnabled = isPro && isEnabled
        applyButton.isEnabled = isPro && isEnabled && (changed || errored)
    }

    /// Build the Bind picker from the addresses this Mac can actually bind to.
    private func rebuildBindMenu() {
        guard let bindPopup else { return }
        let menu = NSMenu()
        let current = WebhookServer.configuredBindAddress   // nil == all interfaces

        func add(_ title: String, value: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = value
            menu.addItem(item)
        }

        add(String(localized: "settings.webhooks.bind_all", defaultValue: "All interfaces", bundle: .macOSBridge), value: "")
        add(String(localized: "settings.webhooks.bind_localhost", defaultValue: "This Mac only (127.0.0.1)", bundle: .macOSBridge), value: "127.0.0.1")

        let detected = WebhookServer.localIPAddresses().filter { $0.ip != "127.0.0.1" }
        if !detected.isEmpty {
            menu.addItem(.separator())
            for entry in detected { add("\(entry.label) – \(entry.ip)", value: entry.ip) }
        }

        // Surface a configured custom address that isn't one of the detected ones.
        if let current, current != "127.0.0.1", !detected.contains(where: { $0.ip == current }) {
            menu.addItem(.separator())
            add(current, value: current)
        }

        menu.addItem(.separator())
        add(String(localized: "settings.webhooks.bind_custom", defaultValue: "Custom…", bundle: .macOSBridge), value: Self.customBindSentinel)

        bindPopup.menu = menu
        let target = current ?? ""
        if let match = menu.items.first(where: { ($0.representedObject as? String) == target }) {
            bindPopup.select(match)
        } else {
            bindPopup.selectItem(at: 0)
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
        refreshApplyState()
    }

    @objc private func bindPopupChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }

        if value == Self.customBindSentinel {
            promptCustomBindAddress()
            return
        }

        if value.isEmpty {
            UserDefaults.standard.removeObject(forKey: WebhookServer.bindAddressKey)
        } else {
            UserDefaults.standard.set(value, forKey: WebhookServer.bindAddressKey)
        }
        refreshApplyState()
    }

    /// Ask for a literal IP the picker can't offer (e.g. a VPN/mesh address that
    /// isn't up yet). Validated with the same `inet_pton` check as the server.
    private func promptCustomBindAddress() {
        let alert = NSAlert()
        alert.messageText = String(localized: "settings.webhooks.bind_custom_title", defaultValue: "Enter an IP address", bundle: .macOSBridge)
        alert.informativeText = String(localized: "settings.webhooks.bind_custom_message", defaultValue: "A local IPv4 or IPv6 address this Mac can bind to.", bundle: .macOSBridge)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = WebhookServer.configuredBindAddress ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespaces)
            if WebhookServer.isValidIPAddress(trimmed) {
                UserDefaults.standard.set(trimmed, forKey: WebhookServer.bindAddressKey)
            } else if !trimmed.isEmpty {
                let err = NSAlert()
                err.messageText = String(localized: "settings.webhooks.bind_invalid", defaultValue: "Not a valid IP address", bundle: .macOSBridge)
                err.informativeText = trimmed
                err.runModal()
            }
        }

        // Re-sync the picker to whatever ended up persisted (selection or revert).
        rebuildBindMenu()
        refreshApplyState()
    }

    @objc private func applyTapped(_ sender: NSButton) {
        WebhookServer.shared.applyConfiguration()
        rebuildBindMenu()
        updateStatusDisplay()
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
        sender.title = String(localized: "common.copied", defaultValue: "Copied!", bundle: .macOSBridge)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.title = originalTitle
        }
    }
}
