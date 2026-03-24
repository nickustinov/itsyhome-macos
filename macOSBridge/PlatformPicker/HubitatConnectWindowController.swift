//
//  HubitatConnectWindowController.swift
//  macOSBridge
//
//  Onboarding screen for connecting to Hubitat
//

import AppKit

protocol HubitatConnectDelegate: AnyObject {
    func hubitatConnectDidSucceed(hubURL: String, appId: String, accessToken: String, deviceCount: Int)
    func hubitatConnectDidCancel()
}

class HubitatConnectWindowController: NSWindowController {

    weak var delegate: HubitatConnectDelegate?

    private let connectView: HubitatConnectView

    init() {
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.level = .normal

        connectView = HubitatConnectView()

        super.init(window: window)

        window.contentView = connectView
        window.setContentSize(NSSize(width: 500, height: 420))

        connectView.onConnect = { [weak self] hubURL, appId, accessToken in
            self?.attemptConnection(hubURL: hubURL, appId: appId, accessToken: accessToken)
        }

        connectView.onCancel = { [weak self] in
            self?.window?.close()
            self?.delegate?.hubitatConnectDidCancel()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        guard let window = window else { return }

        window.center()
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func attemptConnection(hubURL: String, appId: String, accessToken: String) {
        // Validate URL
        guard let url = URL(string: hubURL), url.scheme != nil, url.host != nil else {
            connectView.showError(String(localized: "alert.enter_valid_hub_url", defaultValue: "Please enter a valid hub URL (e.g. http://192.168.1.100)", bundle: .macOSBridge))
            return
        }

        connectView.setConnecting(true)

        // Save credentials temporarily and validate
        HubitatAuthManager.shared.saveCredentials(hubURL: url, appId: appId, accessToken: accessToken)

        Task {
            do {
                let deviceCount = try await HubitatAuthManager.shared.validateAndFetchDeviceCount()
                await MainActor.run {
                    self.connectView.setConnecting(false)
                    self.window?.close()
                    self.delegate?.hubitatConnectDidSucceed(
                        hubURL: hubURL,
                        appId: appId,
                        accessToken: accessToken,
                        deviceCount: deviceCount
                    )
                }
            } catch {
                await MainActor.run {
                    HubitatAuthManager.shared.clearCredentials()
                    self.connectView.setConnecting(false)
                    self.connectView.showError(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Connect view

class HubitatConnectView: NSView {

    var onConnect: ((_ hubURL: String, _ appId: String, _ accessToken: String) -> Void)?
    var onCancel: (() -> Void)?

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: String(localized: "onboarding.hubitat_connect_title", defaultValue: "Connect to Hubitat", bundle: .macOSBridge))
    private let urlLabel = NSTextField(labelWithString: String(localized: "onboarding.hub_url", defaultValue: "Hub URL", bundle: .macOSBridge))
    private let urlField = NSTextField()
    private let appIdLabel = NSTextField(labelWithString: String(localized: "onboarding.maker_api_app_id", defaultValue: "Maker API App ID", bundle: .macOSBridge))
    private let appIdField = NSTextField()
    private let tokenLabel = NSTextField(labelWithString: String(localized: "onboarding.access_token", defaultValue: "Access token", bundle: .macOSBridge))
    private let tokenField = NSSecureTextField()
    private let helpLabel = NSTextField(labelWithString: String(localized: "onboarding.hubitat_help", defaultValue: "Configure Maker API in your Hubitat hub under Apps > Maker API", bundle: .macOSBridge))
    private let errorLabel = NSTextField(labelWithString: "")
    private let connectButton = NSButton(title: String(localized: "common.connect", defaultValue: "Connect", bundle: .macOSBridge), target: nil, action: nil)
    private let backButton = NSButton(title: String(localized: "common.back", defaultValue: "Back", bundle: .macOSBridge), target: nil, action: nil)
    private let spinner = NSProgressIndicator()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bgColor = isDark ? NSColor(white: 0.15, alpha: 1.0) : NSColor(white: 0.98, alpha: 1.0)
        bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
    }

    func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }

    func setConnecting(_ connecting: Bool) {
        connectButton.isEnabled = !connecting
        urlField.isEnabled = !connecting
        appIdField.isEnabled = !connecting
        tokenField.isEnabled = !connecting
        if connecting {
            spinner.startAnimation(nil)
            spinner.isHidden = false
            connectButton.title = String(localized: "common.connecting", defaultValue: "Connecting...", bundle: .macOSBridge)
        } else {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            connectButton.title = String(localized: "common.connect", defaultValue: "Connect", bundle: .macOSBridge)
        }
    }

    private func setupViews() {
        let pluginBundle = Bundle(for: HubitatConnectView.self)

        // Hubitat icon
        iconView.image = pluginBundle.image(forResource: "hubitat")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Hub URL label
        urlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(urlLabel)

        // Hub URL field
        urlField.isEditable = true
        urlField.isSelectable = true
        urlField.isBezeled = true
        urlField.bezelStyle = .roundedBezel
        urlField.font = NSFont.systemFont(ofSize: 14)
        urlField.placeholderString = "http://192.168.1.xxx"
        urlField.placeholderAttributedString = NSAttributedString(
            string: "http://192.168.1.xxx",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        urlField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(urlField)

        // App ID label
        appIdLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        appIdLabel.textColor = .secondaryLabelColor
        appIdLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appIdLabel)

        // App ID field
        appIdField.isEditable = true
        appIdField.isSelectable = true
        appIdField.isBezeled = true
        appIdField.bezelStyle = .roundedBezel
        appIdField.font = NSFont.systemFont(ofSize: 14)
        appIdField.placeholderString = "e.g., 42"
        appIdField.placeholderAttributedString = NSAttributedString(
            string: "e.g., 42",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        appIdField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appIdField)

        // Token label
        tokenLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        tokenLabel.textColor = .secondaryLabelColor
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tokenLabel)

        // Token field
        tokenField.isEditable = true
        tokenField.isSelectable = true
        tokenField.isBezeled = true
        tokenField.bezelStyle = .roundedBezel
        tokenField.font = NSFont.systemFont(ofSize: 14)
        if let secureCell = tokenField.cell as? NSSecureTextFieldCell {
            secureCell.echosBullets = true
        }
        tokenField.placeholderString = String(localized: "onboarding.paste_token", defaultValue: "Paste your token here", bundle: .macOSBridge)
        tokenField.placeholderAttributedString = NSAttributedString(
            string: String(localized: "onboarding.paste_token", defaultValue: "Paste your token here", bundle: .macOSBridge),
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        tokenField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tokenField)

        // Help label
        helpLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        helpLabel.textColor = .tertiaryLabelColor
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(helpLabel)

        // Error label
        errorLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.isHidden = true
        errorLabel.maximumNumberOfLines = 2
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.preferredMaxLayoutWidth = 400
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(errorLabel)

        // Spinner
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        // Connect button
        connectButton.bezelStyle = .rounded
        connectButton.keyEquivalent = "\r"
        connectButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        connectButton.target = self
        connectButton.action = #selector(connectTapped)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(connectButton)

        // Back button
        backButton.bezelStyle = .rounded
        backButton.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        backButton.target = self
        backButton.action = #selector(backTapped)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backButton)

        let horizontalInset: CGFloat = 48

        NSLayoutConstraint.activate([
            // Icon
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            // Title
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            // URL label
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            urlLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // URL field
            urlField.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 6),
            urlField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            urlField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            urlField.heightAnchor.constraint(equalToConstant: 28),

            // App ID label
            appIdLabel.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 18),
            appIdLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // App ID field
            appIdField.topAnchor.constraint(equalTo: appIdLabel.bottomAnchor, constant: 6),
            appIdField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            appIdField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            appIdField.heightAnchor.constraint(equalToConstant: 28),

            // Token label
            tokenLabel.topAnchor.constraint(equalTo: appIdField.bottomAnchor, constant: 18),
            tokenLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // Token field
            tokenField.topAnchor.constraint(equalTo: tokenLabel.bottomAnchor, constant: 6),
            tokenField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            tokenField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            tokenField.heightAnchor.constraint(equalToConstant: 28),

            // Help label
            helpLabel.topAnchor.constraint(equalTo: tokenField.bottomAnchor, constant: 4),
            helpLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // Error label
            errorLabel.topAnchor.constraint(equalTo: helpLabel.bottomAnchor, constant: 12),
            errorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: horizontalInset),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -horizontalInset),

            // Spinner
            spinner.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: connectButton.leadingAnchor, constant: -8),

            // Buttons
            connectButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            connectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            connectButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),

            backButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
        ])
    }

    @objc private func connectTapped() {
        errorLabel.isHidden = true
        let hubURL = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let appId = appIdField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if hubURL.isEmpty {
            showError(String(localized: "alert.enter_hub_url", defaultValue: "Please enter a hub URL", bundle: .macOSBridge))
            return
        }

        if appId.isEmpty {
            showError(String(localized: "alert.enter_app_id", defaultValue: "Please enter a Maker API App ID", bundle: .macOSBridge))
            return
        }

        if accessToken.isEmpty {
            showError(String(localized: "alert.enter_access_token", defaultValue: "Please enter an access token", bundle: .macOSBridge))
            return
        }

        onConnect?(hubURL, appId, accessToken)
    }

    @objc private func backTapped() {
        onCancel?()
    }
}
