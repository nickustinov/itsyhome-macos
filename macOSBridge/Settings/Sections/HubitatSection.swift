//
//  HubitatSection.swift
//  macOSBridge
//
//  Hubitat connection settings
//

import AppKit

class HubitatSection: SettingsCard, NSTextFieldDelegate {

    private let hubURLField = NSTextField()
    private let appIdField = NSTextField()
    private let accessTokenField = NSSecureTextField()
    private let statusIndicator = NSImageView()
    private let statusLabel = NSTextField(labelWithString: String(localized: "settings.hubitat.not_connected", defaultValue: "Not connected", bundle: .macOSBridge))
    private let connectButton = NSButton()
    private let disconnectButton = NSButton()

    private var isConnecting = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        loadCredentials()
        updateUI()
        setupNotifications()
        setupTextFieldDelegates()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusHubURL),
            name: .hubitatSectionFocusHubURL,
            object: nil
        )
    }

    @objc private func focusHubURL() {
        window?.makeFirstResponder(hubURLField)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTextFieldDelegates() {
        hubURLField.delegate = self
        appIdField.delegate = self
        accessTokenField.delegate = self
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        updateUI()
    }

    private func setupContent() {
        // Connection status box
        let statusBox = createCardBox()
        let statusContent = createStatusSection()
        addContentToBox(statusBox, content: statusContent)
        stackView.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Server configuration box
        let configBox = createCardBox()
        let configContent = createConfigSection()
        addContentToBox(configBox, content: configContent)
        stackView.addArrangedSubview(configBox)
        configBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Actions box
        let actionsBox = createCardBox()
        let actionsContent = createActionsSection()
        addContentToBox(actionsBox, content: actionsContent)
        stackView.addArrangedSubview(actionsBox)
        actionsBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func createStatusSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Status")
        statusIndicator.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        statusIndicator.contentTintColor = .systemGray
        row.addArrangedSubview(statusIndicator)

        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .labelColor
        row.addArrangedSubview(statusLabel)

        container.addSubview(row)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 36),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12)
        ])

        return container
    }

    private func createConfigSection() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false

        // Hub URL row
        let urlRow = createInputRow(
            label: String(localized: "settings.hubitat.hub_url", defaultValue: "Hub URL", bundle: .macOSBridge),
            placeholder: "http://192.168.1.xxx",
            textField: hubURLField
        )
        container.addArrangedSubview(urlRow)
        urlRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // App ID row
        let appIdRow = createInputRow(
            label: String(localized: "settings.hubitat.app_id", defaultValue: "App ID", bundle: .macOSBridge),
            placeholder: "Maker API app ID",
            textField: appIdField
        )
        container.addArrangedSubview(appIdRow)
        appIdRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // Access token row
        let tokenRow = createInputRow(
            label: String(localized: "settings.hubitat.access_token", defaultValue: "Access token", bundle: .macOSBridge),
            placeholder: "Maker API access token",
            textField: accessTokenField
        )
        container.addArrangedSubview(tokenRow)
        tokenRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // Help text
        let helpLabel = createLabel(String(localized: "settings.hubitat.help", defaultValue: "Configure Maker API in your Hubitat hub under Apps > Maker API", bundle: .macOSBridge), style: .caption)
        helpLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(helpLabel)

        return container
    }

    private func createInputRow(label: String, placeholder: String, textField: NSTextField) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelField = createLabel(label, style: .body)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelField)

        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 13)
        textField.bezelStyle = .roundedBezel
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.target = self
        textField.action = #selector(textFieldChanged)
        container.addSubview(textField)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 28),
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelField.widthAnchor.constraint(equalToConstant: 100),
            textField.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func createActionsSection() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 12
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        connectButton.title = String(localized: "common.connect", defaultValue: "Connect", bundle: .macOSBridge)
        connectButton.bezelStyle = .rounded
        connectButton.target = self
        connectButton.action = #selector(connectTapped)
        container.addArrangedSubview(connectButton)

        disconnectButton.title = String(localized: "settings.hubitat.disconnect", defaultValue: "Disconnect", bundle: .macOSBridge)
        disconnectButton.bezelStyle = .rounded
        disconnectButton.target = self
        disconnectButton.action = #selector(disconnectTapped)
        container.addArrangedSubview(disconnectButton)

        return container
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
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12)
        ])
    }

    private func loadCredentials() {
        if let hubURL = HubitatAuthManager.shared.hubURL {
            hubURLField.stringValue = hubURL.absoluteString
        }
        if let appId = HubitatAuthManager.shared.appId {
            appIdField.stringValue = appId
        }
        if let token = HubitatAuthManager.shared.accessToken {
            accessTokenField.stringValue = token
        }
    }

    private func updateUI() {
        let hasCredentials = HubitatAuthManager.shared.isConfigured

        if isConnecting {
            statusIndicator.contentTintColor = .systemOrange
            statusLabel.stringValue = String(localized: "common.connecting", defaultValue: "Connecting...", bundle: .macOSBridge)
            connectButton.isEnabled = false
        } else if hasCredentials {
            statusIndicator.contentTintColor = .systemGreen
            statusLabel.stringValue = "Connected to \(HubitatAuthManager.shared.hubURL?.host ?? "hub")"
            connectButton.title = String(localized: "settings.hubitat.test_connection", defaultValue: "Test connection", bundle: .macOSBridge)
            connectButton.isEnabled = true
        } else {
            statusIndicator.contentTintColor = .systemGray
            statusLabel.stringValue = String(localized: "settings.hubitat.not_connected", defaultValue: "Not connected", bundle: .macOSBridge)
            connectButton.title = String(localized: "common.connect", defaultValue: "Connect", bundle: .macOSBridge)
            connectButton.isEnabled = !hubURLField.stringValue.isEmpty &&
                                      !appIdField.stringValue.isEmpty &&
                                      !accessTokenField.stringValue.isEmpty
        }

        disconnectButton.isEnabled = hasCredentials
    }

    @objc private func textFieldChanged() {
        updateUI()
    }

    @objc private func connectTapped() {
        let urlString = hubURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let appId = appIdField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = accessTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), !urlString.isEmpty else {
            showAlert(
                title: String(localized: "alert.invalid_url.title", defaultValue: "Invalid URL", bundle: .macOSBridge),
                message: String(localized: "settings.hubitat.invalid_url_message", defaultValue: "Please enter a valid hub URL, e.g. http://192.168.1.xxx", bundle: .macOSBridge)
            )
            return
        }

        guard !appId.isEmpty else {
            showAlert(
                title: String(localized: "alert.missing_credentials.title", defaultValue: "Missing credentials", bundle: .macOSBridge),
                message: String(localized: "settings.hubitat.missing_app_id", defaultValue: "Please enter the Maker API app ID.", bundle: .macOSBridge)
            )
            return
        }

        guard !token.isEmpty else {
            showAlert(
                title: String(localized: "alert.missing_credentials.title", defaultValue: "Missing credentials", bundle: .macOSBridge),
                message: String(localized: "settings.hubitat.missing_token", defaultValue: "Please enter the Maker API access token.", bundle: .macOSBridge)
            )
            return
        }

        // Save credentials
        HubitatAuthManager.shared.saveCredentials(hubURL: url, appId: appId, accessToken: token)

        // Test connection
        isConnecting = true
        updateUI()

        Task {
            do {
                let success = try await HubitatAuthManager.shared.validateCredentials()
                await MainActor.run {
                    isConnecting = false
                    if success {
                        updateUI()
                        showAlert(
                            title: String(localized: "alert.connected.title", defaultValue: "Connected", bundle: .macOSBridge),
                            message: String(localized: "settings.hubitat.connected_message", defaultValue: "Successfully connected to Hubitat hub.", bundle: .macOSBridge)
                        )
                        NotificationCenter.default.post(name: .hubitatCredentialsChanged, object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    HubitatAuthManager.shared.clearCredentials()
                    updateUI()
                    showAlert(
                        title: String(localized: "alert.connection_failed.title", defaultValue: "Connection failed", bundle: .macOSBridge),
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    @objc private func disconnectTapped() {
        let alert = NSAlert()
        alert.messageText = String(localized: "settings.hubitat.disconnect_title", defaultValue: "Disconnect from Hubitat?", bundle: .macOSBridge)
        alert.informativeText = String(localized: "alert.disconnect.message", defaultValue: "This will clear your saved credentials.", bundle: .macOSBridge)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "alert.disconnect.confirm", defaultValue: "Disconnect", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))

        if alert.runModal() == .alertFirstButtonReturn {
            HubitatAuthManager.shared.clearCredentials()
            hubURLField.stringValue = ""
            appIdField.stringValue = ""
            accessTokenField.stringValue = ""
            updateUI()
            NotificationCenter.default.post(name: .hubitatCredentialsChanged, object: nil)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK", bundle: .macOSBridge))
        alert.runModal()
    }
}
