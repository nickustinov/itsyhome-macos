//
//  AccessoriesSettingsView.swift
//  macOSBridge
//
//  Accessories settings tab with favourites and visibility toggles
//

import AppKit

// MARK: - Favourite item for drag/drop

private struct FavouriteItem {
    enum Kind {
        case scene(SceneData)
        case service(ServiceData)
    }
    let kind: Kind
    let id: String
    let name: String
}

// MARK: - Draggable favourite row

private class DraggableFavouriteRowView: NSView {

    private let starButton: NSButton
    private let dragHandle: NSImageView
    private let typeIcon: NSImageView
    private let nameLabel: NSTextField

    var onRemove: (() -> Void)?

    init(item: FavouriteItem) {
        // Star button
        starButton = NSButton(frame: .zero)
        starButton.bezelStyle = .inline
        starButton.isBordered = false
        starButton.imagePosition = .imageOnly
        starButton.imageScaling = .scaleProportionallyUpOrDown
        starButton.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
        starButton.contentTintColor = DS.Colors.warning

        // Drag handle (NSImageView so it doesn't intercept mouse events for drag)
        dragHandle = NSImageView()
        dragHandle.imageScaling = .scaleProportionallyUpOrDown
        dragHandle.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
        dragHandle.contentTintColor = DS.Colors.mutedForeground

        // Type icon
        typeIcon = NSImageView()
        typeIcon.imageScaling = .scaleProportionallyUpOrDown
        typeIcon.contentTintColor = DS.Colors.mutedForeground

        // Name label
        nameLabel = NSTextField(labelWithString: item.name)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail

        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: FavouritesRowLayout.rowHeight))

        addSubview(starButton)
        addSubview(dragHandle)
        addSubview(typeIcon)
        addSubview(nameLabel)

        starButton.target = self
        starButton.action = #selector(starClicked)

        // Set type icon based on item
        switch item.kind {
        case .scene(let scene):
            typeIcon.image = inferSceneIcon(for: scene)
        case .service(let service):
            typeIcon.image = iconForServiceType(service.serviceType)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func starClicked() {
        onRemove?()
    }

    override func layout() {
        super.layout()

        // Use exact same layout as FavouritesRowView
        let buttonSize = FavouritesRowLayout.buttonSize
        let iconSize = FavouritesRowLayout.iconSize
        let spacing = FavouritesRowLayout.spacing
        var x: CGFloat = 0

        // Star button
        starButton.frame = NSRect(
            x: x,
            y: (bounds.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
        x += buttonSize + spacing

        // Drag handle (same position as eye button)
        dragHandle.frame = NSRect(
            x: x,
            y: (bounds.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
        x += buttonSize + spacing

        // Type icon
        typeIcon.frame = NSRect(
            x: x,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        x += iconSize + spacing

        // Name label (fills remaining space)
        nameLabel.frame = NSRect(
            x: x,
            y: (bounds.height - FavouritesRowLayout.labelHeight) / 2,
            width: max(0, bounds.width - x),
            height: FavouritesRowLayout.labelHeight
        )
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: FavouritesRowLayout.rowHeight)
    }

    private func iconForServiceType(_ type: String) -> NSImage? {
        switch type {
        case ServiceTypes.lightbulb:
            return NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        case ServiceTypes.switch, ServiceTypes.outlet:
            return NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        case ServiceTypes.thermostat:
            return NSImage(systemSymbolName: "thermometer", accessibilityDescription: nil)
        case ServiceTypes.heaterCooler:
            return NSImage(systemSymbolName: "air.conditioner.horizontal", accessibilityDescription: nil)
        case ServiceTypes.lock:
            return NSImage(systemSymbolName: "lock", accessibilityDescription: nil)
        case ServiceTypes.windowCovering:
            return NSImage(systemSymbolName: "blinds.horizontal.closed", accessibilityDescription: nil)
        case ServiceTypes.fan:
            return NSImage(systemSymbolName: "fan", accessibilityDescription: nil)
        case ServiceTypes.garageDoorOpener:
            return NSImage(systemSymbolName: "door.garage.closed", accessibilityDescription: nil)
        case ServiceTypes.contactSensor:
            return NSImage(systemSymbolName: "door.left.hand.closed", accessibilityDescription: nil)
        default:
            return NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
        }
    }

    private func inferSceneIcon(for scene: SceneData) -> NSImage? {
        let name = scene.name.lowercased()
        if name.contains("night") || name.contains("sleep") || name.contains("goodnight") || name.contains("bed") {
            return NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)
        }
        if name.contains("morning") || name.contains("wake") || name.contains("sunrise") {
            return NSImage(systemSymbolName: "sun.horizon.fill", accessibilityDescription: nil)
        }
        if name.contains("evening") || name.contains("sunset") {
            return NSImage(systemSymbolName: "sun.haze.fill", accessibilityDescription: nil)
        }
        if name.contains("away") || name.contains("leave") || name.contains("depart") || name.contains("goodbye") {
            return NSImage(systemSymbolName: "figure.walk", accessibilityDescription: nil)
        }
        if name.contains("home") || name.contains("arrive") || name.contains("welcome") {
            return NSImage(systemSymbolName: "house.fill", accessibilityDescription: nil)
        }
        if name.contains("off") || name.contains("all off") {
            return NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        }
        if name.contains("on") || name.contains("all on") {
            return NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: nil)
        }
        return NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
    }
}

// MARK: - Pasteboard type for drag/drop

private extension NSPasteboard.PasteboardType {
    static let favouriteItem = NSPasteboard.PasteboardType("com.itsyhome.favouriteItem")
}

// MARK: - Main view

class AccessoriesSettingsView: NSView {

    private static let contentWidth: CGFloat = 480

    private let scrollView: NSScrollView
    private let contentView: NSView
    private var menuData: MenuData?
    private var needsRebuild = false
    private var shouldScrollToTop = true

    // Favourites table (embedded in content)
    private var favouritesTableView: NSTableView?
    private var favouriteItems: [FavouriteItem] = []

    override init(frame frameRect: NSRect) {
        // Create scroll view
        scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Create content view for scroll view
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        super.init(frame: frameRect)

        addSubview(scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        // Scroll view fills the entire view
        scrollView.frame = bounds

        // Rebuild content if needed (after layout so bounds are valid)
        if needsRebuild {
            needsRebuild = false
            rebuildContent()
        }
    }

    func configure(with data: MenuData) {
        self.menuData = data
        needsRebuild = true
        shouldScrollToTop = true
        needsLayout = true
    }

    private func rebuildFavouritesList() {
        guard let data = menuData else {
            favouriteItems = []
            return
        }

        let preferences = PreferencesManager.shared

        // Build lookup maps
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let serviceLookup = Dictionary(uniqueKeysWithValues: data.accessories.flatMap { $0.services }.map { ($0.uniqueIdentifier, $0) })

        // Build ordered favourites list from unified list
        var items: [FavouriteItem] = []

        for id in preferences.orderedFavouriteIds {
            if let scene = sceneLookup[id] {
                items.append(FavouriteItem(kind: .scene(scene), id: id, name: scene.name))
            } else if let service = serviceLookup[id] {
                items.append(FavouriteItem(kind: .service(service), id: id, name: service.name))
            }
        }

        favouriteItems = items
    }

    private func rebuildContent() {
        // Rebuild favourites first
        rebuildFavouritesList()

        // Remove all subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        favouritesTableView = nil

        guard let data = menuData else { return }

        let preferences = PreferencesManager.shared
        let padding: CGFloat = 12
        let rowHeight = FavouritesRowLayout.rowHeight
        let headerHeight: CGFloat = 32
        let sectionSpacing: CGFloat = 12

        // Types to exclude (sensors)
        let excludedTypes: Set<String> = [
            ServiceTypes.temperatureSensor,
            ServiceTypes.humiditySensor,
            ServiceTypes.motionSensor
        ]

        // Service type order (same as menu)
        let typeOrder: [String] = [
            ServiceTypes.lightbulb,
            ServiceTypes.switch,
            ServiceTypes.outlet,
            ServiceTypes.fan,
            ServiceTypes.heaterCooler,
            ServiceTypes.thermostat,
            ServiceTypes.windowCovering,
            ServiceTypes.lock,
            ServiceTypes.garageDoorOpener,
            ServiceTypes.contactSensor
        ]

        // Collect services by room, following rooms order from data.rooms
        var servicesByRoom: [String: [ServiceData]] = [:]
        var noRoomServices: [ServiceData] = []

        for accessory in data.accessories {
            for service in accessory.services {
                guard !excludedTypes.contains(service.serviceType) else { continue }

                if let roomId = service.roomIdentifier {
                    servicesByRoom[roomId, default: []].append(service)
                } else {
                    noRoomServices.append(service)
                }
            }
        }

        // Build views from bottom to top (flipped coordinate system in scroll view is false)
        var views: [(view: NSView, height: CGFloat)] = []

        // Instructions card at top
        let instructionsCard = createInstructionsCard()
        views.append((instructionsCard, 62))

        views.append((NSView(), sectionSpacing)) // Spacer

        // Favourites section
        if !favouriteItems.isEmpty {
            let favouritesHeader = FavouritesSectionHeader(
                title: "Favourites",
                icon: NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
            )
            views.append((favouritesHeader, headerHeight))
            views.append((NSView(), 12)) // Small gap after header

            // Create embedded table view for favourites (supports drag-drop)
            let tableHeight = CGFloat(favouriteItems.count) * rowHeight
            let tableContainer = createFavouritesTable(width: scrollView.bounds.width - padding * 2, height: tableHeight)
            views.append((tableContainer, tableHeight))

            views.append((NSView(), sectionSpacing * 2)) // Extra spacer before next section
        }

        // Add scenes section if there are scenes (keep original order, not alphabetical)
        if !data.scenes.isEmpty {
            // Section header
            let scenesHeader = FavouritesSectionHeader(
                title: "Scenes",
                icon: NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil),
                isHidden: preferences.hideScenesSection,
                showEyeButton: true
            )
            scenesHeader.onVisibilityToggled = { [weak self] in
                preferences.hideScenesSection.toggle()
                self?.needsRebuild = true
                self?.needsLayout = true
            }
            views.append((scenesHeader, headerHeight))

            // Scene rows (original order from data)
            let isScenesHidden = preferences.hideScenesSection
            for scene in data.scenes {
                let isFavourite = preferences.isFavourite(sceneId: scene.uniqueIdentifier)
                let isSceneHidden = preferences.isHidden(sceneId: scene.uniqueIdentifier)
                let row = FavouritesRowView(
                    itemType: .scene(scene),
                    isFavourite: isFavourite,
                    isItemHidden: isSceneHidden,
                    isSectionHidden: isScenesHidden
                )
                row.onFavouriteToggled = { [weak self] in
                    preferences.toggleFavourite(sceneId: scene.uniqueIdentifier)
                    self?.needsRebuild = true
                    self?.needsLayout = true
                }
                row.onVisibilityToggled = { [weak self] in
                    preferences.toggleHidden(sceneId: scene.uniqueIdentifier)
                    self?.needsRebuild = true
                    self?.needsLayout = true
                }
                views.append((row, rowHeight))
            }

            views.append((NSView(), sectionSpacing)) // Spacer
        }

        // Add room sections following data.rooms order
        for room in data.rooms {
            guard let services = servicesByRoom[room.uniqueIdentifier], !services.isEmpty else { continue }

            let roomIcon = iconForRoom(room.name)
            let roomId = room.uniqueIdentifier

            // Section header with eye button
            let header = FavouritesSectionHeader(
                title: room.name,
                icon: roomIcon,
                isHidden: preferences.isHidden(roomId: roomId),
                showEyeButton: true
            )
            header.onVisibilityToggled = { [weak self] in
                preferences.toggleHidden(roomId: roomId)
                self?.needsRebuild = true
                self?.needsLayout = true
            }
            views.append((header, headerHeight))

            // Sort services by type order, then by name within type
            let sortedServices = services.sorted { s1, s2 in
                let idx1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                let idx2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                if idx1 != idx2 {
                    return idx1 < idx2
                }
                return s1.name < s2.name
            }

            // Service rows
            let isRoomHidden = preferences.isHidden(roomId: roomId)
            for service in sortedServices {
                let isFavourite = preferences.isFavourite(serviceId: service.uniqueIdentifier)
                let isItemHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
                let row = FavouritesRowView(
                    itemType: .service(service),
                    isFavourite: isFavourite,
                    isItemHidden: isItemHidden,
                    isSectionHidden: isRoomHidden
                )
                row.onFavouriteToggled = { [weak self] in
                    preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
                    self?.needsRebuild = true
                    self?.needsLayout = true
                }
                row.onVisibilityToggled = { [weak self] in
                    preferences.toggleHidden(serviceId: service.uniqueIdentifier)
                    self?.needsRebuild = true
                    self?.needsLayout = true
                }
                views.append((row, rowHeight))
            }

            views.append((NSView(), sectionSpacing)) // Spacer
        }

        // Add "Other" section for services without room
        if !noRoomServices.isEmpty {
            let header = FavouritesSectionHeader(
                title: "Other",
                icon: NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
            )
            views.append((header, headerHeight))

            let sortedServices = noRoomServices.sorted { s1, s2 in
                let idx1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                let idx2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                if idx1 != idx2 {
                    return idx1 < idx2
                }
                return s1.name < s2.name
            }

            for service in sortedServices {
                let isFavourite = preferences.isFavourite(serviceId: service.uniqueIdentifier)
                let isItemHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
                let row = FavouritesRowView(
                    itemType: .service(service),
                    isFavourite: isFavourite,
                    isItemHidden: isItemHidden
                )
                row.onFavouriteToggled = { [weak self] in
                    preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
                    self?.needsRebuild = true
                    self?.needsLayout = true
                }
                row.onVisibilityToggled = { [weak self] in
                    preferences.toggleHidden(serviceId: service.uniqueIdentifier)
                    self?.needsRebuild = true
                    self?.needsLayout = true
                }
                views.append((row, rowHeight))
            }

            views.append((NSView(), sectionSpacing)) // Spacer
        }

        // Calculate total height
        let totalHeight = views.reduce(0) { $0 + $1.height } + padding * 2

        // Set content view size (use fixed width, actual scroll view width from bounds)
        let contentWidth = max(Self.contentWidth, scrollView.bounds.width)
        contentView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: totalHeight)

        // Layout views from top to bottom
        var currentY = totalHeight - padding
        for (view, height) in views {
            currentY -= height
            view.frame = NSRect(
                x: padding,
                y: currentY,
                width: contentWidth - (padding * 2),
                height: height
            )
            contentView.addSubview(view)
        }

        // Scroll to top only on initial load
        if shouldScrollToTop {
            shouldScrollToTop = false
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: totalHeight - self.scrollView.bounds.height))
            }
        }
    }

    private func createInstructionsCard() -> NSView {
        let cardView = NSView(frame: .zero)
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = DS.Colors.muted.withAlphaComponent(0.5).cgColor
        cardView.layer?.cornerRadius = DS.Radius.md

        let iconWidth: CGFloat = 24

        // Line 1: star icon + text
        let star1 = NSImageView(frame: .zero)
        star1.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
        star1.contentTintColor = DS.Colors.warning
        star1.imageScaling = .scaleProportionallyUpOrDown
        cardView.addSubview(star1)

        let label1 = NSTextField(labelWithString: "Add to favourites (shown at top of menu)")
        label1.font = DS.Typography.label
        label1.textColor = DS.Colors.foreground
        cardView.addSubview(label1)

        // Line 2: eye icon + text
        let eye2 = NSImageView(frame: .zero)
        eye2.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        eye2.contentTintColor = DS.Colors.foreground
        eye2.imageScaling = .scaleProportionallyUpOrDown
        cardView.addSubview(eye2)

        let label2 = NSTextField(labelWithString: "Toggle visibility in menus")
        label2.font = DS.Typography.label
        label2.textColor = DS.Colors.foreground
        cardView.addSubview(label2)

        // Set frames directly (static layout)
        let textX: CGFloat = 12 + iconWidth + 8
        star1.frame = NSRect(x: 12, y: 32, width: iconWidth, height: 18)
        label1.frame = NSRect(x: textX, y: 30, width: 320, height: 22)
        eye2.frame = NSRect(x: 12, y: 8, width: iconWidth, height: 18)
        label2.frame = NSRect(x: textX, y: 6, width: 320, height: 22)

        return cardView
    }

    private func createFavouritesTable(width: CGFloat, height: CGFloat) -> NSView {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = FavouritesRowLayout.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.registerForDraggedTypes([.favouriteItem])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = width
        tableView.addTableColumn(column)

        self.favouritesTableView = tableView

        // Container view (no scroll view - table is embedded directly)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        tableView.frame = container.bounds
        container.addSubview(tableView)

        return container
    }

    // MARK: - Icon helpers

    private func iconForRoom(_ name: String) -> NSImage? {
        let lowercased = name.lowercased()

        let symbolName: String
        if lowercased.contains("living") {
            symbolName = "sofa"
        } else if lowercased.contains("bedroom") || lowercased.contains("bed") {
            symbolName = "bed.double"
        } else if lowercased.contains("kitchen") {
            symbolName = "refrigerator"
        } else if lowercased.contains("bath") {
            symbolName = "shower"
        } else if lowercased.contains("office") || lowercased.contains("study") {
            symbolName = "desktopcomputer"
        } else if lowercased.contains("garage") {
            symbolName = "car"
        } else if lowercased.contains("garden") || lowercased.contains("outdoor") {
            symbolName = "leaf"
        } else if lowercased.contains("dining") {
            symbolName = "fork.knife"
        } else if lowercased.contains("hall") || lowercased.contains("corridor") {
            symbolName = "door.left.hand.open"
        } else {
            symbolName = "square.split.bottomrightquarter"
        }

        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }
}

// MARK: - Favourites Table View Delegate/DataSource

extension AccessoriesSettingsView: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return favouriteItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = favouriteItems[row]
        let rowView = DraggableFavouriteRowView(item: item)
        rowView.onRemove = { [weak self] in
            let preferences = PreferencesManager.shared
            switch item.kind {
            case .scene:
                preferences.toggleFavourite(sceneId: item.id)
            case .service:
                preferences.toggleFavourite(serviceId: item.id)
            }
            self?.needsRebuild = true
            self?.needsLayout = true
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return FavouritesRowLayout.rowHeight
    }

    // MARK: - Drag and Drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = favouriteItems[row]
        let pasteboardItem = NSPasteboardItem()
        // Write the item ID to pasteboard (not row index)
        pasteboardItem.setString(item.id, forType: .favouriteItem)
        return pasteboardItem
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let pasteboardItem = items.first,
              let draggedId = pasteboardItem.string(forType: .favouriteItem),
              let originalRow = favouriteItems.firstIndex(where: { $0.id == draggedId }) else {
            return false
        }

        // Calculate destination row - adjust if dragging downward
        var newRow = row
        if originalRow < newRow {
            newRow -= 1
        }

        // Don't do anything if dropping in same position
        if originalRow == newRow {
            return false
        }

        // Move in the unified list
        PreferencesManager.shared.moveFavourite(from: originalRow, to: newRow)

        // Rebuild the favourites list and animate the table
        rebuildFavouritesList()

        tableView.beginUpdates()
        tableView.moveRow(at: originalRow, to: newRow)
        tableView.endUpdates()

        return true
    }
}
