//
//  GeneralSettingsView.swift
//  macOSBridge
//
//  General settings tab with launch at login option
//

import AppKit

class GeneralSettingsView: NSView {

    private let startupLabel: NSTextField
    private let launchAtLoginLabel: NSTextField
    private let launchAtLoginSwitch: ToggleSwitch

    private let displayLabel: NSTextField
    private let scenesGridLabel: NSTextField
    private let scenesGridSwitch: ToggleSwitch

    override init(frame frameRect: NSRect) {
        // Startup section header
        startupLabel = NSTextField(labelWithString: "Startup")
        startupLabel.font = DS.Typography.bodyMedium
        startupLabel.textColor = DS.Colors.foreground

        // Launch at login row
        launchAtLoginLabel = NSTextField(labelWithString: "Launch Itsyhome at login")
        launchAtLoginLabel.font = DS.Typography.label
        launchAtLoginLabel.textColor = DS.Colors.foreground

        launchAtLoginSwitch = ToggleSwitch()

        // Display section header
        displayLabel = NSTextField(labelWithString: "Display")
        displayLabel.font = DS.Typography.bodyMedium
        displayLabel.textColor = DS.Colors.foreground

        // Scenes grid row
        scenesGridLabel = NSTextField(labelWithString: "Show Scenes as grid")
        scenesGridLabel.font = DS.Typography.label
        scenesGridLabel.textColor = DS.Colors.foreground

        scenesGridSwitch = ToggleSwitch()

        super.init(frame: frameRect)

        addSubview(startupLabel)
        addSubview(launchAtLoginLabel)
        addSubview(launchAtLoginSwitch)
        addSubview(displayLabel)
        addSubview(scenesGridLabel)
        addSubview(scenesGridSwitch)

        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(toggleLaunchAtLogin(_:))

        scenesGridSwitch.target = self
        scenesGridSwitch.action = #selector(toggleScenesGrid(_:))

        // Set initial state
        updateFromPreferences()

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
        let sectionSpacing: CGFloat = 28
        let itemSpacing: CGFloat = 12
        let switchWidth = DS.ControlSize.switchWidth
        let switchHeight = DS.ControlSize.switchHeight
        let switchLabelGap: CGFloat = 8

        var y = bounds.height - topPadding

        // Startup section
        startupLabel.sizeToFit()
        y -= startupLabel.frame.height
        startupLabel.frame = NSRect(
            x: padding,
            y: y,
            width: startupLabel.frame.width,
            height: startupLabel.frame.height
        )

        // Launch at login row
        launchAtLoginLabel.sizeToFit()
        y -= itemSpacing + switchHeight
        launchAtLoginSwitch.frame = NSRect(
            x: padding,
            y: y,
            width: switchWidth,
            height: switchHeight
        )

        launchAtLoginLabel.frame = NSRect(
            x: padding + switchWidth + switchLabelGap,
            y: y + (switchHeight - launchAtLoginLabel.frame.height) / 2,
            width: launchAtLoginLabel.frame.width,
            height: launchAtLoginLabel.frame.height
        )

        // Display section
        y -= sectionSpacing

        displayLabel.sizeToFit()
        y -= displayLabel.frame.height
        displayLabel.frame = NSRect(
            x: padding,
            y: y,
            width: displayLabel.frame.width,
            height: displayLabel.frame.height
        )

        // Scenes grid row
        scenesGridLabel.sizeToFit()
        y -= itemSpacing + switchHeight
        scenesGridSwitch.frame = NSRect(
            x: padding,
            y: y,
            width: switchWidth,
            height: switchHeight
        )

        scenesGridLabel.frame = NSRect(
            x: padding + switchWidth + switchLabelGap,
            y: y + (switchHeight - scenesGridLabel.frame.height) / 2,
            width: scenesGridLabel.frame.width,
            height: scenesGridLabel.frame.height
        )
    }

    private func updateFromPreferences() {
        let prefs = PreferencesManager.shared
        launchAtLoginSwitch.setOn(prefs.launchAtLogin, animated: false)
        scenesGridSwitch.setOn(prefs.scenesDisplayMode == .grid, animated: false)
    }

    @objc private func toggleLaunchAtLogin(_ sender: ToggleSwitch) {
        PreferencesManager.shared.launchAtLogin = sender.isOn
    }

    @objc private func toggleScenesGrid(_ sender: ToggleSwitch) {
        let mode: PreferencesManager.ScenesDisplayMode = sender.isOn ? .grid : .list
        PreferencesManager.shared.scenesDisplayMode = mode
    }

    @objc private func preferencesDidChange() {
        updateFromPreferences()
    }
}
