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
}
