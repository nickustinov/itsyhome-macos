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

        if isHomeAssistant {
            cell.updateTimestamp(since: snapshotTimestamps[uuid])
            cell.configureForHA(image: haSnapshotImages[uuid])

            // Configure HA overlays
            let items = haOverlayData[uuid] ?? []
            cell.configureHAOverlays(items: items, target: self, action: #selector(haOverlayPillTapped(_:)))
        } else {
            cell.configureForHomeKit()
            let accessory = cameraAccessories[indexPath.item]
            if let liveView = streamEngine.liveRenderView(for: uuid), liveView !== activeLiveView {
                cell.attachLiveView(liveView)
                cell.showLive()
            } else {
                cell.updateTimestamp(since: snapshotTimestamps[uuid])
                if let snapshotControl = snapshotControls[accessory.uniqueIdentifier],
                   let snapshot = snapshotControl.mostRecentSnapshot {
                    cell.cameraView.cameraSource = snapshot
                }
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
        if isHomeAssistant {
            let camera = haCameras[indexPath.item]
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
        tileSize(at: indexPath.item)
    }
}
