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

    var isHeader: Bool {
        if case .header = self { return true }
        return false
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }
}
