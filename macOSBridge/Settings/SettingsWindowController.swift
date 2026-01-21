//
//  SettingsWindowController.swift
//  macOSBridge
//
//  Main Settings window controller with toolbar-based navigation
//

import AppKit

class SettingsWindowController: NSWindowController, NSToolbarDelegate {

    static let shared = SettingsWindowController()

    // Pane identifiers
    private enum PaneIdentifier: String, CaseIterable {
        case general = "general"
        case accessories = "accessories"
        case about = "about"

        var title: String {
            switch self {
            case .general: return "General"
            case .accessories: return "Accessories"
            case .about: return "About"
            }
        }

        var icon: NSImage? {
            switch self {
            case .general:
                return NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
            case .accessories:
                return NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Accessories")
            case .about:
                return NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
            }
        }

        var toolbarItemIdentifier: NSToolbarItem.Identifier {
            NSToolbarItem.Identifier(rawValue)
        }
    }

    // Content views
    private let generalView = GeneralSettingsView()
    private let accessoriesView = AccessoriesSettingsView()
    private let aboutView = AboutSettingsView()

    private var currentPane: PaneIdentifier = .general
    private var menuData: MenuData?

    private init() {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "General"

        // Use preference toolbar style (icons centered below title)
        window.toolbarStyle = .preference

        super.init(window: window)

        // Setup toolbar
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar

        // Set initial content
        showPane(.general)

        // Select the General item in toolbar
        toolbar.selectedItemIdentifier = PaneIdentifier.general.toolbarItemIdentifier
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with data: MenuData) {
        self.menuData = data
        accessoriesView.configure(with: data)
    }

    override func showWindow(_ sender: Any?) {
        guard let window = window else { return }

        window.center()
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Pane switching

    private func showPane(_ pane: PaneIdentifier) {
        guard let window = window else { return }

        currentPane = pane
        window.title = pane.title

        let paneView: NSView
        switch pane {
        case .general:
            paneView = generalView
        case .accessories:
            paneView = accessoriesView
        case .about:
            paneView = aboutView
        }

        // Calculate content size based on pane (add 1 for separator)
        let separatorHeight: CGFloat = 1
        let contentSize: NSSize
        switch pane {
        case .general:
            contentSize = NSSize(width: 480, height: 200 + separatorHeight)
        case .accessories:
            contentSize = NSSize(width: 480, height: 400 + separatorHeight)
        case .about:
            contentSize = NSSize(width: 480, height: 280 + separatorHeight)
        }

        // Create container with separator at top
        let container = NSView(frame: NSRect(origin: .zero, size: contentSize))

        let separator = NSBox(frame: NSRect(x: 0, y: contentSize.height - separatorHeight, width: contentSize.width, height: separatorHeight))
        separator.boxType = .separator
        container.addSubview(separator)

        paneView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height - separatorHeight)
        container.addSubview(paneView)

        // Resize window (keep top-left corner fixed)
        let currentFrame = window.frame
        var newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        newFrame.origin.x = currentFrame.origin.x
        newFrame.origin.y = currentFrame.maxY - newFrame.height

        window.contentView = container
        window.setFrame(newFrame, display: true)
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let pane = PaneIdentifier(rawValue: sender.itemIdentifier.rawValue) else { return }
        showPane(pane)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = PaneIdentifier(rawValue: itemIdentifier.rawValue) else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.title
        item.image = pane.icon
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))

        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        PaneIdentifier.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}
