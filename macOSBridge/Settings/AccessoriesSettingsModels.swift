//
//  AccessoriesSettingsModels.swift
//  macOSBridge
//
//  Data models for accessories settings
//

import AppKit

// MARK: - Pasteboard types

extension NSPasteboard.PasteboardType {
    static let favouriteItem = NSPasteboard.PasteboardType("com.itsyhome.favouriteItem")
    static let roomItem = NSPasteboard.PasteboardType("com.itsyhome.roomItem")
    static let sceneItem = NSPasteboard.PasteboardType("com.itsyhome.sceneItem")
    static let globalGroupItem = NSPasteboard.PasteboardType("com.itsyhome.globalGroupItem")
    static let roomAccessoryItem = NSPasteboard.PasteboardType("com.itsyhome.roomAccessoryItem")
    static let groupDeviceItem = NSPasteboard.PasteboardType("com.itsyhome.groupDeviceItem")
}

// MARK: - Data models

struct FavouriteItem {
    enum Kind {
        case scene(SceneData)
        case service(ServiceData)
        case group(DeviceGroup)
    }
    let kind: Kind
    let id: String
    let name: String
    let icon: NSImage?
}

enum RoomTableItem {
    case header(room: RoomData, isHidden: Bool, isCollapsed: Bool, serviceCount: Int)
    case group(group: DeviceGroup, roomId: String?)
    case groupSeparator
    case accessory(service: ServiceData, roomHidden: Bool, roomId: String)
    /// Auto-inserted separator between type groups (not user-controlled).
    case separator
    /// User-inserted divider, persisted in PreferencesManager.accessoryOrderByRoom.
    case divider(token: String, roomId: String)
    /// Favourites section header.
    case favouritesHeader(isCollapsed: Bool, count: Int)
    /// One favourite row under the favourites header.
    case favourite(item: FavouriteItem)
    /// Global groups section header.
    case groupsHeader(isCollapsed: Bool, count: Int)
    /// One global group row under the groups header.
    case globalGroup(group: DeviceGroup)
    /// Scenes section header.
    case scenesHeader(isHidden: Bool, isCollapsed: Bool, sceneCount: Int)
    /// One scene row under the scenes header.
    case scene(scene: SceneData, sectionHidden: Bool)
    /// Batteries section header (#144).
    case batteriesHeader(isHidden: Bool, deviceCount: Int)
    /// "Other" (no room) section header.
    case otherHeader(isHidden: Bool, isCollapsed: Bool, count: Int)
    /// One read-only accessory row under the "Other" header (not orderable –
    /// the section renders type-grouped).
    case otherAccessory(service: ServiceData, sectionHidden: Bool)
    /// One device row inside an expanded group (room or global); drags
    /// reorder the group's deviceIds.
    case groupDevice(service: ServiceData, groupId: String)
    /// User divider between top-level sections, persisted in
    /// PreferencesManager.menuLayout.
    case sectionDivider(token: String)
    /// Synthesized auto group ("All lights"). Top level when roomId is nil
    /// (draggable via menuLayout), otherwise a row inside its room (draggable
    /// via the room's accessoryOrder). Eye toggles hiddenAutoGroupIds.
    case autoGroup(group: DeviceGroup, token: String, roomId: String?)

    var isHeader: Bool {
        if case .header = self { return true }
        return false
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }

    /// Token identifying a draggable top-level row in
    /// PreferencesManager.menuLayout (section headers and top-level
    /// dividers); nil for rows inside a section.
    var sectionToken: String? {
        switch self {
        case .header(let room, _, _, _): return room.uniqueIdentifier
        case .favouritesHeader: return PreferencesManager.favouritesSectionToken
        case .groupsHeader: return PreferencesManager.groupsSectionToken
        case .scenesHeader: return PreferencesManager.scenesSectionToken
        case .batteriesHeader: return PreferencesManager.batteriesSectionToken
        case .otherHeader: return PreferencesManager.otherSectionToken
        case .sectionDivider(let token): return token
        case .autoGroup(_, let token, let roomId): return roomId == nil ? token : nil
        default: return nil
        }
    }
}
