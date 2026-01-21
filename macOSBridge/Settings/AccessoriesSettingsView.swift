//
//  AccessoriesSettingsView.swift
//  macOSBridge
//
//  Accessories settings tab with favourites and visibility toggles
//

import AppKit

class AccessoriesSettingsView: NSView {

    private static let contentWidth: CGFloat = 480

    private let instructionsView: NSView
    private let scrollView: NSScrollView
    private let contentView: NSView
    private var menuData: MenuData?
    private var needsRebuild = false

    override init(frame frameRect: NSRect) {
        // Create instructions view (fixed at top)
        instructionsView = NSView(frame: .zero)
        instructionsView.wantsLayer = true

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

        addSubview(instructionsView)
        addSubview(scrollView)

        setupInstructions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupInstructions() {
        // Background card
        let cardView = NSView(frame: .zero)
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = DS.Colors.muted.withAlphaComponent(0.5).cgColor
        cardView.layer?.cornerRadius = DS.Radius.md
        instructionsView.addSubview(cardView)

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
        star1.frame = NSRect(x: 12, y: 28, width: iconWidth, height: 18)
        label1.frame = NSRect(x: textX, y: 26, width: 320, height: 22)
        eye2.frame = NSRect(x: 12, y: 6, width: iconWidth, height: 18)
        label2.frame = NSRect(x: textX, y: 4, width: 320, height: 22)
    }

    override func layout() {
        super.layout()

        let instructionsHeight: CGFloat = 70
        let padding: CGFloat = 12

        // Instructions at top
        instructionsView.frame = NSRect(
            x: 0,
            y: bounds.height - instructionsHeight,
            width: bounds.width,
            height: instructionsHeight
        )

        // Scroll view below instructions
        scrollView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - instructionsHeight
        )

        // Layout instructions card (first subview)
        if let cardView = instructionsView.subviews.first {
            cardView.frame = NSRect(x: padding, y: 8, width: bounds.width - padding * 2, height: 54)
        }

        // Rebuild content if needed (after layout so bounds are valid)
        if needsRebuild {
            needsRebuild = false
            rebuildContent()
        }
    }

    func configure(with data: MenuData) {
        self.menuData = data
        needsRebuild = true
        needsLayout = true
    }

    private func rebuildContent() {
        // Remove all subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }

        guard let data = menuData else { return }

        let preferences = PreferencesManager.shared
        let padding: CGFloat = 12
        let rowHeight: CGFloat = 28
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

        // Add scenes section if there are scenes (keep original order, not alphabetical)
        if !data.scenes.isEmpty {
            // Section header
            let scenesHeader = FavouritesSectionHeader(
                title: "Scenes",
                icon: NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            )
            views.append((scenesHeader, headerHeight))

            // Scene rows (original order from data)
            for scene in data.scenes {
                let isFavourite = preferences.isFavourite(sceneId: scene.uniqueIdentifier)
                let isSceneHidden = preferences.isHidden(sceneId: scene.uniqueIdentifier)
                let row = FavouritesRowView(
                    itemType: .scene(scene),
                    isFavourite: isFavourite,
                    isItemHidden: isSceneHidden
                )
                row.onFavouriteToggled = {
                    preferences.toggleFavourite(sceneId: scene.uniqueIdentifier)
                }
                row.onVisibilityToggled = {
                    preferences.toggleHidden(sceneId: scene.uniqueIdentifier)
                }
                views.append((row, rowHeight))
            }

            views.append((NSView(), sectionSpacing)) // Spacer
        }

        // Add room sections following data.rooms order
        for room in data.rooms {
            guard let services = servicesByRoom[room.uniqueIdentifier], !services.isEmpty else { continue }

            let roomIcon = iconForRoom(room.name)

            // Section header
            let header = FavouritesSectionHeader(title: room.name, icon: roomIcon)
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
            for service in sortedServices {
                let isFavourite = preferences.isFavourite(serviceId: service.uniqueIdentifier)
                let isItemHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
                let row = FavouritesRowView(
                    itemType: .service(service),
                    isFavourite: isFavourite,
                    isItemHidden: isItemHidden
                )
                row.onFavouriteToggled = {
                    preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
                }
                row.onVisibilityToggled = {
                    preferences.toggleHidden(serviceId: service.uniqueIdentifier)
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
                row.onFavouriteToggled = {
                    preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
                }
                row.onVisibilityToggled = {
                    preferences.toggleHidden(serviceId: service.uniqueIdentifier)
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
