//
//  HomeAssistantSection.swift
//  macOSBridge
//
//  Home Assistant connection settings
//

import AppKit

class HomeAssistantSection: SettingsCard, NSTextFieldDelegate {

    private let serverURLField = NSTextField()
    private let accessTokenField = NSSecureTextField()
    private let entityCategoryPopUp = NSPopUpButton()
    private let statusIndicator = NSImageView()
    private let statusLabel = NSTextField(labelWithString: String(localized: "settings.home_assistant.not_connected", defaultValue: "Not connected", bundle: .macOSBridge))
    private let connectButton = NSButton()
    private let disconnectButton = NSButton()

    private var isConnecting = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        loadCredentials()
        loadPreferences()
        updateUI()
        setupNotifications()
        setupTextFieldDelegates()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusServerURL),
            name: NSNotification.Name("HomeAssistantSectionFocusServerURL"),
            object: nil
        )
    }

    @objc private func focusServerURL() {
        window?.makeFirstResponder(serverURLField)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTextFieldDelegates() {
        serverURLField.delegate = self
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

        // Entity category filter box
        let filterBox = createCardBox()
        entityCategoryPopUp.removeAllItems()
        entityCategoryPopUp.addItems(withTitles: [
            String(localized: "settings.home_assistant.entity_filter_hide_all", defaultValue: "Hide config and diagnostic", bundle: .macOSBridge),
            String(localized: "settings.home_assistant.entity_filter_hide_config", defaultValue: "Hide config only", bundle: .macOSBridge),
            String(localized: "settings.home_assistant.entity_filter_hide_diagnostic", defaultValue: "Hide diagnostic only", bundle: .macOSBridge),
            String(localized: "settings.home_assistant.entity_filter_show_all", defaultValue: "Show all", bundle: .macOSBridge)
        ])
        entityCategoryPopUp.controlSize = .small
        entityCategoryPopUp.target = self
        entityCategoryPopUp.action = #selector(entityCategoryFilterChanged)
        let filterRow = createSettingRow(
            label: String(localized: "settings.home_assistant.entity_categories", defaultValue: "Entity categories", bundle: .macOSBridge),
            control: entityCategoryPopUp
        )
        addContentToBox(filterBox, content: filterRow)
        stackView.addArrangedSubview(filterBox)
        filterBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
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

        // Server URL row
        let urlRow = createInputRow(
            label: String(localized: "settings.home_assistant.server_url", defaultValue: "Server URL", bundle: .macOSBridge),
            placeholder: "http://homeassistant.local:8123",
            textField: serverURLField
        )
        container.addArrangedSubview(urlRow)
        urlRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // Access token row
        let tokenRow = createInputRow(
            label: String(localized: "settings.home_assistant.access_token", defaultValue: "Access token", bundle: .macOSBridge),
            placeholder: "Long-lived access token",
            textField: accessTokenField
        )
        container.addArrangedSubview(tokenRow)
        tokenRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // Help text
        let helpLabel = createLabel(String(localized: "settings.home_assistant.token_help", defaultValue: "Get your token from Home Assistant > Profile > Security > Long-Lived Access Tokens", bundle: .macOSBridge), style: .caption)
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

        disconnectButton.title = String(localized: "settings.home_assistant.disconnect", defaultValue: "Disconnect", bundle: .macOSBridge)
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
        if let serverURL = HAAuthManager.shared.serverURL {
            serverURLField.stringValue = serverURL.absoluteString
        }
        if let token = HAAuthManager.shared.accessToken {
            accessTokenField.stringValue = token
        }
    }

    private func updateUI() {
        let hasCredentials = HAAuthManager.shared.isConfigured

        if isConnecting {
            statusIndicator.contentTintColor = .systemOrange
            statusLabel.stringValue = String(localized: "common.connecting", defaultValue: "Connecting...", bundle: .macOSBridge)
            connectButton.isEnabled = false
        } else if hasCredentials {
            statusIndicator.contentTintColor = .systemGreen
            statusLabel.stringValue = "Connected to \(HAAuthManager.shared.serverURL?.host ?? "server")"
            connectButton.title = String(localized: "settings.home_assistant.test_connection", defaultValue: "Test connection", bundle: .macOSBridge)
            connectButton.isEnabled = true
        } else {
            statusIndicator.contentTintColor = .systemGray
            statusLabel.stringValue = String(localized: "settings.home_assistant.not_connected", defaultValue: "Not connected", bundle: .macOSBridge)
            connectButton.title = String(localized: "common.connect", defaultValue: "Connect", bundle: .macOSBridge)
            connectButton.isEnabled = !serverURLField.stringValue.isEmpty && !accessTokenField.stringValue.isEmpty
        }

        disconnectButton.isEnabled = hasCredentials
    }

    @objc private func textFieldChanged() {
        updateUI()
    }

    @objc private func connectTapped() {
        let urlString = serverURLField.stringValue
        let token = accessTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            showAlert(title: String(localized: "alert.missing_credentials.title", defaultValue: "Missing credentials", bundle: .macOSBridge), message: String(localized: "alert.missing_credentials.message", defaultValue: "Please enter both server URL and access token.", bundle: .macOSBridge))
            return
        }

        let result = HAURLValidator.validate(urlString)
        guard case .success(let url) = result else {
            if case .failure(let message) = result {
                showAlert(title: String(localized: "alert.invalid_url.title", defaultValue: "Invalid URL", bundle: .macOSBridge), message: message)
            }
            return
        }

        // Save credentials
        HAAuthManager.shared.saveCredentials(serverURL: url, accessToken: token)

        // Test connection
        isConnecting = true
        updateUI()

        Task {
            do {
                let success = try await HAAuthManager.shared.validateCredentials()
                await MainActor.run {
                    isConnecting = false
                    if success {
                        updateUI()
                        showAlert(title: String(localized: "alert.connected.title", defaultValue: "Connected", bundle: .macOSBridge), message: String(localized: "alert.connected.message", defaultValue: "Successfully connected to Home Assistant.", bundle: .macOSBridge))
                        // Notify the app to connect
                        NotificationCenter.default.post(name: NSNotification.Name("HomeAssistantCredentialsChanged"), object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    HAAuthManager.shared.clearCredentials()
                    updateUI()
                    showAlert(title: String(localized: "alert.connection_failed.title", defaultValue: "Connection failed", bundle: .macOSBridge), message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func disconnectTapped() {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.disconnect.title", defaultValue: "Disconnect from Home Assistant?", bundle: .macOSBridge)
        alert.informativeText = String(localized: "alert.disconnect.message", defaultValue: "This will clear your saved credentials.", bundle: .macOSBridge)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "alert.disconnect.confirm", defaultValue: "Disconnect", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))

        if alert.runModal() == .alertFirstButtonReturn {
            HAAuthManager.shared.clearCredentials()
            serverURLField.stringValue = ""
            accessTokenField.stringValue = ""
            updateUI()
            // Notify the app to disconnect
            NotificationCenter.default.post(name: NSNotification.Name("HomeAssistantCredentialsChanged"), object: nil)
        }
    }

    private func loadPreferences() {
        switch PreferencesManager.shared.entityCategoryFilter {
        case "hideConfig": entityCategoryPopUp.selectItem(at: 1)
        case "hideDiagnostic": entityCategoryPopUp.selectItem(at: 2)
        case "showAll": entityCategoryPopUp.selectItem(at: 3)
        default: entityCategoryPopUp.selectItem(at: 0)
        }
    }

    @objc private func entityCategoryFilterChanged(_ sender: NSPopUpButton) {
        let values = ["hideAll", "hideConfig", "hideDiagnostic", "showAll"]
        PreferencesManager.shared.entityCategoryFilter = values[sender.indexOfSelectedItem]
    }

    private func createSettingRow(label: String, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelField = createLabel(label, style: .body)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelField)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 36),
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelField.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
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
