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
    static let roomGroupItem = NSPasteboard.PasteboardType("com.itsyhome.roomGroupItem")
    static let roomAccessoryItem = NSPasteboard.PasteboardType("com.itsyhome.roomAccessoryItem")
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
    /// Scenes section header, orderable among rooms like any section.
    case scenesHeader(isHidden: Bool, isCollapsed: Bool, sceneCount: Int)
    /// One scene row under the scenes header.
    case scene(scene: SceneData, sectionHidden: Bool)
    /// Batteries section header (#144), orderable among rooms.
    case batteriesHeader(isHidden: Bool, deviceCount: Int)
    /// User divider between top-level sections, persisted in
    /// PreferencesManager.menuSectionOrder.
    case sectionDivider(token: String)

    var isHeader: Bool {
        if case .header = self { return true }
        return false
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }

    /// Token identifying a draggable top-level row in
    /// PreferencesManager.menuSectionOrder (section headers and top-level
    /// dividers); nil for rows inside a section.
    var sectionToken: String? {
        switch self {
        case .header(let room, _, _, _): return room.uniqueIdentifier
        case .scenesHeader: return PreferencesManager.scenesSectionToken
        case .batteriesHeader: return PreferencesManager.batteriesSectionToken
        case .sectionDivider(let token): return token
        default: return nil
        }
    }
}
