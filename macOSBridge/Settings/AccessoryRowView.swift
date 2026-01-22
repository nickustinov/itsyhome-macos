//
//  AccessoryRowView.swift
//  macOSBridge
//
//  Unified row view for accessory lists with optional drag handle
//

import AppKit

// MARK: - Layout constants

struct AccessoryRowLayout {
    static let rowHeight: CGFloat = 36
    static let cardHeight: CGFloat = 32
    static let buttonSize: CGFloat = 20
    static let iconSize: CGFloat = 16
    static let spacing: CGFloat = 6
    static let labelHeight: CGFloat = 17
    static let leftPadding: CGFloat = 8
    static let rightPadding: CGFloat = 12
    static let cardPadding: CGFloat = 2
    static let cardCornerRadius: CGFloat = 8
    static let dragHandleWidth: CGFloat = 10
}

// MARK: - Drag handle view

class DragHandleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dotSize: CGFloat = 2
        let hSpacing: CGFloat = 2
        let vSpacing: CGFloat = 2
        let totalWidth = dotSize * 2 + hSpacing
        let totalHeight = dotSize * 3 + vSpacing * 2

        let startX = (bounds.width - totalWidth) / 2
        let startY = (bounds.height - totalHeight) / 2

        NSColor.tertiaryLabelColor.setFill()

        for col in 0..<2 {
            for row in 0..<3 {
                let x = startX + CGFloat(col) * (dotSize + hSpacing)
                let y = startY + CGFloat(row) * (dotSize + vSpacing)
                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                NSBezierPath(ovalIn: dotRect).fill()
            }
        }
    }
}

// MARK: - Row configuration

struct AccessoryRowConfig {
    let name: String
    let icon: NSImage?
    let isFavourite: Bool
    let isItemHidden: Bool
    let isSectionHidden: Bool
    let showDragHandle: Bool
    let showEyeButton: Bool
    let itemId: String?  // For shortcut binding
}

// MARK: - Accessory row view

class AccessoryRowView: NSView {

    private let cardBackground = NSView()
    private var dragHandle: DragHandleView?
    private let starButton = NSButton()
    private var eyeButton: NSButton?
    private let typeIcon = NSImageView()
    private let nameLabel = NSTextField()
    private var shortcutButton: ShortcutButton?

    private var isFavourite: Bool
    private var isItemHidden: Bool
    private var itemId: String?

    var onStarToggled: (() -> Void)?
    var onEyeToggled: (() -> Void)?

    init(config: AccessoryRowConfig) {
        self.isFavourite = config.isFavourite
        self.isItemHidden = config.isItemHidden
        self.itemId = config.itemId

        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: AccessoryRowLayout.rowHeight))

        setupViews(config: config)
        updateState(config: config)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(config: AccessoryRowConfig) {
        // Card background
        cardBackground.wantsLayer = true
        cardBackground.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        cardBackground.layer?.cornerRadius = AccessoryRowLayout.cardCornerRadius
        addSubview(cardBackground)

        // Drag handle (optional)
        if config.showDragHandle {
            dragHandle = DragHandleView()
            addSubview(dragHandle!)
        }

        // Star button
        starButton.bezelStyle = .inline
        starButton.isBordered = false
        starButton.imagePosition = .imageOnly
        starButton.imageScaling = .scaleProportionallyUpOrDown
        starButton.target = self
        starButton.action = #selector(starTapped)
        addSubview(starButton)

        // Eye button (optional)
        if config.showEyeButton {
            let eye = NSButton()
            eye.bezelStyle = .inline
            eye.isBordered = false
            eye.imagePosition = .imageOnly
            eye.imageScaling = .scaleProportionallyUpOrDown
            eye.target = self
            eye.action = #selector(eyeTapped)
            eyeButton = eye
            addSubview(eye)
        }

        // Type icon
        typeIcon.imageScaling = .scaleProportionallyUpOrDown
        typeIcon.image = config.icon
        typeIcon.contentTintColor = .secondaryLabelColor
        addSubview(typeIcon)

        // Name label
        nameLabel.stringValue = config.name
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isBezeled = false
        nameLabel.isEditable = false
        nameLabel.drawsBackground = false
        addSubview(nameLabel)

        // Shortcut button (only for favourites)
        if config.showDragHandle, let itemId = config.itemId {
            let btn = ShortcutButton(frame: .zero)
            btn.shortcut = PreferencesManager.shared.shortcut(for: itemId)
            btn.onShortcutRecorded = { shortcut in
                PreferencesManager.shared.setShortcut(shortcut, for: itemId)
            }
            shortcutButton = btn
            addSubview(btn)
        }
    }

    private func updateState(config: AccessoryRowConfig) {
        // Star
        let starSymbol = isFavourite ? "star.fill" : "star"
        starButton.image = NSImage(systemSymbolName: starSymbol, accessibilityDescription: nil)
        starButton.contentTintColor = isFavourite ? .systemYellow : .tertiaryLabelColor

        // Eye
        if let eye = eyeButton {
            let eyeSymbol = isItemHidden ? "eye.slash" : "eye"
            eye.image = NSImage(systemSymbolName: eyeSymbol, accessibilityDescription: nil)
            eye.contentTintColor = isItemHidden ? .tertiaryLabelColor : .secondaryLabelColor
        }

        // Dim when hidden
        let shouldDim = isItemHidden || config.isSectionHidden
        nameLabel.alphaValue = shouldDim ? 0.5 : 1.0
        typeIcon.alphaValue = shouldDim ? 0.5 : 1.0
    }

    @objc private func starTapped() {
        isFavourite.toggle()
        let symbol = isFavourite ? "star.fill" : "star"
        starButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        starButton.contentTintColor = isFavourite ? .systemYellow : .tertiaryLabelColor
        onStarToggled?()
    }

    @objc private func eyeTapped() {
        isItemHidden.toggle()
        if let eye = eyeButton {
            let symbol = isItemHidden ? "eye.slash" : "eye"
            eye.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            eye.contentTintColor = isItemHidden ? .tertiaryLabelColor : .secondaryLabelColor
        }
        onEyeToggled?()
    }

    override func layout() {
        super.layout()

        let L = AccessoryRowLayout.self
        let cardY = L.cardPadding

        // Card background
        cardBackground.frame = NSRect(x: 0, y: cardY, width: bounds.width, height: L.cardHeight)

        var x = L.leftPadding

        // Drag handle
        if let drag = dragHandle {
            drag.frame = NSRect(x: x, y: cardY + (L.cardHeight - 14) / 2, width: L.dragHandleWidth, height: 14)
            x += L.dragHandleWidth + L.spacing
        }

        // Star button
        starButton.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.buttonSize) / 2, width: L.buttonSize, height: L.buttonSize)
        x += L.buttonSize + L.spacing

        // Eye button
        if let eye = eyeButton {
            eye.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.buttonSize) / 2, width: L.buttonSize, height: L.buttonSize)
            x += L.buttonSize + L.spacing
        }

        // Type icon (with 8pt gap from control icons)
        x += 8
        typeIcon.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.iconSize) / 2, width: L.iconSize, height: L.iconSize)
        x += L.iconSize + L.spacing

        // Shortcut button on the right (if present)
        var rightEdge = bounds.width - L.rightPadding
        if let shortcut = shortcutButton {
            let shortcutWidth: CGFloat = 100
            let shortcutHeight: CGFloat = 20
            shortcut.frame = NSRect(x: rightEdge - shortcutWidth, y: cardY + (L.cardHeight - shortcutHeight) / 2, width: shortcutWidth, height: shortcutHeight)
            rightEdge -= shortcutWidth + L.spacing
        }

        // Name label
        nameLabel.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.labelHeight) / 2, width: max(0, rightEdge - x), height: L.labelHeight)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: AccessoryRowLayout.rowHeight)
    }
}

// MARK: - Section header

class AccessorySectionHeader: NSView {

    private let titleLabel = NSTextField()
    private let chevronButton = NSButton()
    private var eyeButton: NSButton?

    private(set) var isCollapsed: Bool

    var onVisibilityToggled: (() -> Void)?
    var onCollapseToggled: (() -> Void)?

    private let showChevron: Bool

    init(title: String, isItemHidden: Bool = false, showEyeButton: Bool = false, isCollapsed: Bool = false, showChevron: Bool = false) {
        self.isCollapsed = isCollapsed
        self.showChevron = showChevron
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 32))

        if showChevron {
            chevronButton.bezelStyle = .inline
            chevronButton.isBordered = false
            chevronButton.imagePosition = .imageOnly
            chevronButton.imageScaling = .scaleNone
            chevronButton.target = self
            chevronButton.action = #selector(chevronTapped)
            updateChevron()
            addSubview(chevronButton)
        }

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = isItemHidden ? .tertiaryLabelColor : .labelColor
        titleLabel.alphaValue = isItemHidden ? 0.5 : 1.0
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        addSubview(titleLabel)

        if showEyeButton {
            let eye = NSButton()
            eye.bezelStyle = .inline
            eye.isBordered = false
            eye.imagePosition = .imageOnly
            eye.imageScaling = .scaleProportionallyUpOrDown
            let symbol = isItemHidden ? "eye.slash" : "eye"
            eye.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            eye.contentTintColor = isItemHidden ? .tertiaryLabelColor : .secondaryLabelColor
            eye.target = self
            eye.action = #selector(eyeTapped)
            eyeButton = eye
            addSubview(eye)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateChevron() {
        let symbol = isCollapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevronButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        chevronButton.contentTintColor = .secondaryLabelColor
    }

    @objc private func chevronTapped() {
        isCollapsed.toggle()
        updateChevron()
        onCollapseToggled?()
    }

    @objc private func eyeTapped() {
        onVisibilityToggled?()
    }

    override func layout() {
        super.layout()

        let L = AccessoryRowLayout.self
        var x: CGFloat = 0

        // Chevron before title
        if showChevron {
            let chevronSize: CGFloat = 14
            chevronButton.frame = NSRect(x: x, y: (bounds.height - chevronSize) / 2, width: chevronSize, height: chevronSize)
            x += chevronSize + 2
        }

        if let eye = eyeButton {
            eye.frame = NSRect(x: x, y: (bounds.height - L.buttonSize) / 2, width: L.buttonSize, height: L.buttonSize)
            x += L.buttonSize + L.spacing
        }

        titleLabel.frame = NSRect(x: x, y: (bounds.height - L.labelHeight) / 2, width: bounds.width - x - 8, height: L.labelHeight)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 32)
    }
}
