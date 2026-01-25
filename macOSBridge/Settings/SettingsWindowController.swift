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
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible

        super.init(window: window)

        // Vertically resizable only (fixed width)
        window.setContentSize(NSSize(width: 750, height: 600))
        window.contentMinSize = NSSize(width: 750, height: 350)
        window.contentMaxSize = NSSize(width: 750, height: CGFloat.greatestFiniteMagnitude)

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
