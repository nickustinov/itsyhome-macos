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
                let uuid = accessory.uniqueIdentifier
                DispatchQueue.main.async {
                    self.snapshotTimestamps[uuid] = Date()
                    let indexPath = IndexPath(item: index, section: 0)
                    self.collectionView.reloadItems(at: [indexPath])

                    // Detect aspect ratio from the snapshot cell if not already known
                    if self.cameraAspectRatios[uuid] == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self = self,
                                  let cell = self.collectionView.cellForItem(at: indexPath) as? CameraSnapshotCell else { return }
                            self.detectAspectRatio(from: cell.cameraView, for: uuid)
                        }
                    }
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

            // Detect aspect ratio from the stream view
            if let uuid = self.activeStreamAccessory?.uniqueIdentifier {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self,
                          self.activeStreamControl != nil else { return }
                    let hadRatio = self.cameraAspectRatios[uuid] != nil
                    self.detectAspectRatio(from: self.streamCameraView, for: uuid)

                    // Only resize if a new non-default ratio was just detected
                    if !hadRatio, let ratio = self.cameraAspectRatios[uuid],
                       abs(ratio - Self.defaultAspectRatio) > 0.05 {
                        let streamHeight = Self.streamWidth / ratio
                        self.updatePanelSize(width: Self.streamWidth, height: streamHeight, aspectRatio: ratio, animated: true)
                    }
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
