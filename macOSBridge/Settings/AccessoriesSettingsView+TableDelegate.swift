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
        if tableView === roomsTableView { return roomTableItems.count }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === roomsTableView {
            return createRoomTableRowView(row: row)
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

    private func createFavouriteRowView(item: FavouriteItem) -> NSView {
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
            indentLevel: 1,
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
        case .favouritesHeader(let isCollapsed, let count):
            return createFavouritesHeaderStrip(isCollapsed: isCollapsed, count: count)
        case .favourite(let item):
            return createFavouriteRowView(item: item)
        case .groupsHeader(let isCollapsed, let count):
            return createGroupsHeaderStrip(isCollapsed: isCollapsed, count: count)
        case .globalGroup(let group):
            return createGlobalGroupRowView(group: group)
        case .scenesHeader(let isHidden, let isCollapsed, let sceneCount):
            return createScenesHeaderStrip(isHidden: isHidden, isCollapsed: isCollapsed, sceneCount: sceneCount)
        case .scene(let scene, let sectionHidden):
            return createSceneRowView(scene: scene, sectionHidden: sectionHidden)
        case .batteriesHeader(let isHidden, let deviceCount):
            return createBatteriesHeaderStrip(isHidden: isHidden, deviceCount: deviceCount)
        case .otherHeader(let isHidden, let isCollapsed, let count):
            return createOtherHeaderStrip(isHidden: isHidden, isCollapsed: isCollapsed, count: count)
        case .otherAccessory(let service, let sectionHidden):
            return createAccessoryRow(service: service, roomHidden: sectionHidden, showDragHandle: false)
        case .groupDevice(let service, let groupId):
            return createGroupDeviceRow(service: service, groupId: groupId)
        case .sectionDivider:
            return createSeparatorRow(indented: false)
        }
    }

    /// Row for a device inside an expanded group: draggable to reorder the
    /// group's deviceIds (the order its submenu and pinned menu use).
    private func createGroupDeviceRow(service: ServiceData, groupId: String) -> NSView {
        let config = AccessoryRowConfig(
            name: service.name,
            icon: IconResolver.icon(for: service),
            showDragHandle: true,
            itemId: service.uniqueIdentifier,
            serviceType: service.serviceType,
            indentLevel: 2
        )
        return AccessoryRowView(config: config)
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

    private func createGlobalGroupRowView(group: DeviceGroup) -> NSView {
        createGroupRowView(group: group, indentLevel: 1)
    }

    private func createRoomGroupRowView(group: DeviceGroup, roomId: String?, row: Int) -> NSView {
        createGroupRowView(group: group, indentLevel: 1)
    }

    private func createGroupRowView(group: DeviceGroup, indentLevel: Int) -> AccessoryRowView {
        let preferences = PreferencesManager.shared
        let isFav = preferences.isFavouriteGroup(groupId: group.id)
        let isPinned = preferences.isPinnedGroup(groupId: group.id)

        let config = AccessoryRowConfig(
            name: group.name,
            icon: IconResolver.icon(for: group),
            count: group.deviceIds.count,
            showDragHandle: true,
            showChevron: !group.deviceIds.isEmpty,
            isCollapsed: !expandedSections.contains(group.id),
            isFavourite: isFav,
            isPinned: isPinned,
            showEditButton: true,
            showStarButton: true,
            showPinButton: true,
            itemId: group.id,
            indentLevel: indentLevel,
            isIconEditable: true
        )

        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            guard let self else { return }
            if self.expandedSections.contains(group.id) {
                self.expandedSections.remove(group.id)
            } else {
                self.expandedSections.insert(group.id)
            }
            self.updateRoomsSection()
        }
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
        guard tableView === roomsTableView else { return nil }
        switch roomTableItems[row] {
        case .header, .favouritesHeader, .groupsHeader, .scenesHeader, .batteriesHeader, .otherHeader, .sectionDivider:
            // Top-level sections and dividers all reorder through menuLayout.
            let pb = NSPasteboardItem()
            pb.setString(roomTableItems[row].sectionToken ?? "", forType: .roomItem)
            return pb
        case .group(let group, let roomId):
            // Room groups reorder within the room's item order, like accessories.
            guard let roomId = roomId else { return nil }
            let pb = NSPasteboardItem()
            pb.setString("\(roomId)|\(group.id)", forType: .roomAccessoryItem)
            return pb
        case .accessory(let service, _, let roomId):
            let pb = NSPasteboardItem()
            pb.setString("\(roomId)|\(service.uniqueIdentifier)", forType: .roomAccessoryItem)
            return pb
        case .divider(let token, let roomId):
            let pb = NSPasteboardItem()
            pb.setString("\(roomId)|\(token)", forType: .roomAccessoryItem)
            return pb
        case .favourite(let item):
            let pb = NSPasteboardItem()
            pb.setString(item.id, forType: .favouriteItem)
            return pb
        case .globalGroup(let group):
            let pb = NSPasteboardItem()
            pb.setString(group.id, forType: .globalGroupItem)
            return pb
        case .scene(let scene, _):
            let pb = NSPasteboardItem()
            pb.setString(scene.uniqueIdentifier, forType: .sceneItem)
            return pb
        case .groupDevice(let service, let groupId):
            let pb = NSPasteboardItem()
            pb.setString("\(groupId)|\(service.uniqueIdentifier)", forType: .groupDeviceItem)
            return pb
        default:
            return nil
        }
    }

    /// Row indices of the rows a within-section drag may land between,
    /// clamping the proposed drop row into that range.
    private func clampDrop(_ tableView: NSTableView, row: Int, toRows rows: [Int]) -> NSDragOperation {
        guard let first = rows.first, let last = rows.last else { return [] }
        let clamped = min(max(row, first), last + 1)
        if clamped != row {
            tableView.setDropRow(clamped, dropOperation: .above)
        }
        return .move
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard dropOperation == .above else { return [] }

        guard tableView === roomsTableView else { return .move }

        // Accessory, user divider or room group — reorders within its room.
        if info.draggingPasteboard.types?.contains(.roomAccessoryItem) == true {
            return .move
        }

        // Rows that only move within their own section.
        if info.draggingPasteboard.types?.contains(.sceneItem) == true {
            return clampDrop(tableView, row: row, toRows: roomTableItems.indices.filter {
                if case .scene = roomTableItems[$0] { return true }
                return false
            })
        }
        if info.draggingPasteboard.types?.contains(.favouriteItem) == true {
            return clampDrop(tableView, row: row, toRows: roomTableItems.indices.filter {
                if case .favourite = roomTableItems[$0] { return true }
                return false
            })
        }
        if info.draggingPasteboard.types?.contains(.globalGroupItem) == true {
            return clampDrop(tableView, row: row, toRows: roomTableItems.indices.filter {
                if case .globalGroup = roomTableItems[$0] { return true }
                return false
            })
        }
        if info.draggingPasteboard.types?.contains(.groupDeviceItem) == true {
            // Devices reorder inside their own group only.
            guard let payload = info.draggingPasteboard.string(forType: .groupDeviceItem),
                  let groupId = payload.split(separator: "|", maxSplits: 1).first.map(String.init) else { return [] }
            return clampDrop(tableView, row: row, toRows: roomTableItems.indices.filter {
                if case .groupDevice(_, let gid) = roomTableItems[$0], gid == groupId { return true }
                return false
            })
        }

        // Section reordering: snap the drop to the next section row, or the
        // end of the table.
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

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let pb = items.first else {
            return false
        }

        guard tableView === roomsTableView else { return false }
        if pb.string(forType: .roomAccessoryItem) != nil {
            return acceptRoomAccessoryDrop(pb: pb, row: row)
        }
        if pb.string(forType: .sceneItem) != nil {
            return acceptSceneDrop(pb: pb, row: row)
        }
        if pb.string(forType: .favouriteItem) != nil {
            return acceptFavouriteDrop(pb: pb, row: row)
        }
        if pb.string(forType: .globalGroupItem) != nil {
            return acceptGlobalGroupDrop(pb: pb, row: row)
        }
        if pb.string(forType: .groupDeviceItem) != nil {
            return acceptGroupDeviceDrop(pb: pb, row: row)
        }
        return acceptSectionDrop(pb: pb, row: row)
    }

    /// Number of rows matching `matches` above the drop row – the target
    /// index for a within-section reorder.
    private func sectionTargetIndex(dropRow: Int, matches: (RoomTableItem) -> Bool) -> Int {
        var target = 0
        for (i, item) in roomTableItems.enumerated() where i < dropRow && matches(item) {
            target += 1
        }
        return target
    }

    private func acceptFavouriteDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedId = pb.string(forType: .favouriteItem),
              let originalRow = favouriteItems.firstIndex(where: { $0.id == draggedId }) else {
            return false
        }

        var newRow = sectionTargetIndex(dropRow: row) { if case .favourite = $0 { return true }; return false }
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveFavourite(from: originalRow, to: newRow)
        rebuildFavouritesList()
        rebuildRoomData()
        roomsTableView?.reloadData()

        return true
    }

    private func acceptGroupDeviceDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let payload = pb.string(forType: .groupDeviceItem) else { return false }
        let parts = payload.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return false }
        let groupId = String(parts[0])
        let serviceId = String(parts[1])

        let preferences = PreferencesManager.shared
        guard var group = preferences.deviceGroups.first(where: { $0.id == groupId }),
              let originalIndex = group.deviceIds.firstIndex(of: serviceId) else {
            return false
        }

        var targetIndex = sectionTargetIndex(dropRow: row) {
            if case .groupDevice(_, let gid) = $0, gid == groupId { return true }
            return false
        }
        if originalIndex < targetIndex { targetIndex -= 1 }
        if originalIndex == targetIndex { return false }
        guard targetIndex >= 0, targetIndex < group.deviceIds.count else { return false }

        let id = group.deviceIds.remove(at: originalIndex)
        group.deviceIds.insert(id, at: targetIndex)
        preferences.updateDeviceGroup(group)

        rebuildGroupData()
        rebuildRoomData()
        roomsTableView?.reloadData()

        return true
    }

    /// Reorder a top-level section (room, scenes or batteries) in
    /// menuLayout. Works on the displayed section rows; tokens that are
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

        var order = preferences.menuLayout
        order.removeAll { $0 == draggedToken }
        if targetIndex < others.count, let insertAt = order.firstIndex(of: others[targetIndex]) {
            order.insert(draggedToken, at: insertAt)
        } else if let lastDisplayed = others.last, let lastAt = order.firstIndex(of: lastDisplayed) {
            order.insert(draggedToken, at: lastAt + 1)
        } else {
            order.append(draggedToken)
        }
        preferences.menuLayout = order

        rebuildRoomData()
        roomsTableView?.reloadData()

        return true
    }

    private func acceptSceneDrop(pb: NSPasteboardItem, row: Int) -> Bool {
        guard let draggedId = pb.string(forType: .sceneItem),
              let originalRow = sceneItems.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
            return false
        }

        var newRow = sectionTargetIndex(dropRow: row) { if case .scene = $0 { return true }; return false }
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

        var newRow = sectionTargetIndex(dropRow: row) { if case .globalGroup = $0 { return true }; return false }
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        PreferencesManager.shared.moveGlobalGroup(from: originalRow, to: newRow)
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

        // Resolve the current order of the room's groups, accessories and
        // dividers from the table items. This works whether or not a custom
        // order is saved — when none is saved, auto separators (including the
        // one under the groups block) become real divider tokens, and we
        // persist the seeded order on first drop.
        var roomItemRows: [(rowIndex: Int, token: String)] = []
        var inRoom = false
        for (i, item) in roomTableItems.enumerated() {
            switch item {
            case .header(let room, _, _, _):
                if inRoom { return finishAccessoryDrop(roomId: roomId, draggedToken: draggedToken, roomItemRows: roomItemRows, dropRow: row) }
                inRoom = (room.uniqueIdentifier == roomId)
            case .group(let group, _) where inRoom:
                roomItemRows.append((i, group.id))
            case .accessory(let service, _, _) where inRoom:
                roomItemRows.append((i, service.uniqueIdentifier))
            case .divider(let token, _) where inRoom:
                roomItemRows.append((i, token))
            case .separator, .groupSeparator:
                if inRoom {
                    roomItemRows.append((i, PreferencesManager.newDividerToken()))
                }
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
