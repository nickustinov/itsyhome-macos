//
//  AccessoriesSettingsView.swift
//  macOSBridge
//
//  Accessories settings tab with favourites and visibility toggles
//

import AppKit

// MARK: - Favourite item for drag/drop

struct FavouriteItem {
    enum Kind {
        case scene(SceneData)
        case service(ServiceData)
    }
    let kind: Kind
    let id: String
    let name: String
    let icon: NSImage?
}

extension NSPasteboard.PasteboardType {
    static let favouriteItem = NSPasteboard.PasteboardType("com.itsyhome.favouriteItem")
    static let roomItem = NSPasteboard.PasteboardType("com.itsyhome.roomItem")
    static let sceneItem = NSPasteboard.PasteboardType("com.itsyhome.sceneItem")
}

// MARK: - Room table item

enum RoomTableItem {
    case header(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int)
    case accessory(service: ServiceData, roomHidden: Bool)
}

// MARK: - Main view

class AccessoriesSettingsView: NSView {

    private let stackView = NSStackView()
    private var menuData: MenuData?
    private var needsRebuild = false

    private var favouritesTableView: NSTableView?
    private var roomsTableView: NSTableView?
    private var scenesTableView: NSTableView?

    private var favouriteItems: [FavouriteItem] = []
    private var roomTableItems: [RoomTableItem] = []
    private var sceneItems: [SceneData] = []
    private var orderedRooms: [RoomData] = []

    private var expandedSections: Set<String> = []
    private var servicesByRoom: [String: [ServiceData]] = [:]
    private var noRoomServices: [ServiceData] = []

    private let typeOrder = [ServiceTypes.lightbulb, ServiceTypes.switch, ServiceTypes.outlet, ServiceTypes.fan,
                             ServiceTypes.heaterCooler, ServiceTypes.thermostat, ServiceTypes.windowCovering,
                             ServiceTypes.lock, ServiceTypes.garageDoorOpener]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        if needsRebuild {
            needsRebuild = false
            rebuildContent()
        }
    }

    func configure(with data: MenuData) {
        self.menuData = data
        PreferencesManager.shared.currentHomeId = data.selectedHomeId
        needsRebuild = true
        needsLayout = true
    }

    // MARK: - Build data

    private func rebuildFavouritesList() {
        guard let data = menuData else {
            favouriteItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let serviceLookup = Dictionary(uniqueKeysWithValues: data.accessories.flatMap { $0.services }.map { ($0.uniqueIdentifier, $0) })

        var items: [FavouriteItem] = []
        for id in preferences.orderedFavouriteIds {
            if let scene = sceneLookup[id] {
                items.append(FavouriteItem(kind: .scene(scene), id: id, name: scene.name, icon: SceneIconInference.icon(for: scene.name)))
            } else if let service = serviceLookup[id] {
                items.append(FavouriteItem(kind: .service(service), id: id, name: service.name, icon: IconMapping.iconForServiceType(service.serviceType)))
            }
        }
        favouriteItems = items
    }

    private func rebuildRoomData() {
        guard let data = menuData else {
            roomTableItems = []
            orderedRooms = []
            return
        }

        let preferences = PreferencesManager.shared
        let excludedTypes: Set<String> = [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]

        servicesByRoom = [:]
        noRoomServices = []

        for accessory in data.accessories {
            for service in accessory.services where !excludedTypes.contains(service.serviceType) {
                if let roomId = service.roomIdentifier {
                    servicesByRoom[roomId, default: []].append(service)
                } else {
                    noRoomServices.append(service)
                }
            }
        }

        // Order rooms by saved order, with unseen rooms appended at end
        let roomsWithServices = data.rooms.filter { servicesByRoom[$0.uniqueIdentifier] != nil }
        let savedOrder = preferences.roomOrder
        var ordered: [RoomData] = []
        for roomId in savedOrder {
            if let room = roomsWithServices.first(where: { $0.uniqueIdentifier == roomId }) {
                ordered.append(room)
            }
        }
        for room in roomsWithServices where !ordered.contains(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) {
            ordered.append(room)
        }
        orderedRooms = ordered

        // Update saved order to match current state
        preferences.roomOrder = ordered.map { $0.uniqueIdentifier }

        // Build flat table items
        var items: [RoomTableItem] = []
        for room in ordered {
            let roomId = room.uniqueIdentifier
            let isHidden = preferences.isHidden(roomId: roomId)
            let isCollapsed = !expandedSections.contains(roomId)
            let services = servicesByRoom[roomId] ?? []

            items.append(.header(room: room, isHidden: isHidden, isCollapsed: isCollapsed, serviceCount: services.count))

            if !isCollapsed {
                let sorted = services.sorted { s1, s2 in
                    let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                    let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                    return i1 != i2 ? i1 < i2 : s1.name < s2.name
                }
                for service in sorted {
                    items.append(.accessory(service: service, roomHidden: isHidden))
                }
            }
        }
        roomTableItems = items
    }

    private func rebuildSceneData() {
        guard let data = menuData else {
            sceneItems = []
            return
        }

        let preferences = PreferencesManager.shared
        let savedOrder = preferences.sceneOrder
        var ordered: [SceneData] = []
        for sceneId in savedOrder {
            if let scene = data.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
                ordered.append(scene)
            }
        }
        for scene in data.scenes where !ordered.contains(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) {
            ordered.append(scene)
        }
        sceneItems = ordered
        preferences.sceneOrder = ordered.map { $0.uniqueIdentifier }
    }

    // MARK: - Build content

    private func rebuildContent() {
        rebuildFavouritesList()
        rebuildRoomData()
        rebuildSceneData()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        favouritesTableView = nil
        roomsTableView = nil
        scenesTableView = nil

        guard let data = menuData else { return }

        let preferences = PreferencesManager.shared
        let L = AccessoryRowLayout.self

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "Add accessories to Favourites to pin them at the top of your menu. Use the eye icon to hide sections or devices you don't need.")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(descLabel)
        descLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        addSpacer(height: 16)

        // Favourites section
        if !favouriteItems.isEmpty {
            addHeader(title: "Favourites")
            addSpacer(height: 4)

            let tableHeight = CGFloat(favouriteItems.count) * L.rowHeight
            let tableContainer = createFavouritesTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
            favouritesTableView?.reloadData()
            addSpacer(height: 16)
        }

        // Scenes section
        if !data.scenes.isEmpty {
            let scenesKey = "scenes"
            let isHidden = preferences.hideScenesSection
            let isScenesCollapsed = !expandedSections.contains(scenesKey)

            let header = createScenesHeaderStrip(isHidden: isHidden, isCollapsed: isScenesCollapsed)
            addView(header, height: L.rowHeight)

            if !isScenesCollapsed {
                let tableHeight = CGFloat(sceneItems.count) * L.rowHeight
                let tableContainer = createScenesTable(height: tableHeight)
                addView(tableContainer, height: tableHeight)
                scenesTableView?.reloadData()
            }
            addSpacer(height: 12)
        }

        // Rooms section
        if !roomTableItems.isEmpty {
            let tableHeight = CGFloat(roomTableItems.count) * L.rowHeight + CGFloat(max(0, roomTableItems.count - 1)) * 4
            let tableContainer = createRoomsTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
            roomsTableView?.reloadData()
            addSpacer(height: 12)
        }

        // Other section (no room)
        if !noRoomServices.isEmpty {
            let otherKey = "other"
            let isOtherCollapsed = !expandedSections.contains(otherKey)

            let header = createOtherHeaderStrip(isCollapsed: isOtherCollapsed)
            addView(header, height: L.rowHeight)

            if !isOtherCollapsed {
                let sorted = noRoomServices.sorted { s1, s2 in
                    let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                    let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                    return i1 != i2 ? i1 < i2 : s1.name < s2.name
                }

                let pinnableTypes: Set<String> = [ServiceTypes.thermostat, ServiceTypes.heaterCooler]
                for service in sorted {
                    let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
                    let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
                    let isPinned = preferences.isPinned(serviceId: service.uniqueIdentifier)
                    let showPin = pinnableTypes.contains(service.serviceType)
                    let config = AccessoryRowConfig(
                        name: service.name,
                        icon: IconMapping.iconForServiceType(service.serviceType),
                        isFavourite: isFav,
                        isItemHidden: isServiceHidden,
                        isSectionHidden: false,
                        showDragHandle: false,
                        showEyeButton: true,
                        itemId: nil,
                        showPinButton: showPin,
                        isPinned: isPinned,
                        serviceType: service.serviceType
                    )
                    let row = AccessoryRowView(config: config)
                    row.onStarToggled = { [weak self] in
                        preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
                        self?.rebuild()
                    }
                    row.onEyeToggled = { [weak self] in
                        preferences.toggleHidden(serviceId: service.uniqueIdentifier)
                        self?.rebuild()
                    }
                    row.onPinToggled = { [weak self] in
                        preferences.togglePinned(serviceId: service.uniqueIdentifier)
                        self?.rebuild()
                    }
                    addView(row, height: L.rowHeight)
                }
            }
            addSpacer(height: 12)
        }
    }

    private func rebuild() {
        needsRebuild = true
        needsLayout = true
    }

    // MARK: - Scenes header strip (CardBoxView, no drag handle)

    private func createScenesHeaderStrip(isHidden: Bool, isCollapsed: Bool) -> NSView {
        let preferences = PreferencesManager.shared
        let L = AccessoryRowLayout.self

        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let chevronButton = NSButton()
        chevronButton.bezelStyle = .inline
        chevronButton.isBordered = false
        chevronButton.imagePosition = .imageOnly
        chevronButton.imageScaling = .scaleNone
        let chevronSymbol = isCollapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevronButton.image = NSImage(systemSymbolName: chevronSymbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        chevronButton.contentTintColor = .secondaryLabelColor
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chevronButton)

        let eyeButton = NSButton()
        eyeButton.bezelStyle = .inline
        eyeButton.isBordered = false
        eyeButton.imagePosition = .imageOnly
        eyeButton.imageScaling = .scaleProportionallyUpOrDown
        let eyeSymbol = isHidden ? "eye.slash" : "eye"
        eyeButton.image = NSImage(systemSymbolName: eyeSymbol, accessibilityDescription: nil)
        eyeButton.contentTintColor = isHidden ? .tertiaryLabelColor : .secondaryLabelColor
        eyeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(eyeButton)

        let nameLabel = NSTextField(labelWithString: "Scenes")
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = isHidden ? .tertiaryLabelColor : .labelColor
        nameLabel.alphaValue = isHidden ? 0.5 : 1.0
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            chevronButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: L.leftPadding),
            chevronButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 14),
            chevronButton.heightAnchor.constraint(equalToConstant: 14),

            eyeButton.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: L.spacing),
            eyeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            eyeButton.widthAnchor.constraint(equalToConstant: L.buttonSize),
            eyeButton.heightAnchor.constraint(equalToConstant: L.buttonSize),

            nameLabel.leadingAnchor.constraint(equalTo: eyeButton.trailingAnchor, constant: L.spacing),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -L.rightPadding)
        ])

        chevronButton.target = self
        chevronButton.action = #selector(scenesChevronTapped)
        eyeButton.target = self
        eyeButton.action = #selector(scenesEyeTapped)

        return container
    }

    @objc private func scenesChevronTapped() {
        let scenesKey = "scenes"
        if expandedSections.contains(scenesKey) {
            expandedSections.remove(scenesKey)
        } else {
            expandedSections.insert(scenesKey)
        }
        rebuild()
    }

    @objc private func scenesEyeTapped() {
        PreferencesManager.shared.hideScenesSection.toggle()
        rebuild()
    }

    // MARK: - Other header strip (CardBoxView, no drag handle)

    private func createOtherHeaderStrip(isCollapsed: Bool) -> NSView {
        let L = AccessoryRowLayout.self

        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let chevronButton = NSButton()
        chevronButton.bezelStyle = .inline
        chevronButton.isBordered = false
        chevronButton.imagePosition = .imageOnly
        chevronButton.imageScaling = .scaleNone
        let chevronSymbol = isCollapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevronButton.image = NSImage(systemSymbolName: chevronSymbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        chevronButton.contentTintColor = .secondaryLabelColor
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chevronButton)

        let nameLabel = NSTextField(labelWithString: "Other")
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            chevronButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: L.leftPadding),
            chevronButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 14),
            chevronButton.heightAnchor.constraint(equalToConstant: 14),

            nameLabel.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: L.spacing),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -L.rightPadding)
        ])

        chevronButton.target = self
        chevronButton.action = #selector(otherChevronTapped)

        return container
    }

    @objc private func otherChevronTapped() {
        let otherKey = "other"
        if expandedSections.contains(otherKey) {
            expandedSections.remove(otherKey)
        } else {
            expandedSections.insert(otherKey)
        }
        rebuild()
    }

    // MARK: - Room header strip (CardBoxView with drag handle)

    private func createRoomHeaderView(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int) -> NSView {
        let L = AccessoryRowLayout.self

        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let dragHandle = DragHandleView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dragHandle)

        let chevronButton = NSButton()
        chevronButton.bezelStyle = .inline
        chevronButton.isBordered = false
        chevronButton.imagePosition = .imageOnly
        chevronButton.imageScaling = .scaleNone
        let chevronSymbol = isCollapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevronButton.image = NSImage(systemSymbolName: chevronSymbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        chevronButton.contentTintColor = .secondaryLabelColor
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        chevronButton.tag = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) ?? 0
        chevronButton.target = self
        chevronButton.action = #selector(roomChevronTapped(_:))
        container.addSubview(chevronButton)

        let eyeButton = NSButton()
        eyeButton.bezelStyle = .inline
        eyeButton.isBordered = false
        eyeButton.imagePosition = .imageOnly
        eyeButton.imageScaling = .scaleProportionallyUpOrDown
        let eyeSymbol = isHidden ? "eye.slash" : "eye"
        eyeButton.image = NSImage(systemSymbolName: eyeSymbol, accessibilityDescription: nil)
        eyeButton.contentTintColor = isHidden ? .tertiaryLabelColor : .secondaryLabelColor
        eyeButton.translatesAutoresizingMaskIntoConstraints = false
        eyeButton.tag = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) ?? 0
        eyeButton.target = self
        eyeButton.action = #selector(roomEyeTapped(_:))
        container.addSubview(eyeButton)

        let nameLabel = NSTextField(labelWithString: room.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = isHidden ? .tertiaryLabelColor : .labelColor
        nameLabel.alphaValue = isHidden ? 0.5 : 1.0
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let countLabel = NSTextField(labelWithString: "\(serviceCount)")
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alphaValue = isHidden ? 0.5 : 1.0
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)

        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: L.leftPadding),
            dragHandle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: L.dragHandleWidth),
            dragHandle.heightAnchor.constraint(equalToConstant: 14),

            chevronButton.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: L.spacing),
            chevronButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 14),
            chevronButton.heightAnchor.constraint(equalToConstant: 14),

            eyeButton.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: L.spacing),
            eyeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            eyeButton.widthAnchor.constraint(equalToConstant: L.buttonSize),
            eyeButton.heightAnchor.constraint(equalToConstant: L.buttonSize),

            nameLabel.leadingAnchor.constraint(equalTo: eyeButton.trailingAnchor, constant: L.spacing),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            countLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 4),
            countLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -L.rightPadding)
        ])

        return container
    }

    @objc private func roomChevronTapped(_ sender: NSButton) {
        guard sender.tag < orderedRooms.count else { return }
        let roomId = orderedRooms[sender.tag].uniqueIdentifier
        if expandedSections.contains(roomId) {
            expandedSections.remove(roomId)
        } else {
            expandedSections.insert(roomId)
        }
        rebuild()
    }

    @objc private func roomEyeTapped(_ sender: NSButton) {
        guard sender.tag < orderedRooms.count else { return }
        let roomId = orderedRooms[sender.tag].uniqueIdentifier
        PreferencesManager.shared.toggleHidden(roomId: roomId)
        rebuild()
    }

    // MARK: - Helpers

    private func addHeader(title: String) {
        let header = AccessorySectionHeader(title: title)
        addView(header, height: 32)
    }

    private func addView(_ view: NSView, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    // MARK: - Favourites table

    private func createFavouritesTable(height: CGFloat) -> NSView {
        let tableView = NSTableView()
        self.favouritesTableView = tableView
        tableView.headerView = nil
        tableView.rowHeight = AccessoryRowLayout.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.gridStyleMask = []
        tableView.registerForDraggedTypes([.favouriteItem])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        tableView.delegate = self
        tableView.dataSource = self

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Rooms table

    private func createRoomsTable(height: CGFloat) -> NSView {
        let tableView = NSTableView()
        self.roomsTableView = tableView
        tableView.headerView = nil
        tableView.rowHeight = AccessoryRowLayout.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.gridStyleMask = []
        tableView.registerForDraggedTypes([.roomItem])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        tableView.delegate = self
        tableView.dataSource = self

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Scenes table

    private func createScenesTable(height: CGFloat) -> NSView {
        let tableView = NSTableView()
        self.scenesTableView = tableView
        tableView.headerView = nil
        tableView.rowHeight = AccessoryRowLayout.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.gridStyleMask = []
        tableView.registerForDraggedTypes([.sceneItem])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        tableView.delegate = self
        tableView.dataSource = self

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Room index helpers

    /// Find the index in orderedRooms for a given room table row
    private func roomIndex(forTableRow row: Int) -> Int? {
        var headerCount = 0
        for i in 0...row {
            if case .header = roomTableItems[i] {
                if i == row { return headerCount }
                headerCount += 1
            }
        }
        return nil
    }

    /// Find the table row index for a given room index in orderedRooms
    private func tableRow(forRoomIndex roomIndex: Int) -> Int? {
        var headerCount = 0
        for (i, item) in roomTableItems.enumerated() {
            if case .header = item {
                if headerCount == roomIndex { return i }
                headerCount += 1
            }
        }
        return nil
    }
}

// MARK: - Table delegate

extension AccessoriesSettingsView: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === favouritesTableView { return favouriteItems.count }
        if tableView === roomsTableView { return roomTableItems.count }
        if tableView === scenesTableView { return sceneItems.count }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === favouritesTableView {
            return createFavouriteRowView(row: row)
        }
        if tableView === roomsTableView {
            return createRoomTableRowView(row: row)
        }
        if tableView === scenesTableView {
            return createSceneRowView(row: row)
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        AccessoryRowLayout.rowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isGroupRowStyle = false
        return rowView
    }

    // MARK: - Row creation

    private func createFavouriteRowView(row: Int) -> NSView {
        let item = favouriteItems[row]
        let config = AccessoryRowConfig(
            name: item.name,
            icon: item.icon,
            isFavourite: true,
            isItemHidden: false,
            isSectionHidden: false,
            showDragHandle: true,
            showEyeButton: false,
            itemId: item.id
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onStarToggled = { [weak self] in
            let preferences = PreferencesManager.shared
            switch item.kind {
            case .scene: preferences.toggleFavourite(sceneId: item.id)
            case .service: preferences.toggleFavourite(serviceId: item.id)
            }
            self?.rebuild()
        }
        return rowView
    }

    private func createRoomTableRowView(row: Int) -> NSView {
        let item = roomTableItems[row]
        switch item {
        case .header(let room, let isHidden, let isCollapsed, let serviceCount):
            return createRoomHeaderView(room: room, isHidden: isHidden, isCollapsed: isCollapsed, serviceCount: serviceCount)
        case .accessory(let service, let roomHidden):
            let preferences = PreferencesManager.shared
            let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
            let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
            let isPinned = preferences.isPinned(serviceId: service.uniqueIdentifier)
            let pinnableTypes: Set<String> = [ServiceTypes.thermostat, ServiceTypes.heaterCooler]
            let showPin = pinnableTypes.contains(service.serviceType)
            let config = AccessoryRowConfig(
                name: service.name,
                icon: IconMapping.iconForServiceType(service.serviceType),
                isFavourite: isFav,
                isItemHidden: isServiceHidden,
                isSectionHidden: roomHidden,
                showDragHandle: false,
                showEyeButton: true,
                itemId: nil,
                showPinButton: showPin,
                isPinned: isPinned,
                serviceType: service.serviceType
            )
            let rowView = AccessoryRowView(config: config)
            rowView.onStarToggled = { [weak self] in
                preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
                self?.rebuild()
            }
            rowView.onEyeToggled = { [weak self] in
                preferences.toggleHidden(serviceId: service.uniqueIdentifier)
                self?.rebuild()
            }
            rowView.onPinToggled = { [weak self] in
                preferences.togglePinned(serviceId: service.uniqueIdentifier)
                self?.rebuild()
            }
            return rowView
        }
    }

    private func createSceneRowView(row: Int) -> NSView {
        let scene = sceneItems[row]
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavourite(sceneId: scene.uniqueIdentifier)
        let isSceneHidden = preferences.isHidden(sceneId: scene.uniqueIdentifier)
        let isHidden = preferences.hideScenesSection
        let config = AccessoryRowConfig(
            name: scene.name,
            icon: SceneIconInference.icon(for: scene.name),
            isFavourite: isFav,
            isItemHidden: isSceneHidden,
            isSectionHidden: isHidden,
            showDragHandle: true,
            showEyeButton: true,
            itemId: nil
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onStarToggled = { [weak self] in
            preferences.toggleFavourite(sceneId: scene.uniqueIdentifier)
            self?.rebuild()
        }
        rowView.onEyeToggled = { [weak self] in
            preferences.toggleHidden(sceneId: scene.uniqueIdentifier)
            self?.rebuild()
        }
        return rowView
    }

    // MARK: - Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        if tableView === favouritesTableView {
            let item = favouriteItems[row]
            let pb = NSPasteboardItem()
            pb.setString(item.id, forType: .favouriteItem)
            return pb
        }
        if tableView === roomsTableView {
            // Only room headers are draggable
            if case .header(let room, _, _, _) = roomTableItems[row] {
                let pb = NSPasteboardItem()
                pb.setString(room.uniqueIdentifier, forType: .roomItem)
                return pb
            }
            return nil
        }
        if tableView === scenesTableView {
            let scene = sceneItems[row]
            let pb = NSPasteboardItem()
            pb.setString(scene.uniqueIdentifier, forType: .sceneItem)
            return pb
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard dropOperation == .above else { return [] }

        if tableView === roomsTableView {
            // Only allow dropping above header rows or at end
            if row < roomTableItems.count {
                if case .header = roomTableItems[row] {
                    return .move
                }
                // Find the next header row
                for i in row..<roomTableItems.count {
                    if case .header = roomTableItems[i] {
                        tableView.setDropRow(i, dropOperation: .above)
                        return .move
                    }
                }
                // Drop at end
                tableView.setDropRow(roomTableItems.count, dropOperation: .above)
                return .move
            }
            return .move
        }

        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let pb = items.first else {
            return false
        }

        if tableView === favouritesTableView {
            return acceptFavouriteDrop(pb: pb, row: row, tableView: tableView)
        }
        if tableView === roomsTableView {
            return acceptRoomDrop(pb: pb, row: row)
        }
        if tableView === scenesTableView {
            return acceptSceneDrop(pb: pb, row: row)
        }
        return false
    }

    private func acceptFavouriteDrop(pb: NSPasteboardItem, row: Int, tableView: NSTableView) -> Bool {
        guard let draggedId = pb.string(forType: .favouriteItem),
              let originalRow = favouriteItems.firstIndex(where: { $0.id == draggedId }) else {
            return false
        }

        var newRow = row
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveFavourite(from: originalRow, to: newRow)
        rebuildFavouritesList()

        tableView.beginUpdates()
        tableView.moveRow(at: originalRow, to: newRow)
        tableView.endUpdates()

        return true
    }

    private func acceptRoomDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedId = pb.string(forType: .roomItem) else {
            return false
        }
        guard let originalRoomIndex = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
            return false
        }

        // Determine target room index from the drop row
        var targetRoomIndex: Int
        if row >= roomTableItems.count {
            targetRoomIndex = orderedRooms.count - 1
        } else if case .header = roomTableItems[row] {
            var headerCount = 0
            for i in 0..<row {
                if case .header = roomTableItems[i] { headerCount += 1 }
            }
            targetRoomIndex = headerCount
        } else {
            targetRoomIndex = orderedRooms.count - 1
        }

        if originalRoomIndex < targetRoomIndex { targetRoomIndex -= 1 }
        if originalRoomIndex == targetRoomIndex { return false }

        PreferencesManager.shared.moveRoom(from: originalRoomIndex, to: targetRoomIndex)
        rebuildRoomData()
        roomsTableView?.reloadData()

        return true
    }

    private func acceptSceneDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedId = pb.string(forType: .sceneItem) else {
            return false
        }
        guard let originalRow = sceneItems.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
            return false
        }

        var newRow = row
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveScene(from: originalRow, to: newRow)
        rebuildSceneData()
        scenesTableView?.reloadData()

        return true
    }
}
