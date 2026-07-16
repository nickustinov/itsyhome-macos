//
//  CameraViewController+HomeKit.swift
//  Itsyhome
//
//  HomeKit camera delegates
//

import UIKit
import HomeKit

// MARK: - HMCameraSnapshotControlDelegate

extension CameraViewController: HMCameraSnapshotControlDelegate {

    func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?) {
        guard error == nil, let snapshot = snapshot else { return }
        for (index, accessory) in cameraAccessories.enumerated() {
            if snapshotControls[accessory.uniqueIdentifier] === cameraSnapshotControl {
                let uuid = accessory.uniqueIdentifier
                DispatchQueue.main.async {
                    self.cacheAspectRatio(from: snapshot, for: uuid)
                    self.snapshotTimestamps[uuid] = Date()
                    let indexPath = IndexPath(item: index, section: 0)
                    self.collectionView.reloadItems(at: [indexPath])
                }
                break
            }
        }
    }
}

// MARK: - CameraStreamEngineDelegate

extension CameraViewController: CameraStreamEngineDelegate {

    func streamEngine(_ engine: CameraStreamEngine, didStartStreamFor cameraId: UUID) {
        // Read aspect ratio from the stream source (authoritative)
        if let stream = engine.stream(for: cameraId) {
            let oldRatio = cameraAspectRatios[cameraId]
            cacheAspectRatio(from: stream, for: cameraId, fromStream: true)
            if cameraAspectRatios[cameraId] != oldRatio, !hasPendingOrActiveStream {
                collectionView.collectionViewLayout.invalidateLayout()
                updatePanelSize(width: gridPanelWidth, height: computeGridHeight(), animated: false)
            }
        }

        if let accessory = activeStreamAccessory, accessory.uniqueIdentifier == cameraId {
            // The detail view is waiting for this stream
            detailStreamDidStart(for: accessory)
        } else {
            reloadTile(for: cameraId)
        }
    }

    func streamEngine(_ engine: CameraStreamEngine, didStopStreamFor cameraId: UUID, error: Error?) {
        if let accessory = activeStreamAccessory, accessory.uniqueIdentifier == cameraId, error != nil {
            backToGrid()
            return
        }
        reloadTile(for: cameraId)
    }

    /// Reloads a single grid tile so it switches between its live render
    /// view and the snapshot fallback.
    private func reloadTile(for cameraId: UUID) {
        guard !isHomeAssistant,
              let index = cameraAccessories.firstIndex(where: { $0.uniqueIdentifier == cameraId }) else { return }
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }
}
