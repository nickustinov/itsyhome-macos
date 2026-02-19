//
//  HASuccessWindowController.swift
//  macOSBridge
//
//  Onboarding success screen after connecting to Home Assistant
//

import AppKit

protocol HASuccessDelegate: AnyObject {
    func haSuccessDidFinish()
}

class HASuccessWindowController: NSWindowController {

    weak var delegate: HASuccessDelegate?

    private let successView: HASuccessView

    init(deviceCount: Int, areaCount: Int) {
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

        successView = HASuccessView(deviceCount: deviceCount, areaCount: areaCount)

        super.init(window: window)

        window.contentView = successView
        window.setContentSize(NSSize(width: 500, height: 420))

        successView.onFinish = { [weak self] in
            self?.window?.close()
            self?.delegate?.haSuccessDidFinish()
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
}

// MARK: - Success view

class HASuccessView: NSView {

    var onFinish: (() -> Void)?

    override init(frame frameRect: NSRect) {
        fatalError("Use init(deviceCount:areaCount:)")
    }

    init(deviceCount: Int, areaCount: Int) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        setupViews(deviceCount: deviceCount, areaCount: areaCount)
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

    private func setupViews(deviceCount: Int, areaCount: Int) {
        let pluginBundle = Bundle(for: HASuccessView.self)
        let horizontalInset: CGFloat = 48

        // HA icon
        let iconView = NSImageView()
        iconView.image = pluginBundle.image(forResource: "ha")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Green check badge
        let checkView = NSImageView()
        checkView.image = PhosphorIcon.fill("check-circle")
        checkView.contentTintColor = .systemGreen
        checkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkView)

        // Title
        let titleLabel = NSTextField(labelWithString: String(localized: "onboarding.connected", defaultValue: "You're connected!", bundle: .macOSBridge))
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Device count subtitle
        let devicesText: String
        if areaCount > 0 {
            devicesText = String(localized: "onboarding.found_devices_areas", defaultValue: "Itsyhome found \(deviceCount) devices in \(areaCount) areas.", bundle: .macOSBridge)
        } else {
            devicesText = String(localized: "onboarding.found_devices", defaultValue: "Itsyhome found \(deviceCount) devices.", bundle: .macOSBridge)
        }
        let subtitleLabel = NSTextField(labelWithString: devicesText)
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        // "Rooms" header
        let roomsHeader = NSTextField(labelWithString: String(localized: "onboarding.organized_by_areas", defaultValue: "Organized by areas", bundle: .macOSBridge))
        roomsHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        roomsHeader.textColor = .labelColor
        roomsHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(roomsHeader)

        // Rooms body
        let roomsBody = NSTextField(wrappingLabelWithString: String(localized: "onboarding.areas_description", defaultValue: "Your devices are automatically organized by area. Each area appears as a room submenu in Itsyhome.", bundle: .macOSBridge))
        roomsBody.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        roomsBody.textColor = .secondaryLabelColor
        roomsBody.translatesAutoresizingMaskIntoConstraints = false
        addSubview(roomsBody)

        // "Custom layout" header
        let customHeader = NSTextField(labelWithString: String(localized: "onboarding.custom_layout", defaultValue: "Custom layout", bundle: .macOSBridge))
        customHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        customHeader.textColor = .labelColor
        customHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(customHeader)

        // Custom layout body with bold parts
        let customBody = NSTextField(wrappingLabelWithString: "")
        customBody.attributedStringValue = Self.buildCustomLayoutText()
        customBody.translatesAutoresizingMaskIntoConstraints = false
        addSubview(customBody)

        // Start exploring button
        let startButton = NSButton(title: String(localized: "onboarding.start_exploring", defaultValue: "Start exploring", bundle: .macOSBridge), target: self, action: #selector(finishTapped))
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"
        startButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(startButton)

        NSLayoutConstraint.activate([
            // HA icon
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            // Green check overlapping bottom-right of icon
            checkView.widthAnchor.constraint(equalToConstant: 20),
            checkView.heightAnchor.constraint(equalToConstant: 20),
            checkView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -6),
            checkView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),

            // Title
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            // Separator
            separator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),

            // Rooms header
            roomsHeader.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
            roomsHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // Rooms body
            roomsBody.topAnchor.constraint(equalTo: roomsHeader.bottomAnchor, constant: 4),
            roomsBody.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            roomsBody.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),

            // Custom layout header
            customHeader.topAnchor.constraint(equalTo: roomsBody.bottomAnchor, constant: 16),
            customHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),

            // Custom layout body
            customBody.topAnchor.constraint(equalTo: customHeader.bottomAnchor, constant: 4),
            customBody.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            customBody.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),

            // Start button
            startButton.topAnchor.constraint(equalTo: customBody.bottomAnchor, constant: 20),
            startButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            startButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
    }

    private static func buildCustomLayoutText() -> NSAttributedString {
        let regular = NSFont.systemFont(ofSize: 13, weight: .regular)
        let bold = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let color = NSColor.secondaryLabelColor

        let result = NSMutableAttributedString()

        let parts: [(String, NSFont)] = [
            ("Want a custom layout? Use ", regular),
            ("Create group", bold),
            (" button in Settings \u{2192} Home to organize entities. Use ", regular),
            ("pin", bold),
            (" icon to pin entities or groups to menu bar, or use ", regular),
            ("star", bold),
            (" icon to add favourite entities to the top of the menu.", regular),
        ]

        for (text, font) in parts {
            result.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
            ]))
        }

        return result
    }

    @objc private func finishTapped() {
        onFinish?()
    }
}
