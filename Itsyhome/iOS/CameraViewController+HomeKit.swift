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

            // Read aspect ratio from the stream source (authoritative)
            if let uuid = self.activeStreamAccessory?.uniqueIdentifier,
               let stream = cameraStreamControl.cameraStream {
                let oldRatio = self.cameraAspectRatios[uuid]
                self.cacheAspectRatio(from: stream, for: uuid, fromStream: true)
                let newRatio = self.cameraAspectRatios[uuid]

                if let ratio = newRatio, oldRatio != newRatio {
                    let width = Self.streamWidth
                    let streamHeight = width / ratio
                    self.updatePanelSize(width: width, height: streamHeight, aspectRatio: ratio, animated: true)
                }
            }
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
