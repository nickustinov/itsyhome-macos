//
//  CameraViewController+CollectionView.swift
//  Itsyhome
//
//  Collection view delegate and data source
//

import UIKit
import HomeKit

// MARK: - UICollectionViewDataSource

extension CameraViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cameraCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraSnapshotCell.reuseId, for: indexPath) as! CameraSnapshotCell
        let uuid = cameraUUID(at: indexPath.item)
        let name = cameraName(at: indexPath.item)

        cell.configure(name: name)
        cell.updateTimestamp(since: snapshotTimestamps[uuid])

        if isHomeAssistant {
            cell.configureForHA(image: haSnapshotImages[uuid])
        } else {
            cell.configureForHomeKit()
            let accessory = cameraAccessories[indexPath.item]
            if let snapshotControl = snapshotControls[accessory.uniqueIdentifier],
               let snapshot = snapshotControl.mostRecentSnapshot {
                cell.cameraView.cameraSource = snapshot
            }

            let items = overlayData[accessory.uniqueIdentifier] ?? []
            cell.configureOverlays(items: items, target: self, action: #selector(overlayPillTapped(_:)))
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension CameraViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        NSLog("[CameraDebug] didSelectItemAt: item=%d isHomeAssistant=%d", indexPath.item, isHomeAssistant ? 1 : 0)
        if isHomeAssistant {
            let camera = haCameras[indexPath.item]
            NSLog("[CameraDebug] didSelectItemAt: camera=%@ entityId=%@", camera.name, camera.entityId ?? "nil")
            guard let entityId = camera.entityId else { return }
            let uuid = UUID(uuidString: camera.uniqueIdentifier)!
            startHAStream(cameraId: uuid, entityId: entityId)
        } else {
            let accessory = cameraAccessories[indexPath.item]
            startStream(for: accessory)
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CameraViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = CameraViewController.gridWidth - CameraViewController.sectionSide * 2
        let uuid = cameraUUID(at: indexPath.item)
        let ratio = cameraAspectRatios[uuid] ?? CameraViewController.defaultAspectRatio
        let height = width / ratio + CameraViewController.labelHeight
        return CGSize(width: width, height: height)
    }
}
