//
//  AccessoriesSettingsView+TableDelegate.swift
//  macOSBridge
//
//  Table view delegate and data source for accessories settings
//

import AppKit

// MARK: - Table delegate

extension AccessoriesSettingsView: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === favouritesTableView { return favouriteItems.count }
        if tableView === roomsTableView { return roomTableItems.count }
        if tableView === scenesTableView { return sceneItems.count }
        if tableView === globalGroupsTableView { return globalGroups.count }
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
        if tableView === globalGroupsTableView {
            return createGlobalGroupRowView(row: row)
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView === roomsTableView, row < roomTableItems.count {
            switch roomTableItems[row] {
            case .separator, .groupSeparator:
                return 12
            default:
                break
            }
        }
        return AccessoryRowLayout.rowHeight
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
            showDragHandle: true,
            isFavourite: true,
            showStarButton: true,
            itemId: item.id
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onStarToggled = { [weak self] in
            let preferences = PreferencesManager.shared
            switch item.kind {
            case .scene(let scene): preferences.toggleFavourite(sceneId: scene.uniqueIdentifier)
            case .service(let service): preferences.toggleFavourite(serviceId: service.uniqueIdentifier)
            case .group(let group): preferences.toggleFavouriteGroup(groupId: group.id)
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
        case .group(let group, let roomId):
            return createRoomGroupRowView(group: group, roomId: roomId, row: row)
        case .groupSeparator:
            return createSeparatorRow()
        case .accessory(let service, let roomHidden):
            return createAccessoryRow(service: service, roomHidden: roomHidden)
        case .separator:
            return createSeparatorRow()
        }
    }

    private func createSeparatorRow() -> NSView {
        let container = NSView()
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        let indent = AccessoryRowLayout.indentWidth + AccessoryRowLayout.leftPadding
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: indent),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AccessoryRowLayout.rightPadding),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func createSceneRowView(row: Int) -> NSView {
        let scene = sceneItems[row]
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavourite(sceneId: scene.uniqueIdentifier)
        let isSceneHidden = preferences.isHidden(sceneId: scene.uniqueIdentifier)
        let isHidden = preferences.hideScenesSection
        let isPinned = preferences.isPinnedScene(sceneId: scene.uniqueIdentifier)
        let config = AccessoryRowConfig(
            name: scene.name,
            icon: SceneIconInference.icon(for: scene.name),
            showDragHandle: true,
            isFavourite: isFav,
            isItemHidden: isSceneHidden,
            isSectionHidden: isHidden,
            isPinned: isPinned,
            showStarButton: true,
            showEyeButton: true,
            showPinButton: true,
            indentLevel: 1
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
        rowView.onPinToggled = { [weak self] in
            preferences.togglePinnedScene(sceneId: scene.uniqueIdentifier)
            self?.rebuild()
        }
        return rowView
    }

    func createAccessoryRow(service: ServiceData, roomHidden: Bool, indentLevel: Int = 1) -> AccessoryRowView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
        let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
        let isPinned = preferences.isPinned(serviceId: service.uniqueIdentifier)
        let config = AccessoryRowConfig(
            name: service.name,
            icon: IconMapping.iconForServiceType(service.serviceType),
            isFavourite: isFav,
            isItemHidden: isServiceHidden,
            isSectionHidden: roomHidden,
            isPinned: isPinned,
            showStarButton: true,
            showEyeButton: true,
            showPinButton: true,
            serviceType: service.serviceType,
            indentLevel: indentLevel
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

    private func createGlobalGroupRowView(row: Int) -> NSView {
        let group = globalGroups[row]
        return createGroupRowView(group: group, roomId: nil, row: row, showDragHandle: true)
    }

    private func createRoomGroupRowView(group: DeviceGroup, roomId: String?, row: Int) -> NSView {
        return createGroupRowView(group: group, roomId: roomId, row: row, showDragHandle: true, indentLevel: 1)
    }

    private func createGroupRowView(group: DeviceGroup, roomId: String?, row: Int, showDragHandle: Bool, indentLevel: Int = 0) -> AccessoryRowView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavouriteGroup(groupId: group.id)
        let isPinned = preferences.isPinnedGroup(groupId: group.id)
        let isPro = ProStatusCache.shared.isPro

        let config = AccessoryRowConfig(
            name: group.name,
            icon: NSImage(systemSymbolName: group.icon, accessibilityDescription: group.name),
            count: group.deviceIds.count,
            showDragHandle: showDragHandle && isPro,
            isFavourite: isFav,
            isPinned: isPinned,
            showEditButton: isPro,
            showStarButton: true,
            showPinButton: true,
            rowTag: row,
            indentLevel: indentLevel
        )

        let rowView = AccessoryRowView(config: config)
        rowView.onEditTapped = { [weak self] in
            self?.showGroupEditor(group: group)
        }
        rowView.onStarToggled = { [weak self] in
            preferences.toggleFavouriteGroup(groupId: group.id)
            self?.rebuild()
        }
        rowView.onPinToggled = { [weak self] in
            preferences.togglePinnedGroup(groupId: group.id)
            self?.rebuild()
        }
        return rowView
    }

    // MARK: - Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        // Disable drag for non-pro users on group tables
        let isPro = ProStatusCache.shared.isPro

        if tableView === favouritesTableView {
            let item = favouriteItems[row]
            let pb = NSPasteboardItem()
            pb.setString(item.id, forType: .favouriteItem)
            return pb
        }
        if tableView === roomsTableView {
            // Only room headers and groups are draggable
            switch roomTableItems[row] {
            case .header(let room, _, _, _):
                let pb = NSPasteboardItem()
                pb.setString(room.uniqueIdentifier, forType: .roomItem)
                return pb
            case .group(let group, let roomId):
                guard isPro, let roomId = roomId else { return nil }
                let pb = NSPasteboardItem()
                pb.setString("\(group.id)|\(roomId)", forType: .roomGroupItem)
                return pb
            default:
                return nil
            }
        }
        if tableView === scenesTableView {
            let scene = sceneItems[row]
            let pb = NSPasteboardItem()
            pb.setString(scene.uniqueIdentifier, forType: .sceneItem)
            return pb
        }
        if tableView === globalGroupsTableView {
            guard isPro else { return nil }
            let group = globalGroups[row]
            let pb = NSPasteboardItem()
            pb.setString(group.id, forType: .globalGroupItem)
            return pb
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard dropOperation == .above else { return [] }

        if tableView === roomsTableView {
            // Check what's being dragged
            if info.draggingPasteboard.types?.contains(.roomGroupItem) == true {
                // Room groups can only be dropped among other groups in the same room
                // For simplicity, just allow the drop and handle validation in acceptDrop
                return .move
            }

            // Only allow dropping above header rows or at end (for room reordering)
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

        if tableView === globalGroupsTableView {
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
            // Check if it's a room group drop first
            if pb.string(forType: .roomGroupItem) != nil {
                return acceptRoomGroupDrop(pb: pb, row: row)
            }
            return acceptRoomDrop(pb: pb, row: row)
        }
        if tableView === scenesTableView {
            return acceptSceneDrop(pb: pb, row: row)
        }
        if tableView === globalGroupsTableView {
            return acceptGlobalGroupDrop(pb: pb, row: row)
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
        guard let draggedId = pb.string(forType: .roomItem),
              let originalRoomIndex = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
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
        guard let draggedId = pb.string(forType: .sceneItem),
              let originalRow = sceneItems.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
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

    private func acceptGlobalGroupDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedId = pb.string(forType: .globalGroupItem),
              let originalRow = globalGroups.firstIndex(where: { $0.id == draggedId }) else {
            return false
        }

        var newRow = row
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveGlobalGroup(from: originalRow, to: newRow)
        rebuildGroupData()
        globalGroupsTableView?.reloadData()

        return true
    }

    private func acceptRoomGroupDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let data = pb.string(forType: .roomGroupItem) else { return false }
        let parts = data.split(separator: "|")
        guard parts.count == 2 else { return false }

        let groupId = String(parts[0])
        let roomId = String(parts[1])

        guard let roomGroups = groupsByRoom[roomId],
              let originalIndex = roomGroups.firstIndex(where: { $0.id == groupId }) else {
            return false
        }

        // Find the target index within the room's groups
        // Count how many group rows are before the drop row in this room
        var targetIndex = 0
        var foundRoom = false
        for (i, item) in roomTableItems.enumerated() {
            if case .header(let room, _, _, _) = item, room.uniqueIdentifier == roomId {
                foundRoom = true
                continue
            }
            if foundRoom {
                if case .group = item {
                    if i < row {
                        targetIndex += 1
                    }
                } else if case .header = item {
                    // Hit next room header, stop
                    break
                } else if case .groupSeparator = item {
                    // Dropped after all groups
                    break
                }
            }
        }

        if originalIndex < targetIndex { targetIndex -= 1 }
        if originalIndex == targetIndex { return false }

        PreferencesManager.shared.moveGroupInRoom(roomId, from: originalIndex, to: targetIndex)
        rebuildGroupData()
        rebuildRoomData()
        roomsTableView?.reloadData()

        return true
    }
}
