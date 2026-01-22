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
}

// MARK: - Main view

class AccessoriesSettingsView: NSView {

    private let stackView = NSStackView()
    private var menuData: MenuData?
    private var needsRebuild = false

    private var favouritesTableView: NSTableView?
    private var favouriteItems: [FavouriteItem] = []

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

    // MARK: - Build content

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

    private func rebuildContent() {
        rebuildFavouritesList()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        favouritesTableView = nil

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

        let excludedTypes: Set<String> = [ServiceTypes.temperatureSensor, ServiceTypes.humiditySensor]
        let typeOrder = [ServiceTypes.lightbulb, ServiceTypes.switch, ServiceTypes.outlet, ServiceTypes.fan,
                         ServiceTypes.heaterCooler, ServiceTypes.thermostat, ServiceTypes.windowCovering,
                         ServiceTypes.lock, ServiceTypes.garageDoorOpener]

        var servicesByRoom: [String: [ServiceData]] = [:]
        var noRoomServices: [ServiceData] = []

        for accessory in data.accessories {
            for service in accessory.services where !excludedTypes.contains(service.serviceType) {
                if let roomId = service.roomIdentifier {
                    servicesByRoom[roomId, default: []].append(service)
                } else {
                    noRoomServices.append(service)
                }
            }
        }

        // Favourites section
        if !favouriteItems.isEmpty {
            addHeader(title: "Favourites")
            addSpacer(height: 4)

            let tableHeight = CGFloat(favouriteItems.count) * L.rowHeight
            let tableContainer = createFavouritesTable(height: tableHeight)
            addView(tableContainer, height: tableHeight)
            addSpacer(height: 16)
        }

        // Scenes section
        if !data.scenes.isEmpty {
            let isHidden = preferences.hideScenesSection
            let header = AccessorySectionHeader(title: "Scenes", isItemHidden: isHidden, showEyeButton: true)
            header.onVisibilityToggled = { [weak self] in
                preferences.hideScenesSection.toggle()
                self?.rebuild()
            }
            addView(header, height: 32)

            for scene in data.scenes {
                let isFav = preferences.isFavourite(sceneId: scene.uniqueIdentifier)
                let isSceneHidden = preferences.isHidden(sceneId: scene.uniqueIdentifier)
                let config = AccessoryRowConfig(
                    name: scene.name,
                    icon: SceneIconInference.icon(for: scene.name),
                    isFavourite: isFav,
                    isItemHidden: isSceneHidden,
                    isSectionHidden: isHidden,
                    showDragHandle: false,
                    showEyeButton: true,
                    itemId: nil
                )
                let row = AccessoryRowView(config: config)
                row.onStarToggled = { [weak self] in
                    preferences.toggleFavourite(sceneId: scene.uniqueIdentifier)
                    self?.rebuild()
                }
                row.onEyeToggled = { [weak self] in
                    preferences.toggleHidden(sceneId: scene.uniqueIdentifier)
                    self?.rebuild()
                }
                addView(row, height: L.rowHeight)
            }
            addSpacer(height: 12)
        }

        // Room sections
        for room in data.rooms {
            guard let services = servicesByRoom[room.uniqueIdentifier], !services.isEmpty else { continue }

            let roomId = room.uniqueIdentifier
            let isRoomHidden = preferences.isHidden(roomId: roomId)

            let header = AccessorySectionHeader(title: room.name, isItemHidden: isRoomHidden, showEyeButton: true)
            header.onVisibilityToggled = { [weak self] in
                preferences.toggleHidden(roomId: roomId)
                self?.rebuild()
            }
            addView(header, height: 32)

            let sorted = services.sorted { s1, s2 in
                let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                return i1 != i2 ? i1 < i2 : s1.name < s2.name
            }

            for service in sorted {
                let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
                let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
                let config = AccessoryRowConfig(
                    name: service.name,
                    icon: IconMapping.iconForServiceType(service.serviceType),
                    isFavourite: isFav,
                    isItemHidden: isServiceHidden,
                    isSectionHidden: isRoomHidden,
                    showDragHandle: false,
                    showEyeButton: true,
                    itemId: nil
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
                addView(row, height: L.rowHeight)
            }
            addSpacer(height: 12)
        }

        // Other section
        if !noRoomServices.isEmpty {
            addHeader(title: "Other")

            let sorted = noRoomServices.sorted { s1, s2 in
                let i1 = typeOrder.firstIndex(of: s1.serviceType) ?? Int.max
                let i2 = typeOrder.firstIndex(of: s2.serviceType) ?? Int.max
                return i1 != i2 ? i1 < i2 : s1.name < s2.name
            }

            for service in sorted {
                let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
                let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
                let config = AccessoryRowConfig(
                    name: service.name,
                    icon: IconMapping.iconForServiceType(service.serviceType),
                    isFavourite: isFav,
                    isItemHidden: isServiceHidden,
                    isSectionHidden: false,
                    showDragHandle: false,
                    showEyeButton: true,
                    itemId: nil
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
                addView(row, height: L.rowHeight)
            }
            addSpacer(height: 12)
        }
    }

    private func rebuild() {
        needsRebuild = true
        needsLayout = true
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
        tableView.delegate = self
        tableView.dataSource = self
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

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        self.favouritesTableView = tableView

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
}

// MARK: - Table delegate

extension AccessoriesSettingsView: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        favouriteItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        AccessoryRowLayout.rowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isGroupRowStyle = false
        return rowView
    }

    // Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = favouriteItems[row]
        let pb = NSPasteboardItem()
        pb.setString(item.id, forType: .favouriteItem)
        return pb
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let pb = items.first,
              let draggedId = pb.string(forType: .favouriteItem),
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
}
