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
}
