//
//  MacOSController+PinnedItems.swift
//  macOSBridge
//
//  Pinned status items management and hotkey handling
//

import AppKit

extension MacOSController {

    // MARK: - Pinned status items

    func syncPinnedStatusItems() {
        guard let data = currentMenuData else { return }

        let pinnedIds = PreferencesManager.shared.pinnedItemIds

        // Build lookup maps
        let allServices = data.accessories.flatMap { $0.services }
        let serviceLookup = Dictionary(uniqueKeysWithValues: allServices.map { ($0.uniqueIdentifier, $0) })
        let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0) })
        let sceneLookup = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.uniqueIdentifier, $0) })
        let deviceGroups = PreferencesManager.shared.deviceGroups

        // Build services by room, filtering out hidden services
        let hiddenServiceIds = PreferencesManager.shared.hiddenServiceIds
        var servicesByRoom: [String: [ServiceData]] = [:]
        for service in allServices {
            if let roomId = service.roomIdentifier, !hiddenServiceIds.contains(service.uniqueIdentifier) {
                servicesByRoom[roomId, default: []].append(service)
            }
        }

        // Determine which pinned items are valid
        var validPinnedItems: [String: PinnedItemType] = [:]
        for pinId in pinnedIds {
            if pinId == PreferencesManager.scenesSectionPinId {
                // Scenes section pin
                let visibleScenes = data.scenes.filter { !PreferencesManager.shared.isHidden(sceneId: $0.uniqueIdentifier) }
                if !visibleScenes.isEmpty {
                    validPinnedItems[pinId] = .scenesSection(visibleScenes)
                }
            } else if pinId.hasPrefix("room:") {
                // Room pin
                let roomId = String(pinId.dropFirst(5))
                if let room = roomLookup[roomId], let services = servicesByRoom[roomId], !services.isEmpty {
                    validPinnedItems[pinId] = .room(room, services)
                }
            } else if pinId.hasPrefix("scene:") {
                // Scene pin
                let sceneId = String(pinId.dropFirst(6))
                if let scene = sceneLookup[sceneId] {
                    validPinnedItems[pinId] = .scene(scene)
                }
            } else if pinId.hasPrefix("group:") {
                // Group pin
                let groupId = String(pinId.dropFirst(6))
                if let group = deviceGroups.first(where: { $0.id == groupId }) {
                    let services = group.resolveServices(in: data)
                    if !services.isEmpty {
                        validPinnedItems[pinId] = .group(group, services)
                    }
                }
            } else {
                // Service pin
                if let service = serviceLookup[pinId], !hiddenServiceIds.contains(pinId) {
                    validPinnedItems[pinId] = .service(service)
                }
            }
        }

        // Remove status items that are no longer valid
        for (itemId, _) in pinnedStatusItems {
            if validPinnedItems[itemId] == nil {
                pinnedStatusItems.removeValue(forKey: itemId)
            }
        }

        // Create status items for newly pinned items
        for (itemId, itemType) in validPinnedItems {
            if pinnedStatusItems[itemId] == nil {
                let itemName: String
                switch itemType {
                case .service(let service):
                    itemName = service.name
                case .room(let room, _):
                    itemName = room.name
                case .scene(let scene):
                    itemName = scene.name
                case .scenesSection:
                    itemName = "Scenes"
                case .group(let group, _):
                    itemName = group.name
                }

                let statusItem = PinnedStatusItem(itemId: itemId, itemName: itemName, itemType: itemType)
                statusItem.delegate = self
                pinnedStatusItems[itemId] = statusItem

                // Load cached values immediately for display
                statusItem.loadInitialValues()

                // Request fresh values for the characteristics
                for charId in statusItem.characteristicIdentifiers {
                    readCharacteristic(identifier: charId)
                }
            }
        }
    }

    func handleHotkeyForFavourite(_ favouriteId: String) {
        guard let data = currentMenuData else { return }

        if let scene = data.scenes.first(where: { $0.uniqueIdentifier == favouriteId }),
           let sceneUUID = UUID(uuidString: scene.uniqueIdentifier) {
            executeScene(identifier: sceneUUID)
            return
        }

        if let group = PreferencesManager.shared.deviceGroups.first(where: { $0.id == favouriteId }) {
            for service in group.resolveServices(in: data) {
                toggleService(service)
            }
            return
        }

        for accessory in data.accessories {
            for service in accessory.services {
                if service.uniqueIdentifier == favouriteId {
                    toggleService(service)
                    return
                }
            }
        }
    }

    func toggleService(_ service: ServiceData) {
        if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Bool ?? false
            writeCharacteristic(identifier: id, value: !current)
            return
        }

        if let idString = service.activeId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0)
            return
        }

        if let idString = service.lockTargetStateId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 1
            writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0)
            return
        }

        if let idString = service.targetPositionId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current > 50 ? 0 : 100)
            return
        }

        if let idString = service.targetDoorStateId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 1
            writeCharacteristic(identifier: id, value: current == 0 ? 1 : 0)
            return
        }

        if let idString = service.targetHeatingCoolingStateId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current == 0 ? 3 : 0)
            return
        }

        if let idString = service.brightnessId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 0
            writeCharacteristic(identifier: id, value: current > 0 ? 0 : 100)
            return
        }

        if let idString = service.securitySystemTargetStateId, let id = UUID(uuidString: idString) {
            let current = getCharacteristicValue(identifier: id) as? Int ?? 3
            writeCharacteristic(identifier: id, value: current == 3 ? 0 : 3)
            return
        }
    }
}
