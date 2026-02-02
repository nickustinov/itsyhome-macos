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

        let height = computeGridHeight()
        macOSController?.resizeCameraPanel(width: Self.gridWidth, height: height, aspectRatio: Self.defaultAspectRatio, cameraId: "", animated: false)
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
}
