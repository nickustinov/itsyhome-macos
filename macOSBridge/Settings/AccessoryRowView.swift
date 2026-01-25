//
//  AccessoryRowView.swift
//  macOSBridge
//
//  Unified row view for accessory lists, section headers, and rooms
//

import AppKit

// MARK: - Layout constants

struct AccessoryRowLayout {
    static let rowHeight: CGFloat = 36
    static let cardHeight: CGFloat = 32
    static let buttonSize: CGFloat = 20
    static let iconSize: CGFloat = 16
    static let chevronSize: CGFloat = 14
    static let spacing: CGFloat = 6
    static let labelHeight: CGFloat = 17
    static let leftPadding: CGFloat = 8
    static let rightPadding: CGFloat = 12
    static let cardPadding: CGFloat = 2
    static let cardCornerRadius: CGFloat = 8
    static let dragHandleWidth: CGFloat = 10
    static let indentWidth: CGFloat = 20
    static let pipeSpacing: CGFloat = 8
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
    let count: Int?  // Shows count after name (for groups/rooms)

    // Left side options
    let showDragHandle: Bool
    let showChevron: Bool
    let isCollapsed: Bool

    // State
    let isFavourite: Bool
    let isItemHidden: Bool
    let isSectionHidden: Bool
    let isPinned: Bool

    // Right side buttons
    let showStarButton: Bool
    let showEyeButton: Bool
    let showPinButton: Bool

    // Other
    let itemId: String?  // For shortcut binding
    let rowTag: Int  // For identifying in callbacks
    let serviceType: String?
    let indentLevel: Int  // 0 = no indent, 1 = nested under section
    let isSectionHeader: Bool  // Uses medium weight font

    init(
        name: String,
        icon: NSImage? = nil,
        count: Int? = nil,
        showDragHandle: Bool = false,
        showChevron: Bool = false,
        isCollapsed: Bool = false,
        isFavourite: Bool = false,
        isItemHidden: Bool = false,
        isSectionHidden: Bool = false,
        isPinned: Bool = false,
        showStarButton: Bool = false,
        showEyeButton: Bool = false,
        showPinButton: Bool = false,
        itemId: String? = nil,
        rowTag: Int = 0,
        serviceType: String? = nil,
        indentLevel: Int = 0,
        isSectionHeader: Bool = false
    ) {
        self.name = name
        self.icon = icon
        self.count = count
        self.showDragHandle = showDragHandle
        self.showChevron = showChevron
        self.isCollapsed = isCollapsed
        self.isFavourite = isFavourite
        self.isItemHidden = isItemHidden
        self.isSectionHidden = isSectionHidden
        self.isPinned = isPinned
        self.showStarButton = showStarButton
        self.showEyeButton = showEyeButton
        self.showPinButton = showPinButton
        self.itemId = itemId
        self.rowTag = rowTag
        self.serviceType = serviceType
        self.indentLevel = indentLevel
        self.isSectionHeader = isSectionHeader
    }
}

// MARK: - Accessory row view

class AccessoryRowView: NSView {

    private let cardBackground = NSView()
    private var dragHandle: DragHandleView?
    private var chevronButton: NSButton?
    private var typeIcon: NSImageView?
    private let nameLabel = NSTextField()
    private var countLabel: NSTextField?

    // Right-side controls
    private var starButton: NSButton?
    private var eyeButton: NSButton?
    private var pinButton: NSButton?
    private var shortcutButton: ShortcutButton?

    // Pipe separators
    private var pipes: [NSTextField] = []

    private var isFavourite: Bool
    private var isItemHidden: Bool
    private var isPinned: Bool
    private var isCollapsed: Bool
    private let showDragHandle: Bool
    private let showChevron: Bool
    private let hasIcon: Bool
    private let indentLevel: Int
    let rowTag: Int

    var onStarToggled: (() -> Void)?
    var onEyeToggled: (() -> Void)?
    var onPinToggled: (() -> Void)?
    var onChevronToggled: (() -> Void)?

    init(config: AccessoryRowConfig) {
        self.isFavourite = config.isFavourite
        self.isItemHidden = config.isItemHidden
        self.isPinned = config.isPinned
        self.isCollapsed = config.isCollapsed
        self.showDragHandle = config.showDragHandle
        self.showChevron = config.showChevron
        self.hasIcon = config.icon != nil
        self.indentLevel = config.indentLevel
        self.rowTag = config.rowTag

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

        // Drag handle
        if config.showDragHandle {
            dragHandle = DragHandleView()
            addSubview(dragHandle!)
        }

        // Chevron (for collapsible sections)
        if config.showChevron {
            let btn = NSButton()
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.imagePosition = .imageOnly
            btn.imageScaling = .scaleNone
            btn.target = self
            btn.action = #selector(chevronTapped)
            chevronButton = btn
            addSubview(btn)
        }

        // Type icon
        if let icon = config.icon {
            let iv = NSImageView()
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.image = icon
            iv.contentTintColor = .secondaryLabelColor
            typeIcon = iv
            addSubview(iv)
        }

        // Name label
        nameLabel.stringValue = config.name
        nameLabel.font = config.isSectionHeader ? .systemFont(ofSize: 13, weight: .medium) : .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isBezeled = false
        nameLabel.isEditable = false
        nameLabel.drawsBackground = false
        addSubview(nameLabel)

        // Count label (for groups/rooms)
        if let count = config.count {
            let label = NSTextField(labelWithString: "\(count)")
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            countLabel = label
            addSubview(label)
        }

        // Right side controls with pipes
        var needsPipe = false

        // Star button
        if config.showStarButton {
            let btn = NSButton()
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.imagePosition = .imageOnly
            btn.imageScaling = .scaleProportionallyUpOrDown
            btn.target = self
            btn.action = #selector(starTapped)
            starButton = btn
            addSubview(btn)
            needsPipe = true
        }

        // Eye button
        if config.showEyeButton {
            if needsPipe {
                pipes.append(createPipe())
            }
            let btn = NSButton()
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.imagePosition = .imageOnly
            btn.imageScaling = .scaleProportionallyUpOrDown
            btn.target = self
            btn.action = #selector(eyeTapped)
            eyeButton = btn
            addSubview(btn)
            needsPipe = true
        }

        // Pin button
        if config.showPinButton {
            if needsPipe {
                pipes.append(createPipe())
            }
            let btn = NSButton()
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.imagePosition = .imageOnly
            btn.imageScaling = .scaleProportionallyUpOrDown
            btn.target = self
            btn.action = #selector(pinTapped)
            pinButton = btn
            addSubview(btn)
        }

        // Shortcut button (only for favourites with itemId)
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

    private func createPipe() -> NSTextField {
        let pipe = NSTextField(labelWithString: "|")
        pipe.font = .systemFont(ofSize: 11)
        pipe.textColor = .separatorColor
        addSubview(pipe)
        return pipe
    }

    private func updateState(config: AccessoryRowConfig) {
        // Chevron
        if let chevron = chevronButton {
            let symbol = isCollapsed ? "chevron.right" : "chevron.down"
            let imgConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            chevron.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(imgConfig)
            chevron.contentTintColor = .secondaryLabelColor
        }

        // Star
        if let star = starButton {
            let symbol = isFavourite ? "star.fill" : "star"
            star.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            star.contentTintColor = isFavourite ? .systemYellow : .tertiaryLabelColor
        }

        // Eye
        if let eye = eyeButton {
            let symbol = isItemHidden ? "eye.slash" : "eye"
            eye.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            eye.contentTintColor = isItemHidden ? .tertiaryLabelColor : .secondaryLabelColor
        }

        // Pin
        if let pin = pinButton {
            let symbol = isPinned ? "pin.fill" : "pin"
            pin.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            pin.contentTintColor = isPinned ? .systemBlue : .tertiaryLabelColor
        }

        // Dim when hidden
        let shouldDim = isItemHidden || config.isSectionHidden
        nameLabel.alphaValue = shouldDim ? 0.5 : 1.0
        typeIcon?.alphaValue = shouldDim ? 0.5 : 1.0
        countLabel?.alphaValue = shouldDim ? 0.5 : 1.0
    }

    @objc private func chevronTapped() {
        isCollapsed.toggle()
        let symbol = isCollapsed ? "chevron.right" : "chevron.down"
        let imgConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevronButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(imgConfig)
        onChevronToggled?()
    }

    @objc private func starTapped() {
        isFavourite.toggle()
        let symbol = isFavourite ? "star.fill" : "star"
        starButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        starButton?.contentTintColor = isFavourite ? .systemYellow : .tertiaryLabelColor
        onStarToggled?()
    }

    @objc private func eyeTapped() {
        isItemHidden.toggle()
        let symbol = isItemHidden ? "eye.slash" : "eye"
        eyeButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        eyeButton?.contentTintColor = isItemHidden ? .tertiaryLabelColor : .secondaryLabelColor
        onEyeToggled?()
    }

    @objc private func pinTapped() {
        isPinned.toggle()
        let symbol = isPinned ? "pin.fill" : "pin"
        pinButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        pinButton?.contentTintColor = isPinned ? .systemBlue : .tertiaryLabelColor
        onPinToggled?()
    }

    override func layout() {
        super.layout()

        let L = AccessoryRowLayout.self
        let cardY = L.cardPadding
        let indent = CGFloat(indentLevel) * L.indentWidth

        // Card background (indented)
        cardBackground.frame = NSRect(x: indent, y: cardY, width: bounds.width - indent, height: L.cardHeight)

        var x = indent + L.leftPadding

        // Drag handle (or reserved space for alignment when other rows have it)
        if showDragHandle {
            if let drag = dragHandle {
                drag.frame = NSRect(x: x, y: cardY + (L.cardHeight - 14) / 2, width: L.dragHandleWidth, height: 14)
            }
            x += L.dragHandleWidth + L.spacing
        }

        // Chevron
        if let chevron = chevronButton {
            chevron.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.chevronSize) / 2, width: L.chevronSize, height: L.chevronSize)
            x += L.chevronSize + L.spacing
        }

        // Type icon
        if let icon = typeIcon {
            icon.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.iconSize) / 2, width: L.iconSize, height: L.iconSize)
            x += L.iconSize + L.spacing
        }

        // Right-side controls (calculate from right edge)
        var rightEdge = bounds.width - L.rightPadding
        var pipeIndex = pipes.count - 1

        // Pin button
        if let pin = pinButton {
            pin.frame = NSRect(x: rightEdge - L.buttonSize, y: cardY + (L.cardHeight - L.buttonSize) / 2, width: L.buttonSize, height: L.buttonSize)
            rightEdge -= L.buttonSize

            if pipeIndex >= 0 {
                rightEdge -= L.pipeSpacing
                let pipe = pipes[pipeIndex]
                pipe.sizeToFit()
                pipe.frame = NSRect(x: rightEdge - pipe.frame.width / 2, y: cardY + (L.cardHeight - pipe.frame.height) / 2, width: pipe.frame.width, height: pipe.frame.height)
                rightEdge -= L.pipeSpacing
                pipeIndex -= 1
            }
        }

        // Eye button
        if let eye = eyeButton {
            eye.frame = NSRect(x: rightEdge - L.buttonSize, y: cardY + (L.cardHeight - L.buttonSize) / 2, width: L.buttonSize, height: L.buttonSize)
            rightEdge -= L.buttonSize

            if pipeIndex >= 0 {
                rightEdge -= L.pipeSpacing
                let pipe = pipes[pipeIndex]
                pipe.sizeToFit()
                pipe.frame = NSRect(x: rightEdge - pipe.frame.width / 2, y: cardY + (L.cardHeight - pipe.frame.height) / 2, width: pipe.frame.width, height: pipe.frame.height)
                rightEdge -= L.pipeSpacing
                pipeIndex -= 1
            }
        }

        // Star button
        if let star = starButton {
            star.frame = NSRect(x: rightEdge - L.buttonSize, y: cardY + (L.cardHeight - L.buttonSize) / 2, width: L.buttonSize, height: L.buttonSize)
            rightEdge -= L.buttonSize + L.spacing
        }

        // Shortcut button (before star if present)
        if let shortcut = shortcutButton {
            let shortcutWidth: CGFloat = 100
            let shortcutHeight: CGFloat = 20
            shortcut.frame = NSRect(x: rightEdge - shortcutWidth, y: cardY + (L.cardHeight - shortcutHeight) / 2, width: shortcutWidth, height: shortcutHeight)
            rightEdge -= shortcutWidth + L.spacing
        }

        // Count label (after name)
        var nameLabelWidth = rightEdge - x - L.spacing
        if let count = countLabel {
            count.sizeToFit()
            let countWidth = count.frame.width
            nameLabelWidth -= countWidth + 4
        }

        // Name label
        nameLabel.frame = NSRect(x: x, y: cardY + (L.cardHeight - L.labelHeight) / 2, width: max(0, nameLabelWidth), height: L.labelHeight)

        // Position count label after name
        if let count = countLabel {
            count.sizeToFit()
            let nameEndX = x + nameLabel.frame.width + 4
            count.frame = NSRect(x: nameEndX, y: cardY + (L.cardHeight - count.frame.height) / 2, width: count.frame.width, height: count.frame.height)
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: AccessoryRowLayout.rowHeight)
    }
}

// MARK: - Section header (simple version for other sections)

class AccessorySectionHeader: NSView {

    private let titleLabel = NSTextField()

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 32))

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let L = AccessoryRowLayout.self
        titleLabel.frame = NSRect(x: 0, y: (bounds.height - L.labelHeight) / 2, width: bounds.width - 8, height: L.labelHeight)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 32)
    }
}
