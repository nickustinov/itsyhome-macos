//
//  PlatformPickerWindowController.swift
//  macOSBridge
//
//  First-launch platform picker window
//

import AppKit

protocol PlatformPickerDelegate: AnyObject {
    func platformPickerDidSelectHomeKit()
    func platformPickerDidSelectHomeAssistant()
}

class PlatformPickerWindowController: NSWindowController {

    weak var delegate: PlatformPickerDelegate?

    private let pickerView: PlatformPickerView

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 370),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.level = .floating

        pickerView = PlatformPickerView()

        super.init(window: window)

        window.contentView = pickerView
        window.setContentSize(NSSize(width: 500, height: 370))

        pickerView.onHomeKitSelected = { [weak self] in
            self?.window?.close()
            self?.delegate?.platformPickerDidSelectHomeKit()
        }

        pickerView.onHomeAssistantSelected = { [weak self] in
            self?.window?.close()
            self?.delegate?.platformPickerDidSelectHomeAssistant()
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

// MARK: - Platform picker view

class PlatformPickerView: NSView {

    var onHomeKitSelected: (() -> Void)?
    var onHomeAssistantSelected: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Welcome to Itsyhome")
    private let subtitleLabel = NSTextField(labelWithString: "Choose your smart home platform")
    private let homeKitCard: PlatformCard
    private let homeAssistantCard: PlatformCard
    private let footerLabel = NSTextField(labelWithString: "You can change this later in Settings")

    override init(frame frameRect: NSRect) {
        let pluginBundle = Bundle(for: PlatformPickerView.self)

        homeKitCard = PlatformCard(
            title: "HomeKit",
            subtitle: "Apple's built-in smart home framework",
            icon: pluginBundle.image(forResource: "homekit") ?? NSImage()
        )
        homeAssistantCard = PlatformCard(
            title: "Home Assistant",
            subtitle: "Open-source home automation",
            icon: pluginBundle.image(forResource: "ha") ?? NSImage()
        )

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

    private func setupViews() {
        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // Cards container
        let cardsStack = NSStackView(views: [homeKitCard, homeAssistantCard])
        cardsStack.orientation = .horizontal
        cardsStack.spacing = 20
        cardsStack.distribution = .fillEqually
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardsStack)

        // Card actions
        homeKitCard.onClick = { [weak self] in
            self?.onHomeKitSelected?()
        }
        homeAssistantCard.onClick = { [weak self] in
            self?.onHomeAssistantSelected?()
        }

        // Footer
        footerLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.alignment = .center
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(footerLabel)

        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            // Cards
            cardsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            cardsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            cardsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            cardsStack.heightAnchor.constraint(equalToConstant: 190),

            // Footer
            footerLabel.topAnchor.constraint(equalTo: cardsStack.bottomAnchor, constant: 20),
            footerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}

// MARK: - Platform card

class PlatformCard: NSView {

    var onClick: (() -> Void)?

    private let iconView = NSImageView()
    private let titleLabel: NSTextField
    private let subtitleLabel: NSTextField
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init(title: String, subtitle: String, icon: NSImage) {
        titleLabel = NSTextField(labelWithString: title)
        subtitleLabel = NSTextField(labelWithString: subtitle)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 12

        // Icon
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 140
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -24),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 140),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let bgColor: NSColor
        if isHovered {
            bgColor = isDark ? NSColor(white: 0.28, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)
        } else {
            bgColor = isDark ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.93, alpha: 1.0)
        }

        bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.set()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.arrow.set()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        // Visual feedback
        alphaValue = 0.7
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            onClick?()
        }
    }
}
