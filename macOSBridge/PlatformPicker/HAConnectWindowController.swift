//
//  HAConnectWindowController.swift
//  macOSBridge
//
//  Onboarding screen for connecting to Home Assistant
//

import AppKit

protocol HAConnectDelegate: AnyObject {
    func haConnectDidSucceed(serverURL: String, accessToken: String, deviceCount: Int, areaCount: Int)
    func haConnectDidCancel()
}

// Borderless windows refuse key status by default; override so text fields work
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

class HAConnectWindowController: NSWindowController {

    weak var delegate: HAConnectDelegate?

    private let connectView: HAConnectView

    init() {
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 370),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.level = .normal

        connectView = HAConnectView()

        super.init(window: window)

        window.contentView = connectView
        window.setContentSize(NSSize(width: 500, height: 370))

        connectView.onConnect = { [weak self] serverURL, accessToken in
            self?.attemptConnection(serverURL: serverURL, accessToken: accessToken)
        }

        connectView.onCancel = { [weak self] in
            self?.window?.close()
            self?.delegate?.haConnectDidCancel()
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

    private func attemptConnection(serverURL: String, accessToken: String) {
        // Validate URL
        let result = HAURLValidator.validate(serverURL)
        guard case .success(let url) = result else {
            if case .failure(let message) = result {
                connectView.showError(message)
            }
            return
        }

        connectView.setConnecting(true)

        // Save credentials temporarily and validate
        HAAuthManager.shared.saveCredentials(serverURL: url, accessToken: accessToken)

        Task {
            do {
                let counts = try await HAAuthManager.shared.validateAndFetchCounts()
                await MainActor.run {
                    self.connectView.setConnecting(false)
                    self.window?.close()
                    self.delegate?.haConnectDidSucceed(
                        serverURL: serverURL,
                        accessToken: accessToken,
                        deviceCount: counts.deviceCount,
                        areaCount: counts.areaCount
                    )
                }
            } catch {
                await MainActor.run {
                    HAAuthManager.shared.clearCredentials()
                    self.connectView.setConnecting(false)
                    self.connectView.showError(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Connect view

class HAConnectView: NSView {

    var onConnect: ((_ serverURL: String, _ accessToken: String) -> Void)?
    var onCancel: (() -> Void)?

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Connect to Home Assistant")
    private let urlLabel = NSTextField(labelWithString: "Server URL")
    private let urlField = NSTextField()
    private let tokenLabel = NSTextField(labelWithString: "Long-lived access token")
    private let tokenField = NSSecureTextField()
    private let tokenHintLabel = NSTextField(labelWithString: "Get your token in HA > Profile > Security > Long-Lived Access Tokens")
    private let errorLabel = NSTextField(labelWithString: "")
    private let connectButton = NSButton(title: "Connect", target: nil, action: nil)
    private let backButton = NSButton(title: "Back", target: nil, action: nil)
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
        tokenField.isEnabled = !connecting
        if connecting {
            spinner.startAnimation(nil)
            spinner.isHidden = false
            connectButton.title = "Connecting..."
        } else {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            connectButton.title = "Connect"
        }
    }

    private func setupViews() {
        let pluginBundle = Bundle(for: HAConnectView.self)

        // HA icon
        iconView.image = pluginBundle.image(forResource: "ha")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // URL label
        urlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(urlLabel)

        // URL field
        urlField.isEditable = true
        urlField.isSelectable = true
        urlField.isBezeled = true
        urlField.bezelStyle = .roundedBezel
        urlField.font = NSFont.systemFont(ofSize: 14)
        urlField.placeholderString = "http://homeassistant.local:8123"
        urlField.placeholderAttributedString = NSAttributedString(
            string: "http://homeassistant.local:8123",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        urlField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(urlField)

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
        tokenField.placeholderString = "Paste your token here"
        tokenField.placeholderAttributedString = NSAttributedString(
            string: "Paste your token here",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        tokenField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tokenField)

        // Token hint
        tokenHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        tokenHintLabel.textColor = .tertiaryLabelColor
        tokenHintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tokenHintLabel)

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

            // Token label
            tokenLabel.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 18),
            tokenLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // Token field
            tokenField.topAnchor.constraint(equalTo: tokenLabel.bottomAnchor, constant: 6),
            tokenField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            tokenField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            tokenField.heightAnchor.constraint(equalToConstant: 28),

            // Token hint
            tokenHintLabel.topAnchor.constraint(equalTo: tokenField.bottomAnchor, constant: 4),
            tokenHintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // Error label
            errorLabel.topAnchor.constraint(equalTo: tokenHintLabel.bottomAnchor, constant: 12),
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
        let serverURL = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if serverURL.isEmpty {
            showError("Please enter a server URL")
            return
        }

        if accessToken.isEmpty {
            showError("Please enter an access token")
            return
        }

        onConnect?(serverURL, accessToken)
    }

    @objc private func backTapped() {
        onCancel?()
    }
}
