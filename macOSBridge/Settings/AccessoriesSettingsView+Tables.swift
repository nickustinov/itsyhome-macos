//
//  AccessoriesSettingsView+Tables.swift
//  macOSBridge
//
//  Header strips and toggle actions for accessories settings
//

import AppKit

// MARK: - Icon picker

extension AccessoriesSettingsView: IconPickerPopoverDelegate {

    func showIconPicker(for itemId: String, serviceType: String?, itemType: IconPickerPopover.ItemType, relativeTo view: NSView, iconView: NSView? = nil) {
        // Icon customization is a PRO feature
        guard ProStatusCache.shared.isPro else {
            showProUpgradeAlert()
            return
        }

        let picker = IconPickerPopover(itemId: itemId, serviceType: serviceType, itemType: itemType)
        picker.delegate = self

        let popover = NSPopover()
        popover.contentViewController = picker
        popover.behavior = .transient

        // Show relative to icon if provided, otherwise relative to the row
        let targetView = iconView ?? view
        popover.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .maxX)
    }

    private func showProUpgradeAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.pro_required.icons_title", defaultValue: "Custom icons require Itsyhome Pro", bundle: .macOSBridge)
        alert.informativeText = String(localized: "alert.pro_required.icons_message", defaultValue: "Upgrade to Pro to customize icons for your accessories, scenes, groups, and rooms.", bundle: .macOSBridge)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "common.get_pro", defaultValue: "Get Pro", bundle: .macOSBridge))
        alert.addButton(withTitle: String(localized: "common.not_now", defaultValue: "Not now", bundle: .macOSBridge))

        if alert.runModal() == .alertFirstButtonReturn {
            // Navigate to General section to show Pro purchase options
            NotificationCenter.default.post(name: SettingsView.navigateToSectionNotification, object: "General")
        }
    }

    func iconPicker(_ picker: IconPickerPopover, didSelectIcon iconName: String?) {
        // Rebuild to reflect the icon change
        rebuild()
    }
}

// MARK: - Header strips using AccessoryRowView

extension AccessoriesSettingsView {

    func createScenesHeaderStrip(isHidden: Bool, isCollapsed: Bool, sceneCount: Int) -> NSView {
        let isPinned = PreferencesManager.shared.isPinnedScenesSection
        let config = AccessoryRowConfig(
            name: String(localized: "menu.scenes", defaultValue: "Scenes", bundle: .macOSBridge),
            icon: PhosphorIcon.regular("sparkle"),
            count: sceneCount,
            reserveDragHandleSpace: true,
            showChevron: true,
            isCollapsed: isCollapsed,
            isItemHidden: isHidden,
            isPinned: isPinned,
            showEyeButton: true,
            showPinButton: true,
            isSectionHeader: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.scenesChevronTapped()
        }
        rowView.onEyeToggled = { [weak self] in
            self?.scenesEyeTapped()
        }
        rowView.onPinToggled = { [weak self] in
            PreferencesManager.shared.togglePinnedScenesSection()
            self?.updateScenesSection()
        }
        return rowView
    }

    func createOtherHeaderStrip(isHidden: Bool, isCollapsed: Bool) -> NSView {
        let config = AccessoryRowConfig(
            name: String(localized: "menu.other", defaultValue: "Other", bundle: .macOSBridge),
            showChevron: true,
            isCollapsed: isCollapsed,
            isItemHidden: isHidden,
            showEyeButton: true,
            isSectionHeader: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.otherChevronTapped()
        }
        rowView.onEyeToggled = { [weak self] in
            self?.otherEyeTapped()
        }
        return rowView
    }

    func createRoomHeaderView(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int) -> NSView {
        let preferences = PreferencesManager.shared
        let isPinned = preferences.isPinnedRoom(roomId: room.uniqueIdentifier)
        let roomIndex = orderedRooms.firstIndex(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) ?? 0

        let config = AccessoryRowConfig(
            name: room.name,
            icon: IconResolver.icon(forRoomId: room.uniqueIdentifier, roomName: room.name),
            count: serviceCount,
            showDragHandle: true,
            showChevron: true,
            isCollapsed: isCollapsed,
            isItemHidden: isHidden,
            isPinned: isPinned,
            showEyeButton: true,
            showPinButton: true,
            rowTag: roomIndex,
            isSectionHeader: true,
            isIconEditable: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.roomChevronToggled(roomIndex: roomIndex)
        }
        rowView.onEyeToggled = { [weak self] in
            self?.roomEyeToggled(roomIndex: roomIndex)
        }
        rowView.onPinToggled = { [weak self] in
            self?.roomPinToggled(roomIndex: roomIndex)
        }
        rowView.onIconTapped = { [weak self, weak rowView] in
            guard let self = self, let rowView = rowView else { return }
            self.showIconPicker(
                for: room.uniqueIdentifier,
                serviceType: nil,
                itemType: .room,
                relativeTo: rowView,
                iconView: rowView.iconView
            )
        }
        return rowView
    }

    // MARK: - Toggle Actions (targeted updates)

    func scenesChevronTapped() {
        let scenesKey = "scenes"
        if expandedSections.contains(scenesKey) {
            expandedSections.remove(scenesKey)
        } else {
            expandedSections.insert(scenesKey)
        }
        updateScenesSection()
    }

    func scenesEyeTapped() {
        PreferencesManager.shared.hideScenesSection.toggle()
        updateScenesSection()
    }

    func otherChevronTapped() {
        let otherKey = "other"
        if expandedSections.contains(otherKey) {
            expandedSections.remove(otherKey)
        } else {
            expandedSections.insert(otherKey)
        }
        updateOtherSection()
    }

    func otherEyeTapped() {
        PreferencesManager.shared.hideOtherSection.toggle()
        updateOtherSection()
    }

    private func roomChevronToggled(roomIndex: Int) {
        guard roomIndex < orderedRooms.count else { return }
        let roomId = orderedRooms[roomIndex].uniqueIdentifier
        if expandedSections.contains(roomId) {
            expandedSections.remove(roomId)
        } else {
            expandedSections.insert(roomId)
        }
        updateRoomsSection()
    }

    private func roomEyeToggled(roomIndex: Int) {
        guard roomIndex < orderedRooms.count else { return }
        let roomId = orderedRooms[roomIndex].uniqueIdentifier
        PreferencesManager.shared.toggleHidden(roomId: roomId)
        updateRoomsSection()
    }

    private func roomPinToggled(roomIndex: Int) {
        guard roomIndex < orderedRooms.count else { return }
        let room = orderedRooms[roomIndex]
        PreferencesManager.shared.togglePinnedRoom(roomId: room.uniqueIdentifier)
        updateRoomsSection()
    }
}

// MARK: - Groups table view (prevents dragging when only one group)

class GroupsTableView: NSTableView {

    override func mouseDown(with event: NSEvent) {
        guard numberOfRows > 1 else { return }
        super.mouseDown(with: event)
    }
}

// MARK: - Rooms table view (prevents dragging accessory rows)

class RoomsTableView: NSTableView {

    var roomTableItems: (() -> [RoomTableItem])?
    var groupCountForRoom: ((String) -> Int)?

    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .withinApplication ? .move : []
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)

        if clickedRow >= 0, let items = roomTableItems?(), clickedRow < items.count {
            let item = items[clickedRow]
            switch item {
            case .header:
                break // headers are always draggable
            case .group(_, let roomId):
                // Only allow drag if the room has more than one group
                if let roomId = roomId, (groupCountForRoom?(roomId) ?? 0) <= 1 {
                    return
                }
            default:
                return
            }
        }

        super.mouseDown(with: event)
    }
}
