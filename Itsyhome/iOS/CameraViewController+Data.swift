//
//  CameraViewController+Data.swift
//  Itsyhome
//
//  Camera loading and overlay data resolution
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Camera loading

    func loadCameras() {
        if isHomeAssistant {
            loadHACameras()
            return
        }

        guard let manager = homeKitManager else { return }

        let allCameras = manager.cameraAccessories
        let homeId = manager.selectedHomeIdentifier?.uuidString ?? ""

        let orderKey = "cameraOrder_\(homeId)"
        let hiddenKey = "hiddenCameraIds_\(homeId)"
        let order = UserDefaults.standard.stringArray(forKey: orderKey) ?? []
        let hiddenIds = Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])

        var ordered: [HMAccessory] = []
        var remaining = allCameras
        for id in order {
            if let uuid = UUID(uuidString: id),
               let index = remaining.firstIndex(where: { $0.uniqueIdentifier == uuid }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        ordered.append(contentsOf: remaining)

        cameraAccessories = ordered.filter { !hiddenIds.contains($0.uniqueIdentifier.uuidString) }

        resolveOverlayData(homeId: homeId)

        if activeStreamControl == nil && homeKitManager?.pendingDoorbellCameraId == nil {
            let height = computeGridHeight()
            macOSController?.resizeCameraPanel(width: Self.gridWidth, height: height, aspectRatio: Self.defaultAspectRatio, animated: false)
        }
    }

    func resolveOverlayData(homeId: String) {
        overlayData = [:]
        let overlayKey = "cameraOverlayAccessories_\(homeId)"
        guard let data = UserDefaults.standard.data(forKey: overlayKey),
              let mapping = try? JSONDecoder().decode([String: [String]].self, from: data),
              let home = homeKitManager?.selectedHome else { return }

        for camera in cameraAccessories {
            let cameraId = camera.uniqueIdentifier.uuidString
            guard let serviceIds = mapping[cameraId], !serviceIds.isEmpty else { continue }

            var resolved: [(characteristic: HMCharacteristic, name: String, serviceType: String)] = []
            for serviceIdStr in serviceIds {
                guard let serviceUUID = UUID(uuidString: serviceIdStr) else { continue }
                if let (characteristic, name, type) = findToggleCharacteristic(serviceUUID: serviceUUID, in: home) {
                    resolved.append((characteristic: characteristic, name: name, serviceType: type))
                }
            }
            if !resolved.isEmpty {
                overlayData[camera.uniqueIdentifier] = resolved
            }
        }

        readOverlayCharacteristicValues()
    }

    func readOverlayCharacteristicValues() {
        for (_, items) in overlayData {
            for item in items {
                item.characteristic.readValue { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.refreshVisiblePillStates()
                    }
                }
            }
        }
    }

    func refreshVisiblePillStates() {
        for cell in collectionView.visibleCells {
            guard let snapshotCell = cell as? CameraSnapshotCell,
                  let indexPath = collectionView.indexPath(for: cell),
                  indexPath.item < cameraAccessories.count else { continue }
            let uuid = cameraAccessories[indexPath.item].uniqueIdentifier
            guard let items = overlayData[uuid] else { continue }
            snapshotCell.updatePillStates(items: items)
        }
    }

    func findToggleCharacteristic(serviceUUID: UUID, in home: HMHome) -> (HMCharacteristic, String, String)? {
        for accessory in home.accessories {
            for service in accessory.services {
                if service.uniqueIdentifier == serviceUUID {
                    let type = service.serviceType
                    let name = service.name

                    switch type {
                    case HMServiceTypeGarageDoorOpener:
                        let c = service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetDoorState }
                        if let c { return (c, name, type) }
                    case HMServiceTypeLockMechanism:
                        let c = service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetLockMechanismState }
                        if let c { return (c, name, type) }
                    default:
                        let c = service.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }
                        if let c { return (c, name, type) }
                    }

                    return nil
                }
            }
        }
        return nil
    }

    // MARK: - HA overlay resolution

    func resolveHAOverlayData() {
        haOverlayData = [:]

        // Use a key without home suffix for HA (no multi-home support)
        let overlayKey = "cameraOverlayAccessories"

        // Use instance cache if available, otherwise fall back to static cache
        guard let data = UserDefaults.standard.data(forKey: overlayKey),
              let mapping = try? JSONDecoder().decode([String: [String]].self, from: data),
              let menuData = cachedMenuData ?? Self.cachedHAMenuData else {
            return
        }

        for camera in haCameras {
            let cameraId = camera.uniqueIdentifier
            guard let uuid = UUID(uuidString: cameraId),
                  let serviceIds = mapping[cameraId], !serviceIds.isEmpty else {
                continue
            }

            var resolved: [(entityId: String, name: String, serviceType: String, isOn: Bool)] = []
            for serviceIdStr in serviceIds {
                if let service = findService(id: serviceIdStr, in: menuData) {
                    resolved.append((entityId: serviceIdStr, name: service.name, serviceType: service.serviceType, isOn: false))
                }
            }
            if !resolved.isEmpty {
                haOverlayData[uuid] = resolved
            }
        }

        // Fetch actual states from HA
        fetchHAOverlayStates()
    }

    func findService(id: String, in menuData: MenuData) -> ServiceData? {
        for accessory in menuData.accessories {
            for service in accessory.services where service.uniqueIdentifier == id {
                return service
            }
        }
        return nil
    }

    func fetchHAOverlayStates() {
        let menuData = cachedMenuData ?? Self.cachedHAMenuData
        guard let serverURL = HAAuthManager.shared.serverURL,
              let token = HAAuthManager.shared.accessToken,
              let menuData = menuData else { return }

        // Collect all unique entity IDs we need to query
        var entityIds: Set<String> = []
        for (_, items) in haOverlayData {
            for item in items {
                if let service = findService(id: item.entityId, in: menuData),
                   let haEntityId = service.haEntityId {
                    entityIds.insert(haEntityId)
                }
            }
        }

        guard !entityIds.isEmpty else { return }

        // Query HA for states
        let statesURL = serverURL.appendingPathComponent("api/states")
        var request = URLRequest(url: statesURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let states = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

            // Build entity state lookup
            var stateMap: [String: Bool] = [:]
            for state in states {
                guard let entityId = state["entity_id"] as? String,
                      entityIds.contains(entityId),
                      let stateValue = state["state"] as? String else { continue }

                stateMap[entityId] = self.isEntityOn(entityId: entityId, state: stateValue)
            }

            DispatchQueue.main.async {
                self.updateHAOverlayStatesFromMap(stateMap, menuData: menuData)
            }
        }.resume()
    }

    func isEntityOn(entityId: String, state: String) -> Bool {
        let domain = entityId.components(separatedBy: ".").first ?? ""
        switch domain {
        case "light", "switch", "fan":
            return state == "on"
        case "lock":
            return state == "unlocked"
        case "cover":
            return state == "open" || state == "opening"
        default:
            return state == "on"
        }
    }

    func updateHAOverlayStatesFromMap(_ stateMap: [String: Bool], menuData: MenuData) {
        // Update haOverlayData with actual states
        for (cameraUUID, items) in haOverlayData {
            var updated: [(entityId: String, name: String, serviceType: String, isOn: Bool)] = []
            for item in items {
                if let service = findService(id: item.entityId, in: menuData),
                   let haEntityId = service.haEntityId,
                   let isOn = stateMap[haEntityId] {
                    updated.append((entityId: item.entityId, name: item.name, serviceType: item.serviceType, isOn: isOn))
                } else {
                    updated.append(item)
                }
            }
            haOverlayData[cameraUUID] = updated
        }

        // Refresh UI
        collectionView.reloadData()

        // Update stream overlays if streaming
        if let cameraId = activeHACameraId {
            updateHAStreamOverlays(cameraId: cameraId)
        }
    }

    func refreshHAOverlayStates() {
        // Re-fetch states from HA API
        fetchHAOverlayStates()
    }
}
