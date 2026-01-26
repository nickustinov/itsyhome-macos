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
        alert.messageText = "Custom icons require Itsyhome Pro"
        alert.informativeText = "Upgrade to Pro to customize icons for your accessories, scenes, groups, and rooms."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Get Pro")
        alert.addButton(withTitle: "Not now")

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
            name: "Scenes",
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

    func createOtherHeaderStrip(isCollapsed: Bool) -> NSView {
        let config = AccessoryRowConfig(
            name: "Other",
            showChevron: true,
            isCollapsed: isCollapsed,
            isSectionHeader: true
        )
        let rowView = AccessoryRowView(config: config)
        rowView.onChevronToggled = { [weak self] in
            self?.otherChevronTapped()
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

// MARK: - Rooms table view (prevents dragging accessory rows)

class RoomsTableView: NSTableView {

    var roomTableItems: (() -> [RoomTableItem])?

    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .withinApplication ? .move : []
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)

        // Only allow drag initiation from header rows and group rows
        if clickedRow >= 0, let items = roomTableItems?(), clickedRow < items.count {
            let item = items[clickedRow]
            if !item.isHeader && !item.isGroup {
                // For accessory rows, handle click but don't allow drag
                // Just select/deselect without initiating drag
                return
            }
        }

        super.mouseDown(with: event)
    }
}
