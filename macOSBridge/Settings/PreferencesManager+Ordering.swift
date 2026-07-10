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

    // MARK: - Menu section order (per-home)

    /// Tokens for the non-room sections that can be ordered among rooms at the
    /// top level of the menu. The "section:" prefix cannot collide with room
    /// UUID strings.
    static let scenesSectionToken = "section:scenes"
    static let batteriesSectionToken = "section:batteries"

    /// Top-level menu order: room ids interleaved with the scenes/batteries
    /// section tokens and user divider tokens ("divider:<uuid>", same form as
    /// in-room dividers). Authoritative for the menu and the settings list;
    /// `roomOrder` is kept as the derived room-only subsequence for consumers
    /// that only understand rooms (webhook API, cloud sync).
    var menuSectionOrder: [String] {
        get { defaults.stringArray(forKey: homeKey(Keys.menuSectionOrder)) ?? [] }
        set {
            defaults.set(newValue, forKey: homeKey(Keys.menuSectionOrder))
            roomOrder = newValue.filter { !$0.hasPrefix("section:") && !$0.hasPrefix(Self.dividerPrefix) }
        }
    }

    /// Resolve the saved section order against the rooms that actually exist:
    /// stale entries are dropped, new rooms are appended after the last room
    /// (falling back to just before a trailing batteries token), and missing
    /// section tokens are seeded at their default positions – scenes first,
    /// batteries last, with a divider on each side of the rooms block,
    /// matching the classic menu layout. User dividers are kept wherever they
    /// are. Pure: persists nothing, so it is safe to call while building the
    /// menu.
    func reconciledMenuSectionOrder(roomIds: [String]) -> [String] {
        let sections = [Self.scenesSectionToken, Self.batteriesSectionToken]
        let validIds = Set(roomIds)

        // First run: classic layout, dividers around the rooms block, rooms in
        // the legacy roomOrder sequence.
        if menuSectionOrder.isEmpty {
            var rooms = roomOrder.filter { validIds.contains($0) }
            for id in roomIds where !rooms.contains(id) { rooms.append(id) }
            return [Self.scenesSectionToken, "\(Self.dividerPrefix)\(UUID().uuidString)"]
                + rooms
                + ["\(Self.dividerPrefix)\(UUID().uuidString)", Self.batteriesSectionToken]
        }

        var order: [String] = []
        for token in menuSectionOrder where sections.contains(token) || validIds.contains(token) || token.hasPrefix(Self.dividerPrefix) {
            if !order.contains(token) { order.append(token) }
        }
        if !order.contains(Self.scenesSectionToken) {
            order.insert(Self.scenesSectionToken, at: 0)
        }
        if !order.contains(Self.batteriesSectionToken) {
            order.append(Self.batteriesSectionToken)
        }

        // Append rooms not yet in the saved order, respecting the legacy
        // roomOrder sequence.
        let known = Set(order)
        var newRooms = roomOrder.filter { validIds.contains($0) && !known.contains($0) }
        for id in roomIds where !known.contains(id) && !newRooms.contains(id) {
            newRooms.append(id)
        }
        if !newRooms.isEmpty {
            let insertIndex = order.lastIndex(where: { validIds.contains($0) })
                .map { $0 + 1 }
                ?? (order.last == Self.batteriesSectionToken ? order.count - 1 : order.count)
            order.insert(contentsOf: newRooms, at: insertIndex)
        }
        return order
    }

    /// Insert a top-level divider just above the given section token
    /// (room id, scenes or batteries token).
    func addMenuSectionDivider(beforeToken token: String) {
        var order = menuSectionOrder
        guard let index = order.firstIndex(of: token) else { return }
        order.insert("\(Self.dividerPrefix)\(UUID().uuidString)", at: index)
        menuSectionOrder = order
    }

    func removeMenuSectionDivider(token: String) {
        var order = menuSectionOrder
        order.removeAll { $0 == token }
        menuSectionOrder = order
    }

    /// Persist the reconciled order (and its roomOrder mirror) when it drifted
    /// from what is saved. Called from the settings screen, not the menu
    /// builder, so building the menu never re-posts a preferences change.
    func normalizeMenuSectionOrder(roomIds: [String]) -> [String] {
        let order = reconciledMenuSectionOrder(roomIds: roomIds)
        if order != menuSectionOrder {
            menuSectionOrder = order
        }
        return order
    }

    func moveMenuSection(from sourceIndex: Int, to destinationIndex: Int) {
        var order = menuSectionOrder
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        menuSectionOrder = order
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

    func moveGroupInRoom(_ roomId: String, from sourceIndex: Int, to destinationIndex: Int) {
        var order = groupOrder(forRoom: roomId)
        guard sourceIndex >= 0, sourceIndex < order.count,
              destinationIndex >= 0, destinationIndex < order.count else { return }
        let item = order.remove(at: sourceIndex)
        order.insert(item, at: destinationIndex)
        setGroupOrder(order, forRoom: roomId)
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
