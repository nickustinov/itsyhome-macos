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
        cameraAccessories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraSnapshotCell.reuseId, for: indexPath) as! CameraSnapshotCell
        let accessory = cameraAccessories[indexPath.item]
        cell.configure(name: accessory.name)
        cell.updateTimestamp(since: snapshotTimestamps[accessory.uniqueIdentifier])

        if let snapshotControl = snapshotControls[accessory.uniqueIdentifier],
           let snapshot = snapshotControl.mostRecentSnapshot {
            cell.cameraView.cameraSource = snapshot
        }

        let items = overlayData[accessory.uniqueIdentifier] ?? []
        cell.configureOverlays(items: items, target: self, action: #selector(overlayPillTapped(_:)))

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension CameraViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let accessory = cameraAccessories[indexPath.item]
        startStream(for: accessory)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CameraViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = CameraViewController.gridWidth - CameraViewController.sectionSide * 2
        let height = width * 9.0 / 16.0 + CameraViewController.labelHeight
        return CGSize(width: width, height: height)
    }
}
