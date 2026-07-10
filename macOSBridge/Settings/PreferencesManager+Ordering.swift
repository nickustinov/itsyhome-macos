//
//  PreferencesManager+Ordering.swift
//  macOSBridge
//
//  Order management for rooms, scenes, cameras, and groups
//

import Foundation

extension PreferencesManager {

    // MARK: - Camera order (per-home)

    var cameraOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.cameraOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.cameraOrder))
            postNotification()
        }
    }

    func moveCameraOrder(from sourceIndex: Int, to destinationIndex: Int) {
        var order = cameraOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        cameraOrder = order
    }

    // MARK: - Room order (per-home)

    var roomOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.roomOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.roomOrder))
            postNotification()
        }
    }

    func moveRoom(from sourceIndex: Int, to destinationIndex: Int) {
        var order = roomOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        roomOrder = order
    }

    // MARK: - Menu layout (per-home)

    /// Tokens for the non-room sections of the menu's top level. The
    /// "section:" prefix cannot collide with room UUID strings.
    static let favouritesSectionToken = "section:favourites"
    static let groupsSectionToken = "section:groups"
    static let scenesSectionToken = "section:scenes"
    static let batteriesSectionToken = "section:batteries"
    static let otherSectionToken = "section:other"

    static var sectionTokens: [String] {
        [favouritesSectionToken, groupsSectionToken, scenesSectionToken, batteriesSectionToken, otherSectionToken]
    }

    static func newDividerToken() -> String {
        "\(dividerPrefix)\(UUID().uuidString)"
    }

    /// The menu's complete top-level layout: every section (favourites,
    /// global groups, scenes, each room, other, batteries) interleaved with
    /// user divider tokens ("divider:<uuid>", same form as in-room dividers).
    /// Authoritative for the menu and the settings list; `roomOrder` is kept
    /// as the derived room-only subsequence for consumers that only
    /// understand rooms (webhook API, cloud sync).
    var menuLayout: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.menuLayout)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.menuLayout))
            roomOrder = newValue.filter { !$0.hasPrefix("section:") && !$0.hasPrefix(Self.dividerPrefix) }
        }
    }

    /// Resolve the saved layout against the rooms that actually exist: stale
    /// entries are dropped, new rooms are appended after the last room, and
    /// missing section tokens are seeded at their classic positions. User
    /// dividers are kept wherever they are. Pure: persists nothing, so it is
    /// safe to call while building the menu.
    func reconciledMenuLayout(roomIds: [String]) -> [String] {
        let validIds = Set(roomIds)

        // First run: classic layout - favourites, groups, scenes and the
        // rooms block split by dividers, then Other and Batteries.
        if menuLayout.isEmpty {
            var rooms = roomOrder.filter { validIds.contains($0) }
            for id in roomIds where !rooms.contains(id) { rooms.append(id) }
            return [
                Self.favouritesSectionToken, Self.newDividerToken(),
                Self.groupsSectionToken, Self.newDividerToken(),
                Self.scenesSectionToken, Self.newDividerToken()
            ] + rooms + [
                Self.otherSectionToken, Self.newDividerToken(),
                Self.batteriesSectionToken
            ]
        }

        var order: [String] = []
        for token in menuLayout where Self.sectionTokens.contains(token) || validIds.contains(token) || token.hasPrefix(Self.dividerPrefix) {
            if !order.contains(token) { order.append(token) }
        }

        // Seed section tokens a fresh install would have but this layout
        // lacks (added in a later version): leading sections at the top in
        // their classic order, trailing ones at the end.
        for token in [Self.scenesSectionToken, Self.groupsSectionToken, Self.favouritesSectionToken] where !order.contains(token) {
            order.insert(token, at: 0)
        }
        for token in [Self.otherSectionToken, Self.batteriesSectionToken] where !order.contains(token) {
            order.append(token)
        }

        // Append rooms not yet in the saved layout, respecting the legacy
        // roomOrder sequence.
        let known = Set(order)
        var newRooms = roomOrder.filter { validIds.contains($0) && !known.contains($0) }
        for id in roomIds where !known.contains(id) && !newRooms.contains(id) {
            newRooms.append(id)
        }
        if !newRooms.isEmpty {
            let insertIndex = order.lastIndex(where: { validIds.contains($0) })
                .map { $0 + 1 }
                ?? order.firstIndex(of: Self.otherSectionToken)
                ?? order.count
            order.insert(contentsOf: newRooms, at: insertIndex)
        }
        return order
    }

    /// Insert a top-level divider just above the given section token
    /// (room id or one of the section tokens).
    func addMenuSectionDivider(beforeToken token: String) {
        var order = menuLayout
        guard let index = order.firstIndex(of: token) else { return }
        order.insert(Self.newDividerToken(), at: index)
        menuLayout = order
    }

    func removeMenuSectionDivider(token: String) {
        var order = menuLayout
        order.removeAll { $0 == token }
        menuLayout = order
    }

    /// Persist the reconciled layout (and its roomOrder mirror) when it
    /// drifted from what is saved. Called from the settings screen, not the
    /// menu builder, so building the menu never re-posts a preferences change.
    func normalizeMenuLayout(roomIds: [String]) -> [String] {
        let order = reconciledMenuLayout(roomIds: roomIds)
        if order != menuLayout {
            menuLayout = order
        }
        return order
    }

    // MARK: - Scene order (per-home)

    var sceneOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.sceneOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.sceneOrder))
            postNotification()
        }
    }

    func moveScene(from sourceIndex: Int, to destinationIndex: Int) {
        var order = sceneOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        sceneOrder = order
    }

    // MARK: - Global group order (per-home)

    /// Order of groups that have no room assignment (global groups)
    var globalGroupOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.globalGroupOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.globalGroupOrder))
            postNotification()
        }
    }

    func moveGlobalGroup(from sourceIndex: Int, to destinationIndex: Int) {
        var order = globalGroupOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        globalGroupOrder = order
    }

    // MARK: - Group order by room (per-home)

    /// Per-room group ordering
    var groupOrderByRoom: [String: [String]] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.groupOrderByRoom)),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.groupOrderByRoom))
                postNotification()
            }
        }
    }

    func groupOrder(forRoom roomId: String) -> [String] {
        groupOrderByRoom[roomId] ?? []
    }

    func setGroupOrder(_ order: [String], forRoom roomId: String) {
        var mapping = groupOrderByRoom
        if order.isEmpty {
            mapping.removeValue(forKey: roomId)
        } else {
            mapping[roomId] = order
        }
        groupOrderByRoom = mapping
    }

    // MARK: - Accessory order by room (per-home)

    /// Per-room accessory (service) ordering. Entries are either service UUID
    /// strings or divider tokens of the form "divider:<uuid>". Empty means the
    /// room uses the default type-grouped rendering.
    var accessoryOrderByRoom: [String: [String]] {
        get {
            guard let data = defaults.data(forKey: homeKey(Keys.accessoryOrderByRoom)),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: homeKey(Keys.accessoryOrderByRoom))
                postNotification()
            }
        }
    }

    static let dividerPrefix = "divider:"

    func accessoryOrder(forRoom roomId: String) -> [String] {
        accessoryOrderByRoom[roomId] ?? []
    }

    func setAccessoryOrder(_ order: [String], forRoom roomId: String) {
        var mapping = accessoryOrderByRoom
        if order.isEmpty {
            mapping.removeValue(forKey: roomId)
        } else {
            mapping[roomId] = order
        }
        accessoryOrderByRoom = mapping
    }

    func resetAccessoryOrder(forRoom roomId: String) {
        setAccessoryOrder([], forRoom: roomId)
    }

    func addDivider(forRoom roomId: String, at insertionIndex: Int? = nil) {
        var order = accessoryOrder(forRoom: roomId)
        let token = "\(Self.dividerPrefix)\(UUID().uuidString)"
        if let index = insertionIndex, index >= 0, index <= order.count {
            order.insert(token, at: index)
        } else {
            order.append(token)
        }
        setAccessoryOrder(order, forRoom: roomId)
    }

    func removeItem(_ token: String, forRoom roomId: String) {
        var order = accessoryOrder(forRoom: roomId)
        order.removeAll { $0 == token }
        setAccessoryOrder(order, forRoom: roomId)
    }

    func moveAccessoryInRoom(_ roomId: String, from sourceIndex: Int, to destinationIndex: Int) {
        var order = accessoryOrder(forRoom: roomId)
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        setAccessoryOrder(order, forRoom: roomId)
    }
}
