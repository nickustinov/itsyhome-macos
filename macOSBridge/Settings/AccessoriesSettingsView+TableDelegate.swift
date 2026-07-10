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
        if tableView === globalGroupsTableView {
            return createGlobalGroupRowView(row: row)
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView === roomsTableView, row < roomTableItems.count {
            switch roomTableItems[row] {
            case .separator, .groupSeparator, .divider, .sectionDivider:
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
        // Get the resolved icon based on item type
        let icon: NSImage?
        let serviceType: String?
        let itemType: IconPickerPopover.ItemType
        switch item.kind {
        case .scene(let scene):
            icon = IconResolver.icon(for: scene)
            serviceType = nil
            itemType = .scene
        case .service(let service):
            icon = IconResolver.icon(for: service)
            serviceType = service.serviceType
            itemType = .service
        case .group(let group):
            icon = IconResolver.icon(for: group)
            serviceType = nil
            itemType = .group
        }

        let config = AccessoryRowConfig(
            name: item.name,
            icon: icon,
            showDragHandle: true,
            isFavourite: true,
            showStarButton: true,
            itemId: item.id,
            serviceType: serviceType,
            isIconEditable: true
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
        rowView.onIconTapped = { [weak self, weak rowView] in
            guard let self = self, let rowView = rowView else { return }
            // Determine the actual item ID for icon storage
            let actualItemId: String
            switch item.kind {
            case .scene(let scene): actualItemId = scene.uniqueIdentifier
            case .service(let service): actualItemId = service.uniqueIdentifier
            case .group(let group): actualItemId = group.id
            }
            self.showIconPicker(
                for: actualItemId,
                serviceType: serviceType,
                itemType: itemType,
                relativeTo: rowView,
                iconView: rowView.iconView
            )
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
        case .accessory(let service, let roomHidden, _):
            return createAccessoryRow(service: service, roomHidden: roomHidden)
        case .separator:
            return createSeparatorRow()
        case .divider:
            return createSeparatorRow()
        case .scenesHeader(let isHidden, let isCollapsed, let sceneCount):
            return createScenesHeaderStrip(isHidden: isHidden, isCollapsed: isCollapsed, sceneCount: sceneCount)
        case .scene(let scene, let sectionHidden):
            return createSceneRowView(scene: scene, sectionHidden: sectionHidden)
        case .batteriesHeader(let isHidden, let deviceCount):
            return createBatteriesHeaderStrip(isHidden: isHidden, deviceCount: deviceCount)
        case .sectionDivider:
            return createSeparatorRow(indented: false)
        }
    }

    private func createSeparatorRow(indented: Bool = true) -> NSView {
        let container = NSView()
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        let indent = indented
            ? AccessoryRowLayout.indentWidth + AccessoryRowLayout.leftPadding
            : AccessoryRowLayout.leftPadding
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: indent),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AccessoryRowLayout.rightPadding),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func createSceneRowView(scene: SceneData, sectionHidden: Bool) -> NSView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavourite(sceneId: scene.uniqueIdentifier)
        let isSceneHidden = preferences.isHidden(sceneId: scene.uniqueIdentifier)
        let isHidden = sectionHidden
        let isPinned = preferences.isPinnedScene(sceneId: scene.uniqueIdentifier)
        let config = AccessoryRowConfig(
            name: scene.name,
            icon: IconResolver.icon(for: scene),
            showDragHandle: true,
            isFavourite: isFav,
            isItemHidden: isSceneHidden,
            isSectionHidden: isHidden,
            isPinned: isPinned,
            showStarButton: true,
            showEyeButton: true,
            showPinButton: true,
            itemId: scene.uniqueIdentifier,
            indentLevel: 1,
            isIconEditable: true
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
        rowView.onIconTapped = { [weak self, weak rowView] in
            guard let self = self, let rowView = rowView else { return }
            self.showIconPicker(
                for: scene.uniqueIdentifier,
                serviceType: nil,
                itemType: .scene,
                relativeTo: rowView,
                iconView: rowView.iconView
            )
        }
        return rowView
    }

    func createAccessoryRow(service: ServiceData, roomHidden: Bool, indentLevel: Int = 1, showDragHandle: Bool = true) -> AccessoryRowView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavourite(serviceId: service.uniqueIdentifier)
        let isServiceHidden = preferences.isHidden(serviceId: service.uniqueIdentifier)
        let isPinned = preferences.isPinned(serviceId: service.uniqueIdentifier)
        let config = AccessoryRowConfig(
            name: service.name,
            icon: IconResolver.icon(for: service),
            showDragHandle: showDragHandle,
            isFavourite: isFav,
            isItemHidden: isServiceHidden,
            isSectionHidden: roomHidden,
            isPinned: isPinned,
            showStarButton: true,
            showEyeButton: true,
            showPinButton: true,
            itemId: service.uniqueIdentifier,
            serviceType: service.serviceType,
            indentLevel: indentLevel,
            isIconEditable: true
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
        rowView.onIconTapped = { [weak self, weak rowView] in
            guard let self = self, let rowView = rowView else { return }
            self.showIconPicker(
                for: service.uniqueIdentifier,
                serviceType: service.serviceType,
                itemType: .service,
                relativeTo: rowView,
                iconView: rowView.iconView
            )
        }
        return rowView
    }

    private func createGlobalGroupRowView(row: Int) -> NSView {
        let group = globalGroups[row]
        let canDrag = globalGroups.count > 1
        return createGroupRowView(group: group, roomId: nil, row: row, showDragHandle: canDrag, reserveDragSpace: true)
    }

    private func createRoomGroupRowView(group: DeviceGroup, roomId: String?, row: Int) -> NSView {
        let roomGroupCount = roomId.flatMap { groupsByRoom[$0]?.count } ?? 0
        let canDrag = roomGroupCount > 1
        return createGroupRowView(group: group, roomId: roomId, row: row, showDragHandle: canDrag, reserveDragSpace: true, indentLevel: 1)
    }

    private func createGroupRowView(group: DeviceGroup, roomId: String?, row: Int, showDragHandle: Bool, reserveDragSpace: Bool = false, indentLevel: Int = 0) -> AccessoryRowView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavouriteGroup(groupId: group.id)
        let isPinned = preferences.isPinnedGroup(groupId: group.id)

        let config = AccessoryRowConfig(
            name: group.name,
            icon: IconResolver.icon(for: group),
            count: group.deviceIds.count,
            showDragHandle: showDragHandle,
            reserveDragHandleSpace: reserveDragSpace && !showDragHandle,
            isFavourite: isFav,
            isPinned: isPinned,
            showEditButton: true,
            showStarButton: true,
            showPinButton: true,
            itemId: group.id,
            rowTag: row,
            indentLevel: indentLevel,
            isIconEditable: true
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
        rowView.onIconTapped = { [weak self, weak rowView] in
            guard let self = self, let rowView = rowView else { return }
            self.showIconPicker(
                for: group.id,
                serviceType: nil,
                itemType: .group,
                relativeTo: rowView,
                iconView: rowView.iconView
            )
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
            switch roomTableItems[row] {
            case .header, .scenesHeader, .batteriesHeader, .sectionDivider:
                // Top-level sections and dividers all reorder through menuSectionOrder.
                let pb = NSPasteboardItem()
                pb.setString(roomTableItems[row].sectionToken ?? "", forType: .roomItem)
                return pb
            case .group(let group, let roomId):
                guard let roomId = roomId else { return nil }
                guard (groupsByRoom[roomId]?.count ?? 0) > 1 else { return nil }
                let pb = NSPasteboardItem()
                pb.setString("\(group.id)|\(roomId)", forType: .roomGroupItem)
                return pb
            case .accessory(let service, _, let roomId):
                let pb = NSPasteboardItem()
                pb.setString("\(roomId)|\(service.uniqueIdentifier)", forType: .roomAccessoryItem)
                return pb
            case .divider(let token, let roomId):
                let pb = NSPasteboardItem()
                pb.setString("\(roomId)|\(token)", forType: .roomAccessoryItem)
                return pb
            case .scene(let scene, _):
                let pb = NSPasteboardItem()
                pb.setString(scene.uniqueIdentifier, forType: .sceneItem)
                return pb
            default:
                return nil
            }
        }
        if tableView === globalGroupsTableView {
            // Only allow drag if there's more than one global group
            guard globalGroups.count > 1 else { return nil }
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
            // Accessory or user divider — drop must stay inside its source room.
            if info.draggingPasteboard.types?.contains(.roomAccessoryItem) == true {
                return .move
            }

            if info.draggingPasteboard.types?.contains(.roomGroupItem) == true {
                return .move
            }

            // Scene rows only move within the scenes section.
            if info.draggingPasteboard.types?.contains(.sceneItem) == true {
                let sceneRows = roomTableItems.indices.filter {
                    if case .scene = roomTableItems[$0] { return true }
                    return false
                }
                guard let first = sceneRows.first, let last = sceneRows.last else { return [] }
                let clamped = min(max(row, first), last + 1)
                if clamped != row {
                    tableView.setDropRow(clamped, dropOperation: .above)
                }
                return .move
            }

            // Section reordering (rooms, scenes, batteries): snap the drop to
            // the next section header row, or the end of the table.
            if row < roomTableItems.count {
                if roomTableItems[row].sectionToken != nil {
                    return .move
                }
                for i in row..<roomTableItems.count where roomTableItems[i].sectionToken != nil {
                    tableView.setDropRow(i, dropOperation: .above)
                    return .move
                }
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
            if pb.string(forType: .roomAccessoryItem) != nil {
                return acceptRoomAccessoryDrop(pb: pb, row: row)
            }
            if pb.string(forType: .roomGroupItem) != nil {
                return acceptRoomGroupDrop(pb: pb, row: row)
            }
            if pb.string(forType: .sceneItem) != nil {
                return acceptSceneDrop(pb: pb, row: row)
            }
            return acceptSectionDrop(pb: pb, row: row)
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

    /// Reorder a top-level section (room, scenes or batteries) in
    /// menuSectionOrder. Works on the displayed section rows; tokens that are
    /// currently not displayed (e.g. batteries with no battery devices) keep
    /// their relative position in the saved order.
    private func acceptSectionDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedToken = pb.string(forType: .roomItem), !draggedToken.isEmpty else { return false }

        let displayed = roomTableItems.compactMap { $0.sectionToken }
        guard let originalIndex = displayed.firstIndex(of: draggedToken) else { return false }

        // Target = number of section rows above the drop row.
        var targetIndex = 0
        for (i, item) in roomTableItems.enumerated() where i < row && item.sectionToken != nil {
            targetIndex += 1
        }
        if originalIndex < targetIndex { targetIndex -= 1 }
        if originalIndex == targetIndex { return false }

        // Translate the displayed move into the saved order: insert the dragged
        // token before the displayed token that ends up after it.
        let preferences = PreferencesManager.shared
        var others = displayed
        others.remove(at: originalIndex)

        var order = preferences.menuSectionOrder
        order.removeAll { $0 == draggedToken }
        if targetIndex < others.count, let insertAt = order.firstIndex(of: others[targetIndex]) {
            order.insert(draggedToken, at: insertAt)
        } else if let lastDisplayed = others.last, let lastAt = order.firstIndex(of: lastDisplayed) {
            order.insert(draggedToken, at: lastAt + 1)
        } else {
            order.append(draggedToken)
        }
        preferences.menuSectionOrder = order

        rebuildRoomData()
        roomsTableView?.reloadData()

        return true
    }

    private func acceptSceneDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedId = pb.string(forType: .sceneItem),
              let originalRow = sceneItems.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
            return false
        }

        // Target = number of scene rows above the drop row.
        var newRow = 0
        for (i, item) in roomTableItems.enumerated() where i < row {
            if case .scene = item { newRow += 1 }
        }
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveScene(from: originalRow, to: newRow)
        rebuildSceneData()
        rebuildRoomData()
        roomsTableView?.reloadData()

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

    private func acceptRoomAccessoryDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let payload = pb.string(forType: .roomAccessoryItem) else { return false }
        let parts = payload.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return false }

        let roomId = String(parts[0])
        let draggedToken = String(parts[1])

        // Resolve current order of accessories+dividers in this room from the
        // table items. This works whether or not a custom order is saved —
        // when none is saved, auto separators become real divider tokens,
        // and we persist the seeded order on first drop.
        var roomItemRows: [(rowIndex: Int, token: String)] = []
        var inRoom = false
        for (i, item) in roomTableItems.enumerated() {
            switch item {
            case .header(let room, _, _, _):
                if inRoom { return finishAccessoryDrop(roomId: roomId, draggedToken: draggedToken, roomItemRows: roomItemRows, dropRow: row) }
                inRoom = (room.uniqueIdentifier == roomId)
            case .accessory(let service, _, _) where inRoom:
                roomItemRows.append((i, service.uniqueIdentifier))
            case .divider(let token, _) where inRoom:
                roomItemRows.append((i, token))
            case .separator where inRoom:
                roomItemRows.append((i, "\(PreferencesManager.dividerPrefix)\(UUID().uuidString)"))
            default:
                break
            }
        }
        return finishAccessoryDrop(roomId: roomId, draggedToken: draggedToken, roomItemRows: roomItemRows, dropRow: row)
    }

    private func finishAccessoryDrop(roomId: String, draggedToken: String, roomItemRows: [(rowIndex: Int, token: String)], dropRow: Int) -> Bool {
        guard let originalIndex = roomItemRows.firstIndex(where: { $0.token == draggedToken }) else { return false }

        // Compute target index = number of items in this room whose tableRow < dropRow.
        var targetIndex = 0
        for entry in roomItemRows where entry.rowIndex < dropRow {
            targetIndex += 1
        }

        if originalIndex < targetIndex { targetIndex -= 1 }
        if originalIndex == targetIndex { return false }

        var order = roomItemRows.map(\.token)
        let item = order.remove(at: originalIndex)
        order.insert(item, at: targetIndex)

        PreferencesManager.shared.setAccessoryOrder(order, forRoom: roomId)
        rebuildRoomData()
        roomsTableView?.reloadData()
        return true
    }
}
