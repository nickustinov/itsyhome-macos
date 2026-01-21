//
//  GeneralSettingsView.swift
//  macOSBridge
//
//  General settings tab with launch at login option
//

import AppKit

class GeneralSettingsView: NSView {

    private let sectionLabel: NSTextField
    private let launchAtLoginCheckbox: NSButton

    override init(frame frameRect: NSRect) {
        // Section header
        sectionLabel = NSTextField(labelWithString: "Startup")
        sectionLabel.font = DS.Typography.bodyMedium
        sectionLabel.textColor = DS.Colors.foreground

        // Launch at login checkbox
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch Itsyhome at login", target: nil, action: nil)
        launchAtLoginCheckbox.font = DS.Typography.label

        super.init(frame: frameRect)

        addSubview(sectionLabel)
        addSubview(launchAtLoginCheckbox)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        // Set initial state
        launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off

        // Listen for external preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: PreferencesManager.preferencesChangedNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()

        let padding: CGFloat = 20
        let topPadding: CGFloat = 20

        // Section label at top
        sectionLabel.sizeToFit()
        sectionLabel.frame = NSRect(
            x: padding,
            y: bounds.height - topPadding - sectionLabel.frame.height,
            width: sectionLabel.frame.width,
            height: sectionLabel.frame.height
        )

        // Checkbox below section label
        launchAtLoginCheckbox.sizeToFit()
        launchAtLoginCheckbox.frame = NSRect(
            x: padding,
            y: sectionLabel.frame.minY - 12 - launchAtLoginCheckbox.frame.height,
            width: launchAtLoginCheckbox.frame.width,
            height: launchAtLoginCheckbox.frame.height
        )
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        PreferencesManager.shared.launchAtLogin = (sender.state == .on)
    }

    @objc private func preferencesDidChange() {
        launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
    }
}
