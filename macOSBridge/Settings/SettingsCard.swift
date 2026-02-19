//
//  SettingsCard.swift
//  macOSBridge
//
//  Base class for settings content cards with modern styling
//

import AppKit

class SettingsCard: NSView {

    let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCard()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCard() {
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func createGroupBox() -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 10
        // Use a color that's visible against the window background
        box.fillColor = NSColor(named: "GroupBoxBackground") ?? NSColor.white.withAlphaComponent(0.8)
        box.borderWidth = 0
        box.titlePosition = .noTitle
        box.translatesAutoresizingMaskIntoConstraints = false
        box.wantsLayer = true
        return box
    }

    func createSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }

    func createLabel(_ text: String, style: LabelStyle = .body) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        switch style {
        case .title:
            label.font = .systemFont(ofSize: 20, weight: .bold)
        case .subtitle:
            label.font = .systemFont(ofSize: 13)
            label.textColor = .secondaryLabelColor
        case .body:
            label.font = .systemFont(ofSize: 13)
        case .caption:
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
        case .sectionHeader:
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .labelColor
        case .code:
            label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            label.textColor = .secondaryLabelColor
        }
        return label
    }

    func createRow(label: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let labelField = createLabel(label, style: .body)
        row.addArrangedSubview(labelField)
        row.addArrangedSubview(NSView()) // Spacer
        row.addArrangedSubview(control)

        return row
    }

    enum LabelStyle {
        case title, subtitle, body, caption, sectionHeader, code
    }

    /// Creates a Pro-required banner with a button to navigate to the General section
    static func createProBanner() -> NSView {
        let banner = ProBannerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        return banner
    }
}

// MARK: - Adaptive background views

/// Rounded card background that adapts to light/dark mode
class CardBoxView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color = isDark ? NSColor(white: 0.18, alpha: 1.0) : NSColor(white: 0.97, alpha: 1.0)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        color.setFill()
        path.fill()
    }
}

/// Rounded background with a blue tint for Pro-related sections
class ProTintBoxView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color = isDark
            ? NSColor(red: 0.12, green: 0.16, blue: 0.25, alpha: 1.0)
            : NSColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        color.setFill()
        path.fill()
    }
}

private class ProBannerView: ProTintBoxView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let iconView = NSImageView()
        iconView.image = PhosphorIcon.fill("lock")
        iconView.contentTintColor = .systemBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        let label = NSTextField(wrappingLabelWithString: String(localized: "settings.pro.banner", defaultValue: "This feature is available to Itsyhome Pro subscribers.", bundle: .macOSBridge))
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        let button = NSButton(title: String(localized: "settings.pro.get_pro_button", defaultValue: "Get Pro", bundle: .macOSBridge), target: self, action: #selector(getProTapped))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -8),

            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @objc private func getProTapped() {
        NotificationCenter.default.post(
            name: SettingsView.navigateToSectionNotification,
            object: nil,
            userInfo: ["index": 0]
        )
    }
}
