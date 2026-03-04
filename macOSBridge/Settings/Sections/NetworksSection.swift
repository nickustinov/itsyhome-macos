//
//  NetworksSection.swift
//  macOSBridge
//
//  Settings section for SSID-based auto-switching
//

import AppKit
import CoreLocation

class NetworksSection: SettingsCard {

    private let enableSwitch = NSSwitch()
    private let ssidLabel = NSTextField(labelWithString: "–")
    private var rulesStack = NSStackView()
    private var addRuleContainer = NSView()
    private var permissionDeniedBox: NSView?
    private var currentNetworkBox: NSView?
    private var rulesBox: NSView?
    private var menuData: MenuData?

    // Add rule panel controls
    private let ssidField = NSTextField()
    private let targetPopUp = NSPopUpButton()
    private let targetURLField = NSTextField()
    private let targetTokenField = NSSecureTextField()
    private var isAddingHomeKitRule: Bool {
        PlatformManager.shared.selectedPlatform == .homeKit
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContent()
        loadState()
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(with data: MenuData) {
        self.menuData = data
        rebuildRulesList()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthorizationChange),
            name: NetworkLocationManager.locationAuthorizationDidChange,
            object: nil
        )
    }

    @objc private func handleAuthorizationChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateVisibility()
        }
    }

    private func setupContent() {
        let isPro = ProStatusCache.shared.isPro

        // Pro banner
        if !isPro {
            let banner = SettingsCard.createProBanner()
            stackView.addArrangedSubview(banner)
            banner.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }

        // Enable toggle card
        let enableBox = createCardBox()
        enableSwitch.controlSize = .mini
        enableSwitch.target = self
        enableSwitch.action = #selector(enableSwitchChanged)
        enableSwitch.isEnabled = isPro
        let enableRow = createSettingRow(
            label: String(localized: "settings.networks.enable", defaultValue: "Auto-switch by WiFi network", bundle: .macOSBridge),
            subtitle: String(localized: "settings.networks.enable_subtitle", defaultValue: "Switch home or server based on your WiFi network.", bundle: .macOSBridge),
            control: enableSwitch
        )
        addContentToBox(enableBox, content: enableRow)
        stackView.addArrangedSubview(enableBox)
        enableBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Current network card
        let networkBox = createCardBox()
        ssidLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        let ssidRow = createSettingRow(
            label: String(localized: "settings.networks.current_network", defaultValue: "Current network", bundle: .macOSBridge),
            control: ssidLabel
        )
        addContentToBox(networkBox, content: ssidRow)
        stackView.addArrangedSubview(networkBox)
        networkBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        currentNetworkBox = networkBox

        // Permission denied card
        let deniedBox = createCardBox()
        let deniedContent = createPermissionDeniedContent()
        addContentToBox(deniedBox, content: deniedContent)
        stackView.addArrangedSubview(deniedBox)
        deniedBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        permissionDeniedBox = deniedBox

        // Rules card
        let rBox = createCardBox()
        let rulesContent = createRulesContent()
        addContentToBox(rBox, content: rulesContent)
        stackView.addArrangedSubview(rBox)
        rBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        rulesBox = rBox
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

        if let subtitle {
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

    // MARK: - Permission denied content

    private func createPermissionDeniedContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(wrappingLabelWithString: String(localized: "settings.networks.permission_denied", defaultValue: "Location access is required to read your WiFi network name. Grant permission in System Settings \u{2192} Privacy & Security \u{2192} Location Services.", bundle: .macOSBridge))
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)

        let openButton = NSButton(title: String(localized: "settings.networks.open_settings", defaultValue: "Open System Settings", bundle: .macOSBridge), target: self, action: #selector(openSystemSettings))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        stack.addArrangedSubview(openButton)

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8)
        ])

        return wrapper
    }

    @objc private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Rules content

    private func createRulesContent() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false

        // Header with label and add button
        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 8
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = createLabel(String(localized: "settings.networks.rules", defaultValue: "Rules", bundle: .macOSBridge), style: .sectionHeader)
        header.addArrangedSubview(headerLabel)
        header.addArrangedSubview(NSView()) // spacer

        let addButton = NSButton(title: String(localized: "settings.networks.add_rule", defaultValue: "Add rule", bundle: .macOSBridge), target: self, action: #selector(showAddRulePanel))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small
        header.addArrangedSubview(addButton)

        container.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // Rules list
        rulesStack.orientation = .vertical
        rulesStack.spacing = 4
        rulesStack.alignment = .leading
        rulesStack.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(rulesStack)
        rulesStack.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // Add rule panel (hidden initially)
        addRuleContainer.translatesAutoresizingMaskIntoConstraints = false
        addRuleContainer.isHidden = true
        container.addArrangedSubview(addRuleContainer)
        addRuleContainer.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        setupAddRulePanel()

        return container
    }

    private func setupAddRulePanel() {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.spacing = 8
        panel.alignment = .leading
        panel.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let separator = createSeparator()
        panel.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        // SSID field
        let ssidRow = NSStackView()
        ssidRow.orientation = .horizontal
        ssidRow.spacing = 8
        ssidRow.alignment = .centerY
        ssidRow.translatesAutoresizingMaskIntoConstraints = false

        let ssidRowLabel = createLabel(String(localized: "settings.networks.ssid", defaultValue: "WiFi network", bundle: .macOSBridge), style: .body)
        ssidRowLabel.translatesAutoresizingMaskIntoConstraints = false
        ssidRowLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        ssidRow.addArrangedSubview(ssidRowLabel)

        ssidField.placeholderString = NetworkLocationManager.shared.currentSSID ?? "SSID"
        ssidField.translatesAutoresizingMaskIntoConstraints = false
        ssidField.controlSize = .regular
        ssidRow.addArrangedSubview(ssidField)

        panel.addArrangedSubview(ssidRow)
        ssidRow.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        // Target row
        let targetRow = NSStackView()
        targetRow.orientation = .horizontal
        targetRow.spacing = 8
        targetRow.alignment = .centerY
        targetRow.translatesAutoresizingMaskIntoConstraints = false

        let targetLabel: String
        if isAddingHomeKitRule {
            targetLabel = String(localized: "settings.networks.home", defaultValue: "Home", bundle: .macOSBridge)
        } else {
            targetLabel = String(localized: "settings.networks.server_url", defaultValue: "Server URL", bundle: .macOSBridge)
        }
        let targetRowLabel = createLabel(targetLabel, style: .body)
        targetRowLabel.translatesAutoresizingMaskIntoConstraints = false
        targetRowLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        targetRow.addArrangedSubview(targetRowLabel)

        if isAddingHomeKitRule {
            targetPopUp.removeAllItems()
            if let homes = menuData?.homes {
                for home in homes {
                    targetPopUp.addItem(withTitle: home.name)
                    targetPopUp.lastItem?.representedObject = home
                }
            }
            targetPopUp.controlSize = .regular
            targetPopUp.translatesAutoresizingMaskIntoConstraints = false
            targetRow.addArrangedSubview(targetPopUp)
        } else {
            targetURLField.placeholderString = "http://192.168.1.50:8123"
            targetURLField.translatesAutoresizingMaskIntoConstraints = false
            targetURLField.controlSize = .regular
            targetRow.addArrangedSubview(targetURLField)
        }

        panel.addArrangedSubview(targetRow)
        targetRow.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        // Token row (HA only)
        if !isAddingHomeKitRule {
            let tokenRow = NSStackView()
            tokenRow.orientation = .horizontal
            tokenRow.spacing = 8
            tokenRow.alignment = .centerY
            tokenRow.translatesAutoresizingMaskIntoConstraints = false

            let tokenRowLabel = createLabel(String(localized: "settings.networks.access_token", defaultValue: "Access token", bundle: .macOSBridge), style: .body)
            tokenRowLabel.translatesAutoresizingMaskIntoConstraints = false
            tokenRowLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
            tokenRow.addArrangedSubview(tokenRowLabel)

            targetTokenField.placeholderString = String(localized: "settings.networks.token_placeholder", defaultValue: "Optional – uses default if empty", bundle: .macOSBridge)
            targetTokenField.translatesAutoresizingMaskIntoConstraints = false
            targetTokenField.controlSize = .regular
            tokenRow.addArrangedSubview(targetTokenField)

            panel.addArrangedSubview(tokenRow)
            tokenRow.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true
        }

        // Buttons
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY
        buttons.translatesAutoresizingMaskIntoConstraints = false

        buttons.addArrangedSubview(NSView()) // spacer

        let cancelButton = NSButton(title: String(localized: "common.cancel", defaultValue: "Cancel", bundle: .macOSBridge), target: self, action: #selector(cancelAddRule))
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .small
        buttons.addArrangedSubview(cancelButton)

        let saveButton = NSButton(title: String(localized: "common.save", defaultValue: "Save", bundle: .macOSBridge), target: self, action: #selector(saveRule))
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .small
        saveButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(saveButton)

        panel.addArrangedSubview(buttons)
        buttons.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true

        addRuleContainer.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: addRuleContainer.topAnchor),
            panel.leadingAnchor.constraint(equalTo: addRuleContainer.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: addRuleContainer.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: addRuleContainer.bottomAnchor)
        ])
    }

    // MARK: - State

    private func loadState() {
        let enabled = PreferencesManager.shared.networkAutoSwitchEnabled
        enableSwitch.state = enabled ? .on : .off
        updateSSIDLabel()
        rebuildRulesList()
        updateVisibility()
    }

    private func updateSSIDLabel() {
        let ssid = NetworkLocationManager.shared.currentSSID
        ssidLabel.stringValue = ssid ?? String(localized: "settings.networks.no_network", defaultValue: "Not connected", bundle: .macOSBridge)
    }

    private func updateVisibility() {
        let enabled = PreferencesManager.shared.networkAutoSwitchEnabled
        let hasPermission = NetworkLocationManager.shared.hasLocationPermission
        let permissionNotDetermined = NetworkLocationManager.shared.locationAuthorizationStatus == .notDetermined

        currentNetworkBox?.isHidden = !enabled || (!hasPermission && !permissionNotDetermined)
        permissionDeniedBox?.isHidden = !enabled || hasPermission || permissionNotDetermined
        rulesBox?.isHidden = !enabled

        updateSSIDLabel()
    }

    // MARK: - Rules list

    private func rebuildRulesList() {
        // Remove existing rule rows
        for view in rulesStack.arrangedSubviews {
            rulesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let platform = PlatformManager.shared.selectedPlatform
        if platform == .homeKit {
            let rules = PreferencesManager.shared.homeKitNetworkRules
            if rules.isEmpty {
                let emptyLabel = createLabel(String(localized: "settings.networks.no_rules", defaultValue: "No rules configured.", bundle: .macOSBridge), style: .caption)
                rulesStack.addArrangedSubview(emptyLabel)
            } else {
                for rule in rules {
                    let row = createRuleRow(ssid: rule.ssid, target: rule.homeName, ruleId: rule.id, isHomeKit: true)
                    rulesStack.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalTo: rulesStack.widthAnchor).isActive = true
                }
            }
        } else if platform == .homeAssistant {
            let rules = PreferencesManager.shared.haNetworkRules
            if rules.isEmpty {
                let emptyLabel = createLabel(String(localized: "settings.networks.no_rules", defaultValue: "No rules configured.", bundle: .macOSBridge), style: .caption)
                rulesStack.addArrangedSubview(emptyLabel)
            } else {
                for rule in rules {
                    let target = rule.accessToken != nil ? "\(rule.serverURL) + token" : rule.serverURL
                    let row = createRuleRow(ssid: rule.ssid, target: target, ruleId: rule.id, isHomeKit: false)
                    rulesStack.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalTo: rulesStack.widthAnchor).isActive = true
                }
            }
        }
    }

    private func createRuleRow(ssid: String, target: String, ruleId: UUID, isHomeKit: Bool) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let ssidField = createLabel(ssid, style: .body)
        ssidField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        row.addArrangedSubview(ssidField)

        let arrow = createLabel("\u{2192}", style: .body)
        arrow.textColor = .secondaryLabelColor
        row.addArrangedSubview(arrow)

        let targetField = createLabel(target, style: .body)
        targetField.textColor = .secondaryLabelColor
        targetField.lineBreakMode = .byTruncatingMiddle
        row.addArrangedSubview(targetField)

        row.addArrangedSubview(NSView()) // spacer

        let removeButton = NSButton(title: "", target: nil, action: nil)
        removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")
        removeButton.imagePosition = .imageOnly
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        removeButton.target = self
        removeButton.tag = ruleId.hashValue
        if isHomeKit {
            removeButton.action = #selector(removeHomeKitRuleAction(_:))
        } else {
            removeButton.action = #selector(removeHARuleAction(_:))
        }
        // Store rule ID for lookup
        removeButton.identifier = NSUserInterfaceItemIdentifier(ruleId.uuidString)
        row.addArrangedSubview(removeButton)

        row.heightAnchor.constraint(equalToConstant: 28).isActive = true

        return row
    }

    // MARK: - Actions

    @objc private func enableSwitchChanged(_ sender: NSSwitch) {
        let enabled = sender.state == .on
        PreferencesManager.shared.networkAutoSwitchEnabled = enabled

        if enabled {
            let status = NetworkLocationManager.shared.locationAuthorizationStatus
            if status == .notDetermined {
                NetworkLocationManager.shared.requestLocationPermission()
            } else if NetworkLocationManager.shared.hasLocationPermission {
                NetworkLocationManager.shared.startMonitoring()
            }
        } else {
            NetworkLocationManager.shared.stopMonitoring()
        }

        updateVisibility()
    }

    @objc private func showAddRulePanel() {
        ssidField.stringValue = NetworkLocationManager.shared.currentSSID ?? ""
        ssidField.placeholderString = NetworkLocationManager.shared.currentSSID ?? "SSID"
        targetURLField.stringValue = ""
        targetTokenField.stringValue = ""

        // Refresh homes list
        if isAddingHomeKitRule {
            targetPopUp.removeAllItems()
            if let homes = menuData?.homes {
                for home in homes {
                    targetPopUp.addItem(withTitle: home.name)
                    targetPopUp.lastItem?.representedObject = home
                }
            }
        }

        addRuleContainer.isHidden = false
    }

    @objc private func cancelAddRule() {
        addRuleContainer.isHidden = true
    }

    @objc private func saveRule() {
        let ssid = ssidField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !ssid.isEmpty else { return }

        if isAddingHomeKitRule {
            guard let home = targetPopUp.selectedItem?.representedObject as? HomeData else { return }
            let rule = HomeKitNetworkRule(id: UUID(), ssid: ssid, homeId: home.uniqueIdentifier, homeName: home.name)
            PreferencesManager.shared.addHomeKitRule(rule)
        } else {
            let url = targetURLField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !url.isEmpty else { return }
            let token = targetTokenField.stringValue.trimmingCharacters(in: .whitespaces)
            let rule = HANetworkRule(id: UUID(), ssid: ssid, serverURL: url, accessToken: token.isEmpty ? nil : token)
            PreferencesManager.shared.addHARule(rule)
        }

        addRuleContainer.isHidden = true
        rebuildRulesList()
    }

    @objc private func removeHomeKitRuleAction(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: idString) else { return }
        PreferencesManager.shared.removeHomeKitRule(id: uuid)
        rebuildRulesList()
    }

    @objc private func removeHARuleAction(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: idString) else { return }
        PreferencesManager.shared.removeHARule(id: uuid)
        rebuildRulesList()
    }
}
