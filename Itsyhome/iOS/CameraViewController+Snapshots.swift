//
//  CameraViewController+Snapshots.swift
//  Itsyhome
//
//  Snapshot handling and timers
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Snapshots

    func takeAllSnapshots() {
        for accessory in cameraAccessories {
            guard let profile = accessory.cameraProfiles?.first,
                  let snapshotControl = profile.snapshotControl else { continue }

            snapshotControl.delegate = self
            snapshotControls[accessory.uniqueIdentifier] = snapshotControl
            snapshotControl.takeSnapshot()
        }
    }

    func startSnapshotTimer() {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.takeAllSnapshots()
        }
    }

    func stopSnapshotTimer() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    func startTimestampTimer() {
        timestampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimestampLabels()
        }
    }

    func stopTimestampTimer() {
        timestampTimer?.invalidate()
        timestampTimer = nil
    }

    func updateTimestampLabels() {
        for cell in collectionView.visibleCells {
            guard let snapshotCell = cell as? CameraSnapshotCell,
                  let indexPath = collectionView.indexPath(for: cell),
                  indexPath.item < cameraAccessories.count else { continue }
            let uuid = cameraAccessories[indexPath.item].uniqueIdentifier
            snapshotCell.updateTimestamp(since: snapshotTimestamps[uuid])
        }
    }
}
