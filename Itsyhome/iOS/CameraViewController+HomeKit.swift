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
        guard error == nil else { return }
        for (index, accessory) in cameraAccessories.enumerated() {
            if snapshotControls[accessory.uniqueIdentifier] === cameraSnapshotControl {
                DispatchQueue.main.async {
                    self.snapshotTimestamps[accessory.uniqueIdentifier] = Date()
                    let indexPath = IndexPath(item: index, section: 0)
                    self.collectionView.reloadItems(at: [indexPath])
                }
                break
            }
        }
    }
}

// MARK: - HMCameraStreamControlDelegate

extension CameraViewController: HMCameraStreamControlDelegate {

    func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        DispatchQueue.main.async {
            if let stream = cameraStreamControl.cameraStream {
                let savedMuted = self.activeStreamAccessory.map { self.loadMuteSetting(for: $0) } ?? false
                self.isMuted = savedMuted
                self.updateMuteButtonState()

                let audioSetting: HMCameraAudioStreamSetting = savedMuted ? .muted : (HMCameraAudioStreamSetting(rawValue: 2) ?? .muted)
                stream.updateAudioStreamSetting(audioSetting) { _ in }
            }
            self.streamSpinner.stopAnimating()
            self.streamCameraView.isHidden = false
            self.streamCameraView.cameraSource = cameraStreamControl.cameraStream
        }
    }

    func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        if error != nil {
            DispatchQueue.main.async {
                self.backToGrid()
            }
        }
    }
}
