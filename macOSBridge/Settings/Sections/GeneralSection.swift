//
//  GeneralSection.swift
//  macOSBridge
//
//  General settings section with Pro subscription
//

import AppKit
import Combine

class GeneralSection: SettingsCard {

    private let launchSwitch = NSSwitch()
    private let gridSwitch = NSSwitch()

    // Pro section
    private var cancellables = Set<AnyCancellable>()
    private var proBox: NSView!
    private let proBadge = NSTextField()
    private let thankYouLabel = NSTextField()
    private var proTitleLabel: NSTextField!
    private var proSubtitleLabel: NSTextField!
    private var buttonStack: NSStackView!
    private let yearlyButton = NSButton()
    private let lifetimeButton = NSButton()
    private let restoreButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        setupProSection()
        loadPreferences()
        setupBindings()
        updateProVisibility()
        updateButtonTitles()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        // Launch at login box
        let launchBox = createCardBox()
        launchSwitch.controlSize = .small
        launchSwitch.target = self
        launchSwitch.action = #selector(launchSwitchChanged)
        let launchRow = createSettingRow(label: "Launch Itsyhome at login", control: launchSwitch)
        addContentToBox(launchBox, content: launchRow)
        stackView.addArrangedSubview(launchBox)
        launchBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Grid view box
        let gridBox = createCardBox()
        gridSwitch.controlSize = .small
        gridSwitch.target = self
        gridSwitch.action = #selector(gridSwitchChanged)
        let gridRow = createSettingRow(
            label: "Show scenes as grid",
            subtitle: "Display scenes in a compact grid layout instead of a list.",
            control: gridSwitch
        )
        addContentToBox(gridBox, content: gridRow)
        stackView.addArrangedSubview(gridBox)
        gridBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func setupProSection() {
        // Pro subscription box with gradient-like appearance
        proBox = NSView()
        proBox.wantsLayer = true
        proBox.layer?.backgroundColor = NSColor(red: 0.95, green: 0.92, blue: 1.0, alpha: 1.0).cgColor
        proBox.layer?.cornerRadius = 10
        proBox.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .horizontal
        content.spacing = 16
        content.alignment = .centerY
        content.translatesAutoresizingMaskIntoConstraints = false
        proBox.addSubview(content)

        // Star icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Pro")
        iconView.contentTintColor = NSColor.systemPurple
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 36).isActive = true
        content.addArrangedSubview(iconView)

        // Text stack
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading

        // Pro badge (shown when subscribed)
        proBadge.stringValue = "ACTIVE"
        proBadge.font = .systemFont(ofSize: 9, weight: .bold)
        proBadge.textColor = .white
        proBadge.backgroundColor = .systemGreen
        proBadge.drawsBackground = true
        proBadge.alignment = .center
        proBadge.isBezeled = false
        proBadge.isEditable = false
        proBadge.wantsLayer = true
        proBadge.layer?.cornerRadius = 3
        proBadge.translatesAutoresizingMaskIntoConstraints = false

        thankYouLabel.stringValue = "Thank you for your support!"
        thankYouLabel.font = .systemFont(ofSize: 11)
        thankYouLabel.textColor = .secondaryLabelColor
        thankYouLabel.isBezeled = false
        thankYouLabel.isEditable = false
        thankYouLabel.drawsBackground = false

        // Title row
        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 6
        titleRow.alignment = .centerY

        proTitleLabel = createLabel("Itsyhome Pro", style: .body)
        proTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        titleRow.addArrangedSubview(proTitleLabel)
        titleRow.addArrangedSubview(proBadge)
        textStack.addArrangedSubview(titleRow)

        // Thank you (shown when subscribed)
        textStack.addArrangedSubview(thankYouLabel)

        // Subtitle (shown when not subscribed)
        proSubtitleLabel = createLabel("Unlock powerful automation with deeplinks, webhooks, and more.", style: .caption)
        textStack.addArrangedSubview(proSubtitleLabel)

        content.addArrangedSubview(textStack)

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        content.addArrangedSubview(spacer)

        // Buttons stack
        buttonStack = NSStackView()
        buttonStack.orientation = .vertical
        buttonStack.spacing = 4
        buttonStack.alignment = .trailing

        let purchaseRow = NSStackView()
        purchaseRow.orientation = .horizontal
        purchaseRow.spacing = 10

        yearlyButton.title = "Yearly"
        yearlyButton.bezelStyle = .rounded
        yearlyButton.controlSize = .large
        yearlyButton.isEnabled = false
        yearlyButton.target = self
        yearlyButton.action = #selector(yearlyTapped)

        lifetimeButton.title = "Lifetime"
        lifetimeButton.bezelStyle = .rounded
        lifetimeButton.controlSize = .large
        lifetimeButton.isEnabled = false
        lifetimeButton.target = self
        lifetimeButton.action = #selector(lifetimeTapped)

        purchaseRow.addArrangedSubview(yearlyButton)
        purchaseRow.addArrangedSubview(lifetimeButton)

        restoreButton.title = "Restore purchases"
        restoreButton.bezelStyle = .inline
        restoreButton.controlSize = .small
        restoreButton.isBordered = false
        restoreButton.contentTintColor = .secondaryLabelColor
        restoreButton.target = self
        restoreButton.action = #selector(restoreTapped)

        buttonStack.addArrangedSubview(purchaseRow)
        buttonStack.addArrangedSubview(restoreButton)
        content.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: proBox.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: proBox.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: proBox.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: proBox.bottomAnchor, constant: -16),
            proBadge.widthAnchor.constraint(equalToConstant: 44),
            proBadge.heightAnchor.constraint(equalToConstant: 16)
        ])

        stackView.addArrangedSubview(proBox)
        proBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func createCardBox() -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor
        box.layer?.cornerRadius = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func addContentToBox(_ box: NSView, content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 6),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -6)
        ])
    }

    private func createSettingRow(label: String, subtitle: String? = nil, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let labelField = createLabel(label, style: .body)
        labelStack.addArrangedSubview(labelField)

        if let subtitle = subtitle {
            let subtitleField = createLabel(subtitle, style: .caption)
            subtitleField.lineBreakMode = .byWordWrapping
            subtitleField.maximumNumberOfLines = 2
            labelStack.addArrangedSubview(subtitleField)
        }

        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelStack)
        container.addSubview(control)

        let rowHeight: CGFloat = subtitle != nil ? 56 : 36

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: rowHeight),
            labelStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func loadPreferences() {
        launchSwitch.state = PreferencesManager.shared.launchAtLogin ? .on : .off
        gridSwitch.state = PreferencesManager.shared.scenesDisplayMode == .grid ? .on : .off
    }

    private func updateProVisibility() {
        let isPro = ProStatusCache.shared.isPro

        proBadge.isHidden = !isPro
        thankYouLabel.isHidden = !isPro

        proSubtitleLabel.isHidden = isPro
        buttonStack.isHidden = isPro
    }

    private func updateButtonTitles() {
        if let yearly = ProManager.shared.yearlyProduct {
            yearlyButton.title = "\(yearly.displayPrice)/year"
            yearlyButton.isEnabled = true
        }
        if let lifetime = ProManager.shared.lifetimeProduct {
            lifetimeButton.title = "\(lifetime.displayPrice) lifetime"
            lifetimeButton.isEnabled = true
        }
    }

    private func setupBindings() {
        ProManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateProVisibility() }
            .store(in: &cancellables)

        ProManager.shared.$products
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButtonTitles() }
            .store(in: &cancellables)
    }

    @objc private func launchSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.launchAtLogin = sender.state == .on
    }

    @objc private func gridSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.scenesDisplayMode = sender.state == .on ? .grid : .list
    }

    @objc private func yearlyTapped() {
        guard let product = ProManager.shared.yearlyProduct else { return }
        Task {
            do { _ = try await ProManager.shared.purchase(product) }
            catch { print("Purchase error: \(error)") }
        }
    }

    @objc private func lifetimeTapped() {
        guard let product = ProManager.shared.lifetimeProduct else { return }
        Task {
            do { _ = try await ProManager.shared.purchase(product) }
            catch { print("Purchase error: \(error)") }
        }
    }

    @objc private func restoreTapped() {
        Task { await ProManager.shared.restore() }
    }
}
