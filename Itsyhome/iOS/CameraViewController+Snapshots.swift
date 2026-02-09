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
        if isHomeAssistant {
            takeAllHASnapshots()
            return
        }

        for accessory in cameraAccessories {
            guard let profile = accessory.cameraProfiles?.first,
                  let snapshotControl = profile.snapshotControl else { continue }

            snapshotControl.delegate = self
            snapshotControls[accessory.uniqueIdentifier] = snapshotControl
            snapshotControl.takeSnapshot()
        }
    }

    func startSnapshotTimer() {
        stopSnapshotTimer()
        if isHomeAssistant {
            startHASnapshotTimer()
            return
        }
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.takeAllSnapshots()
        }
    }

    func stopSnapshotTimer() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
        haSnapshotTimer?.invalidate()
        haSnapshotTimer = nil
    }

    func startTimestampTimer() {
        stopTimestampTimer()
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
                  indexPath.item < cameraCount else { continue }
            let uuid = cameraUUID(at: indexPath.item)
            snapshotCell.updateTimestamp(since: snapshotTimestamps[uuid])
        }
    }
}
