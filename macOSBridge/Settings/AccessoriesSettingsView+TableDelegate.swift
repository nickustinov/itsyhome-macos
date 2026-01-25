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
            let pinnableTypes: Set<String> = [ServiceTypes.thermostat, ServiceTypes.heaterCooler]
            return createAccessoryRow(service: service, roomHidden: roomHidden, pinnableTypes: pinnableTypes)
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

    func createAccessoryRow(service: ServiceData, roomHidden: Bool, pinnableTypes: Set<String>) -> AccessoryRowView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
        let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
        let isPinned = preferences.isPinned(serviceId: service.uniqueIdentifier)
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
}
