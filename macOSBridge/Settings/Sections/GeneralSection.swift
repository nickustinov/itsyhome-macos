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
    private let syncSwitch = NSSwitch()
    private var syncStatusLabel: NSTextField!
    private var syncProBadge: NSView!

    // Platform picker
    private var homeKitCard: PlatformCardButton!
    private var homeAssistantCard: PlatformCardButton!

    // Pro section
    private var cancellables = Set<AnyCancellable>()
    private var proBox: NSView!
    private let proBadge = NSView()
    private let thankYouLabel = NSTextField()
    private var proSubtitleLabel: NSTextField!
    private var noSubscriptionsLabel: NSTextField!
    private var featuresGrid: NSView!
    private var buttonStack: NSStackView!
    private let buyButton = NSButton()
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
        // Platform picker box
        let platformBox = createCardBox()
        let platformContent = createPlatformPickerSection()
        addContentToBox(platformBox, content: platformContent)
        stackView.addArrangedSubview(platformBox)
        platformBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Launch at login box
        let launchBox = createCardBox()
        launchSwitch.controlSize = .mini
        launchSwitch.target = self
        launchSwitch.action = #selector(launchSwitchChanged)
        let launchRow = createSettingRow(label: String(localized: "settings.general.launch_at_login", defaultValue: "Launch Itsyhome at login", bundle: .macOSBridge), control: launchSwitch)
        addContentToBox(launchBox, content: launchRow)
        stackView.addArrangedSubview(launchBox)
        launchBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

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

    private func createPlatformPickerSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let pluginBundle = Bundle(for: GeneralSection.self)

        // Label
        let label = createLabel(String(localized: "settings.general.platform", defaultValue: "Smart home platform", bundle: .macOSBridge), style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        // Platform cards container
        let cardsStack = NSStackView()
        cardsStack.orientation = .horizontal
        cardsStack.spacing = 12
        cardsStack.alignment = .centerY
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cardsStack)

        let currentPlatform = PlatformManager.shared.selectedPlatform

        // HomeKit card
        homeKitCard = PlatformCardButton(
            icon: pluginBundle.image(forResource: "homekit"),
            title: String(localized: "settings.general.homekit", defaultValue: "HomeKit", bundle: .macOSBridge),
            isSelected: currentPlatform == .homeKit
        )
        homeKitCard.onSelect = { [weak self] in self?.platformCardTapped(.homeKit) }
        cardsStack.addArrangedSubview(homeKitCard)

        // Home Assistant card
        homeAssistantCard = PlatformCardButton(
            icon: pluginBundle.image(forResource: "ha"),
            title: String(localized: "settings.general.home_assistant", defaultValue: "Home Assistant", bundle: .macOSBridge),
            isSelected: currentPlatform == .homeAssistant
        )
        homeAssistantCard.onSelect = { [weak self] in self?.platformCardTapped(.homeAssistant) }
        cardsStack.addArrangedSubview(homeAssistantCard)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 80),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            cardsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cardsStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func platformCardTapped(_ newPlatform: SelectedPlatform) {
        let currentPlatform = PlatformManager.shared.selectedPlatform

        if newPlatform == currentPlatform {
            return
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "alert.restart.title", defaultValue: "Restart required", bundle: .macOSBridge)
        alert.informativeText = String(localized: "alert.restart.message", defaultValue: "Switching platforms requires restarting Itsyhome. Any unsaved changes will be lost.", bundle: .macOSBridge)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "alert.restart.confirm", defaultValue: "Restart app", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge))

        if alert.runModal() == .alertFirstButtonReturn {
            // Don't clear HA credentials - let user switch back without re-entering them
            // Credentials are only cleared via Disconnect button in HA settings panel

            // Set new platform
            PlatformManager.shared.selectedPlatform = newPlatform

            // Restart the app
            restartApp()
        }
        // No need to revert - cards maintain their own state
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", path]
        task.launch()
        NSApp.terminate(nil)
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

        let labelField = createLabel(String(localized: "settings.general.icloud_sync", defaultValue: "iCloud sync", bundle: .macOSBridge), style: .body)
        headerRow.addArrangedSubview(labelField)

        // Pro badge (only shown for non-Pro users)
        syncProBadge = NSView()
        syncProBadge.wantsLayer = true
        syncProBadge.layer?.backgroundColor = NSColor.systemBlue.cgColor
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
        syncStatusLabel = createLabel(String(localized: "settings.general.sync_description", defaultValue: "Sync favourites across your devices.", bundle: .macOSBridge), style: .caption)
        syncStatusLabel.lineBreakMode = .byWordWrapping
        syncStatusLabel.maximumNumberOfLines = 2
        labelStack.addArrangedSubview(syncStatusLabel)

        syncSwitch.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelStack)
        container.addSubview(syncSwitch)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            labelStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: syncSwitch.leadingAnchor, constant: -16),
            syncSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            syncSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func setupProSection() {
        proBox = ProTintBoxView()
        proBox.translatesAutoresizingMaskIntoConstraints = false

        // Main horizontal layout: icon | text content | buttons
        let mainRow = NSStackView()
        mainRow.orientation = .horizontal
        mainRow.spacing = 14
        mainRow.alignment = .top
        mainRow.translatesAutoresizingMaskIntoConstraints = false
        proBox.addSubview(mainRow)

        // App icon (top-aligned)
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        mainRow.addArrangedSubview(iconView)

        // Center text content
        let textContent = NSStackView()
        textContent.orientation = .vertical
        textContent.spacing = 4
        textContent.alignment = .leading

        // Title row with badge
        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY

        let titleLabel = NSTextField(labelWithString: String(localized: "settings.pro.title", defaultValue: "Itsyhome Pro", bundle: .macOSBridge))
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleRow.addArrangedSubview(titleLabel)

        // Pro badge (shown when active)
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
        titleRow.addArrangedSubview(proBadge)

        textContent.addArrangedSubview(titleRow)

        // Thank you label (shown when subscribed)
        thankYouLabel.stringValue = String(localized: "settings.pro.thank_you", defaultValue: "Thank you for your support!", bundle: .macOSBridge)
        thankYouLabel.font = .systemFont(ofSize: 12)
        thankYouLabel.textColor = .secondaryLabelColor
        thankYouLabel.isBezeled = false
        thankYouLabel.isEditable = false
        thankYouLabel.drawsBackground = false
        textContent.addArrangedSubview(thankYouLabel)

        // Subtitle (shown when not subscribed)
        proSubtitleLabel = NSTextField(labelWithString: String(localized: "settings.pro.subtitle", defaultValue: "Unlock the full power of your smart home.", bundle: .macOSBridge))
        proSubtitleLabel.font = .systemFont(ofSize: 12)
        proSubtitleLabel.textColor = .secondaryLabelColor
        textContent.addArrangedSubview(proSubtitleLabel)

        // No subscriptions label
        noSubscriptionsLabel = NSTextField(labelWithString: String(localized: "settings.pro.no_subscriptions", defaultValue: "No subscriptions \u{00B7} Purchase once, keep forever", bundle: .macOSBridge))
        noSubscriptionsLabel.font = .boldSystemFont(ofSize: 12)
        noSubscriptionsLabel.textColor = .labelColor
        textContent.addArrangedSubview(noSubscriptionsLabel)

        // Features grid (3x2)
        textContent.setCustomSpacing(10, after: noSubscriptionsLabel)
        featuresGrid = createFeaturesGrid()
        textContent.addArrangedSubview(featuresGrid)

        textContent.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mainRow.addArrangedSubview(textContent)

        // Right side: button + restore
        buttonStack = NSStackView()
        buttonStack.orientation = .vertical
        buttonStack.spacing = 6
        buttonStack.alignment = .centerX

        buyButton.bezelStyle = .rounded
        buyButton.controlSize = .large
        buyButton.bezelColor = .systemBlue
        buyButton.isEnabled = false
        buyButton.target = self
        buyButton.action = #selector(buyTapped)
        buttonStack.addArrangedSubview(buyButton)

        restoreButton.title = String(localized: "settings.pro.restore_purchases", defaultValue: "Restore purchases", bundle: .macOSBridge)
        restoreButton.bezelStyle = .inline
        restoreButton.controlSize = .small
        restoreButton.isBordered = false
        restoreButton.contentTintColor = .secondaryLabelColor
        restoreButton.target = self
        restoreButton.action = #selector(restoreTapped)
        buttonStack.addArrangedSubview(restoreButton)

        mainRow.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            mainRow.topAnchor.constraint(equalTo: proBox.topAnchor, constant: 14),
            mainRow.leadingAnchor.constraint(equalTo: proBox.leadingAnchor, constant: 14),
            mainRow.trailingAnchor.constraint(equalTo: proBox.trailingAnchor, constant: -14),
            mainRow.bottomAnchor.constraint(equalTo: proBox.bottomAnchor, constant: -14)
        ])

        stackView.addArrangedSubview(proBox)
        proBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func createFeaturesGrid() -> NSView {
        let features = [
            String(localized: "settings.pro.feature_cameras", defaultValue: "Cameras", bundle: .macOSBridge),
            String(localized: "settings.pro.feature_groups", defaultValue: "Device groups", bundle: .macOSBridge),
            String(localized: "settings.pro.feature_deeplinks", defaultValue: "Deeplinks", bundle: .macOSBridge),
            String(localized: "settings.pro.feature_sync", defaultValue: "iCloud sync", bundle: .macOSBridge),
            String(localized: "settings.pro.feature_stream_deck", defaultValue: "Stream Deck", bundle: .macOSBridge),
            String(localized: "settings.pro.feature_webhooks", defaultValue: "Webhooks/CLI", bundle: .macOSBridge)
        ]

        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.rowSpacing = 4
        grid.columnSpacing = 16

        for row in stride(from: 0, to: features.count, by: 3) {
            let cells: [NSView] = (0..<3).map { col in
                let feature = features[row + col]
                let cell = NSStackView()
                cell.orientation = .horizontal
                cell.spacing = 4
                cell.alignment = .centerY

                let check = NSImageView()
                check.image = PhosphorIcon.fill("check-circle")
                check.contentTintColor = .systemGreen
                check.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                check.translatesAutoresizingMaskIntoConstraints = false
                check.widthAnchor.constraint(equalToConstant: 14).isActive = true
                check.heightAnchor.constraint(equalToConstant: 14).isActive = true
                cell.addArrangedSubview(check)

                let label = NSTextField(labelWithString: feature)
                label.font = .systemFont(ofSize: 11)
                label.textColor = .secondaryLabelColor
                cell.addArrangedSubview(label)

                return cell
            }
            grid.addRow(with: cells)
        }

        return grid
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
        syncSwitch.state = CloudSyncManager.shared.isSyncEnabled ? .on : .off
        updateSyncUI()
    }

    private func updateSyncUI() {
        let isPro = ProStatusCache.shared.isPro
        let syncEnabled = CloudSyncManager.shared.isSyncEnabled
        syncSwitch.isEnabled = isPro
        syncProBadge.isHidden = isPro
        if !isPro {
            syncStatusLabel.stringValue = String(localized: "settings.general.sync_full_description", defaultValue: "Sync favourites, hidden items, groups, and shortcuts.", bundle: .macOSBridge)
        } else if syncEnabled {
            if let lastSync = CloudSyncManager.shared.lastSyncTimestamp {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let relative = formatter.localizedString(for: lastSync, relativeTo: Date())
                syncStatusLabel.stringValue = "Last synced \(relative)."
            } else {
                syncStatusLabel.stringValue = String(localized: "settings.general.sync_enabled", defaultValue: "Sync enabled.", bundle: .macOSBridge)
            }
        } else {
            syncStatusLabel.stringValue = String(localized: "settings.general.sync_full_description", defaultValue: "Sync favourites, hidden items, groups, and shortcuts.", bundle: .macOSBridge)
        }
    }

    private func updateProVisibility() {
        let isPro = ProStatusCache.shared.isPro

        proBadge.isHidden = !isPro
        thankYouLabel.isHidden = !isPro

        proSubtitleLabel.isHidden = isPro
        noSubscriptionsLabel.isHidden = isPro
        featuresGrid.isHidden = isPro
        buttonStack.isHidden = isPro
    }

    private func updateButtonTitles() {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ]
        if let product = ProManager.shared.lifetimeProduct {
            buyButton.attributedTitle = NSAttributedString(string: "\(String(localized: "settings.pro.get_pro", defaultValue: "Get Pro", bundle: .macOSBridge)) \u{2013} \(product.displayPrice)", attributes: attrs)
            buyButton.isEnabled = true
        } else {
            buyButton.attributedTitle = NSAttributedString(string: String(localized: "settings.pro.get_pro", defaultValue: "Get Pro", bundle: .macOSBridge), attributes: attrs)
            buyButton.isEnabled = false
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

    @objc private func syncSwitchChanged(_ sender: NSSwitch) {
        CloudSyncManager.shared.isSyncEnabled = sender.state == .on
        updateSyncUI()
    }

    @objc private func buyTapped() {
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

// MARK: - Platform card button

class PlatformCardButton: NSView {

    var onSelect: (() -> Void)?
    var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    private let iconView = NSImageView()
    private let titleLabel: NSTextField
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init(icon: NSImage?, title: String, isSelected: Bool) {
        self.isSelected = isSelected
        self.titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6

        // Icon
        iconView.image = icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Title
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 95),
            heightAnchor.constraint(equalToConstant: 68),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
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
        if isSelected {
            bgColor = isDark ? NSColor(white: 0.28, alpha: 1.0) : NSColor(white: 0.78, alpha: 1.0)
        } else if isHovered {
            bgColor = isDark ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.85, alpha: 1.0)
        } else {
            bgColor = isDark ? NSColor(white: 0.18, alpha: 1.0) : NSColor(white: 0.90, alpha: 1.0)
        }

        bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        if !isSelected {
            NSCursor.pointingHand.set()
        }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.arrow.set()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if !isSelected {
            alphaValue = 0.7
        }
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) && !isSelected {
            onSelect?()
        }
    }
}
