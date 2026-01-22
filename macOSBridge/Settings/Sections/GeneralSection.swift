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
    private let syncSwitch = NSSwitch()
    private var syncStatusLabel: NSTextField!
    private var syncProBadge: NSView!

    // Pro section
    private var cancellables = Set<AnyCancellable>()
    private var proBox: NSView!
    private let proBadge = NSView()
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
        launchSwitch.controlSize = .mini
        launchSwitch.target = self
        launchSwitch.action = #selector(launchSwitchChanged)
        let launchRow = createSettingRow(label: "Launch Itsyhome at login", control: launchSwitch)
        addContentToBox(launchBox, content: launchRow)
        stackView.addArrangedSubview(launchBox)
        launchBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Grid view box
        let gridBox = createCardBox()
        gridSwitch.controlSize = .mini
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

        // iCloud sync box
        let syncBox = createCardBox()
        syncSwitch.controlSize = .mini
        syncSwitch.target = self
        syncSwitch.action = #selector(syncSwitchChanged)
        let syncRow = createSyncSettingRow()
        addContentToBox(syncBox, content: syncRow)
        stackView.addArrangedSubview(syncBox)
        syncBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func createSyncSettingRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        // Header row with label and Pro badge
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.spacing = 6
        headerRow.alignment = .centerY

        let labelField = createLabel("iCloud sync", style: .body)
        headerRow.addArrangedSubview(labelField)

        // Pro badge (only shown for non-Pro users)
        syncProBadge = NSView()
        syncProBadge.wantsLayer = true
        syncProBadge.layer?.backgroundColor = NSColor.systemPurple.cgColor
        syncProBadge.layer?.cornerRadius = 3
        syncProBadge.translatesAutoresizingMaskIntoConstraints = false
        syncProBadge.widthAnchor.constraint(equalToConstant: 26).isActive = true
        syncProBadge.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let badgeLabel = NSTextField(labelWithString: "PRO")
        badgeLabel.font = .systemFont(ofSize: 8, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        syncProBadge.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.centerXAnchor.constraint(equalTo: syncProBadge.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: syncProBadge.centerYAnchor)
        ])
        headerRow.addArrangedSubview(syncProBadge)

        labelStack.addArrangedSubview(headerRow)

        // Status label
        syncStatusLabel = createLabel("Sync favourites across your devices.", style: .caption)
        syncStatusLabel.lineBreakMode = .byWordWrapping
        syncStatusLabel.maximumNumberOfLines = 2
        labelStack.addArrangedSubview(syncStatusLabel)

        syncSwitch.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelStack)
        container.addSubview(syncSwitch)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 56),
            labelStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: syncSwitch.leadingAnchor, constant: -16),
            syncSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            syncSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func setupProSection() {
        // Pro subscription box with gradient-like appearance
        proBox = NSView()
        proBox.wantsLayer = true
        proBox.layer?.backgroundColor = NSColor(red: 0.95, green: 0.92, blue: 1.0, alpha: 1.0).cgColor
        proBox.layer?.cornerRadius = 10
        proBox.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 12
        content.alignment = .leading
        content.translatesAutoresizingMaskIntoConstraints = false
        proBox.addSubview(content)

        // Header row with icon and title
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .centerY

        // Star icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Pro")
        iconView.contentTintColor = NSColor.systemPurple
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        headerRow.addArrangedSubview(iconView)

        proTitleLabel = createLabel("Itsyhome Pro", style: .body)
        proTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        headerRow.addArrangedSubview(proTitleLabel)

        // Pro badge (shown when subscribed)
        proBadge.wantsLayer = true
        proBadge.layer?.backgroundColor = NSColor.systemGreen.cgColor
        proBadge.layer?.cornerRadius = 3
        proBadge.translatesAutoresizingMaskIntoConstraints = false
        proBadge.widthAnchor.constraint(equalToConstant: 44).isActive = true
        proBadge.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let proBadgeLabel = NSTextField(labelWithString: "ACTIVE")
        proBadgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        proBadgeLabel.textColor = .white
        proBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        proBadge.addSubview(proBadgeLabel)
        NSLayoutConstraint.activate([
            proBadgeLabel.centerXAnchor.constraint(equalTo: proBadge.centerXAnchor),
            proBadgeLabel.centerYAnchor.constraint(equalTo: proBadge.centerYAnchor)
        ])

        headerRow.addArrangedSubview(proBadge)

        content.addArrangedSubview(headerRow)

        // Thank you label (shown when subscribed)
        thankYouLabel.stringValue = "Thank you for your support!"
        thankYouLabel.font = .systemFont(ofSize: 11)
        thankYouLabel.textColor = .secondaryLabelColor
        thankYouLabel.isBezeled = false
        thankYouLabel.isEditable = false
        thankYouLabel.drawsBackground = false
        content.addArrangedSubview(thankYouLabel)

        // Subtitle (shown when not subscribed)
        proSubtitleLabel = createLabel("Unlock deeplinks, webhooks, and more.", style: .caption)
        content.addArrangedSubview(proSubtitleLabel)

        // Buttons stack
        buttonStack = NSStackView()
        buttonStack.orientation = .vertical
        buttonStack.spacing = 8
        buttonStack.alignment = .leading

        let purchaseRow = NSStackView()
        purchaseRow.orientation = .horizontal
        purchaseRow.spacing = 8

        yearlyButton.title = "Yearly"
        yearlyButton.bezelStyle = .rounded
        yearlyButton.controlSize = .regular
        yearlyButton.isEnabled = false
        yearlyButton.target = self
        yearlyButton.action = #selector(yearlyTapped)

        lifetimeButton.title = "Lifetime"
        lifetimeButton.bezelStyle = .rounded
        lifetimeButton.controlSize = .regular
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
            content.topAnchor.constraint(equalTo: proBox.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: proBox.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: proBox.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: proBox.bottomAnchor, constant: -12)
        ])

        stackView.addArrangedSubview(proBox)
        proBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func createCardBox() -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(white: 0.97, alpha: 1.0).cgColor
        box.layer?.cornerRadius = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func addContentToBox(_ box: NSView, content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4)
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
        syncSwitch.state = CloudSyncManager.shared.isSyncEnabled ? .on : .off
        updateSyncUI()
    }

    private func updateSyncUI() {
        let isPro = ProStatusCache.shared.isPro
        syncSwitch.isEnabled = isPro
        syncProBadge.isHidden = isPro

        if !isPro {
            syncStatusLabel.stringValue = "Requires Pro to sync across devices."
        } else if CloudSyncManager.shared.isSyncEnabled {
            if let lastSync = CloudSyncManager.shared.lastSyncTimestamp {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let relative = formatter.localizedString(for: lastSync, relativeTo: Date())
                syncStatusLabel.stringValue = "Last synced \(relative)."
            } else {
                syncStatusLabel.stringValue = "Sync enabled."
            }
        } else {
            syncStatusLabel.stringValue = "Sync favourites, hidden items, groups, and shortcuts."
        }
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
            .sink { [weak self] _ in
                self?.updateProVisibility()
                self?.updateSyncUI()
            }
            .store(in: &cancellables)

        ProManager.shared.$products
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButtonTitles() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: CloudSyncManager.syncStatusChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateSyncUI() }
            .store(in: &cancellables)
    }

    @objc private func launchSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.launchAtLogin = sender.state == .on
    }

    @objc private func gridSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.scenesDisplayMode = sender.state == .on ? .grid : .list
    }

    @objc private func syncSwitchChanged(_ sender: NSSwitch) {
        CloudSyncManager.shared.isSyncEnabled = sender.state == .on
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
