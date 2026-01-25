//
//  AccessoriesSettingsView.swift
//  macOSBridge
//
//  Accessories settings tab with favourites and visibility toggles
//

import AppKit

// MARK: - Pasteboard types

extension NSPasteboard.PasteboardType {
    static let favouriteItem = NSPasteboard.PasteboardType("com.itsyhome.favouriteItem")
    static let roomItem = NSPasteboard.PasteboardType("com.itsyhome.roomItem")
    static let sceneItem = NSPasteboard.PasteboardType("com.itsyhome.sceneItem")
}

// MARK: - Data models

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

enum RoomTableItem {
    case header(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int)
    case accessory(service: ServiceData, roomHidden: Bool)

    var isHeader: Bool {
        if case .header = self { return true }
        return false
    }
}

// MARK: - Main view

class AccessoriesSettingsView: NSView {

    private let stackView = NSStackView()
    private var menuData: MenuData?
    private var needsRebuild = false

    // Tables
    var favouritesTableView: NSTableView?
    var roomsTableView: RoomsTableView?
    var scenesTableView: NSTableView?

    // Data
    var favouriteItems: [FavouriteItem] = []
    var roomTableItems: [RoomTableItem] = []
    var sceneItems: [SceneData] = []
    var orderedRooms: [RoomData] = []
    var expandedSections: Set<String> = []
    var servicesByRoom: [String: [ServiceData]] = [:]
    var noRoomServices: [ServiceData] = []

    let typeOrder = [ServiceTypes.lightbulb, ServiceTypes.switch, ServiceTypes.outlet, ServiceTypes.fan,
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

    func rebuild() {
        needsRebuild = true
        needsLayout = true
    }

    // MARK: - Data building

    func rebuildFavouritesList() {
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

    func rebuildRoomData() {
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

    func rebuildSceneData() {
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

    // MARK: - Content building

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
            buildOtherSection()
        }
    }

    private func buildOtherSection() {
        let preferences = PreferencesManager.shared
        let L = AccessoryRowLayout.self
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
                let row = createAccessoryRow(service: service, roomHidden: false, pinnableTypes: pinnableTypes)
                addView(row, height: L.rowHeight)
            }
        }
        addSpacer(height: 12)
    }

    // MARK: - Layout helpers

    func addHeader(title: String) {
        let header = AccessorySectionHeader(title: title)
        addView(header, height: 32)
    }

    func addView(_ view: NSView, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    // MARK: - Room index helpers

    func roomIndex(forTableRow row: Int) -> Int? {
        var headerCount = 0
        for i in 0...row {
            if case .header = roomTableItems[i] {
                if i == row { return headerCount }
                headerCount += 1
            }
        }
        return nil
    }

    func tableRow(forRoomIndex roomIndex: Int) -> Int? {
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
