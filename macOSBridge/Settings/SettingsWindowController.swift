//
//  SettingsWindowController.swift
//  macOSBridge
//
//  Main settings window controller with sidebar navigation
//

import AppKit

class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private let settingsView = SettingsView()
    private var menuData: MenuData?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"

        super.init(window: window)

        window.contentView = settingsView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with data: MenuData) {
        self.menuData = data
        settingsView.configure(with: data)
    }

    override func showWindow(_ sender: Any?) {
        guard let window = window else { return }

        window.center()
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func selectTab(index: Int) {
        settingsView.selectSection(at: index)
    }
}
