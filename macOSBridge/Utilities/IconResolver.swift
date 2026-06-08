//
//  IconResolver.swift
//  macOSBridge
//
//  Centralized icon resolution that checks custom icons first
//

import AppKit

enum IconResolver {

    // MARK: - Service icons

    /// Get icon for a service, checking custom icons first
    static func icon(for service: ServiceData, filled: Bool = false) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: service.uniqueIdentifier) {
            return PhosphorIcon.icon(customName, filled: filled)
        }
        return IconMapping.iconForServiceType(service.serviceType, filled: filled)
    }

    /// Get icon name for a service, checking custom icons first
    static func iconName(for service: ServiceData) -> String {
        PreferencesManager.shared.customIcon(for: service.uniqueIdentifier)
            ?? PhosphorIcon.defaultIconName(for: service.serviceType)
    }

    /// State-aware icon for a binary sensor (menu row or pinned status item).
    /// A user-chosen custom icon is always honoured (only its fill weight
    /// reflects state); otherwise the central config's per-state glyphs are used
    /// (e.g. door-open / door for a contact sensor), falling back to filling the
    /// default icon when active.
    static func sensorIcon(for service: ServiceData, active: Bool) -> NSImage? {
        if PreferencesManager.shared.customIcon(for: service.uniqueIdentifier) != nil {
            return icon(for: service, filled: active)
        }
        let mode = active ? "open" : "closed"
        return PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: false)
            ?? icon(for: service, filled: active)
    }

    /// Get icon for a service by ID and type, checking custom icons first
    static func icon(forServiceId serviceId: String, serviceType: String, filled: Bool = false) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: serviceId) {
            return PhosphorIcon.icon(customName, filled: filled)
        }
        return IconMapping.iconForServiceType(serviceType, filled: filled)
    }

    /// Get icon name for a service by ID and type, checking custom icons first
    static func iconName(forServiceId serviceId: String, serviceType: String) -> String {
        PreferencesManager.shared.customIcon(for: serviceId)
            ?? PhosphorIcon.defaultIconName(for: serviceType)
    }

    // MARK: - Scene icons

    /// Get icon for a scene, checking custom icons first
    static func icon(for scene: SceneData) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: scene.uniqueIdentifier) {
            return PhosphorIcon.regular(customName)
        }
        return PhosphorIcon.iconForScene(scene.name)
    }

    /// Get icon name for a scene, checking custom icons first
    static func iconName(for scene: SceneData) -> String {
        PreferencesManager.shared.customIcon(for: scene.uniqueIdentifier)
            ?? PhosphorIcon.iconNameForScene(scene.name)
    }

    /// Get icon for a scene by ID and name, checking custom icons first
    static func icon(forSceneId sceneId: String, sceneName: String) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: sceneId) {
            return PhosphorIcon.regular(customName)
        }
        return PhosphorIcon.iconForScene(sceneName)
    }

    // MARK: - Group icons

    /// Get icon for a group, checking custom icons first
    static func icon(for group: DeviceGroup, filled: Bool = false) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: group.id) {
            return PhosphorIcon.icon(customName, filled: filled)
        }
        return PhosphorIcon.icon(group.icon, filled: filled)
    }

    /// Get icon name for a group, checking custom icons first
    static func iconName(for group: DeviceGroup) -> String {
        PreferencesManager.shared.customIcon(for: group.id) ?? group.icon
    }

    /// Get icon for a group by ID, checking custom icons first
    static func icon(forGroupId groupId: String, filled: Bool = false) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: groupId) {
            return PhosphorIcon.icon(customName, filled: filled)
        }
        // Fall back to default group icon if no custom icon and no group object available
        return PhosphorIcon.icon(PhosphorIcon.defaultGroupIcon, filled: filled)
    }

    // MARK: - Room icons

    /// Get icon for a room, checking custom icons first
    static func icon(forRoomId roomId: String, roomName: String) -> NSImage? {
        if let customName = PreferencesManager.shared.customIcon(for: roomId) {
            return PhosphorIcon.regular(customName)
        }
        return PhosphorIcon.iconForRoom(roomName)
    }

    /// Get icon name for a room, checking custom icons first
    static func iconName(forRoomId roomId: String, roomName: String) -> String {
        PreferencesManager.shared.customIcon(for: roomId)
            ?? PhosphorIcon.iconNameForRoom(roomName)
    }
}
