//
//  CameraViewController+Streaming.swift
//  Itsyhome
//
//  Camera streaming functionality
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - HomeKit streaming

    func startStream(for accessory: HMAccessory) {
        guard let profile = accessory.cameraProfiles?.first,
              let streamControl = profile.streamControl else { return }

        activeStreamAccessory = accessory

        streamContainerView.isHidden = false
        streamCameraView.isHidden = true
        streamSpinner.startAnimating()
        collectionView.isHidden = true
        stopSnapshotTimer()

        macOSController?.notifyStreamStarted(cameraIdentifier: accessory.uniqueIdentifier)

        let ratio = cameraAspectRatios[accessory.uniqueIdentifier] ?? Self.defaultAspectRatio
        let streamHeight = Self.streamWidth / ratio
        updatePanelSize(width: Self.streamWidth, height: streamHeight, aspectRatio: ratio, animated: false)
        updateStreamOverlays(for: accessory)
        updateAudioControls(for: accessory)

        activeStreamControl = streamControl
        streamControl.delegate = self
        streamControl.startStream()
    }

    func updateStreamOverlays(for accessory: HMAccessory) {
        streamOverlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let items = overlayData[accessory.uniqueIdentifier] else { return }

        for item in items {
            let pill = createOverlayPill(characteristic: item.characteristic, name: item.name, serviceType: item.serviceType, size: .large)
            streamOverlayStack.addArrangedSubview(pill)
        }

        for item in items {
            item.characteristic.readValue { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshStreamOverlayStates()
                }
            }
        }
    }

    func refreshStreamOverlayStates() {
        guard let accessory = activeStreamAccessory,
              let items = overlayData[accessory.uniqueIdentifier] else { return }

        for (index, pill) in streamOverlayStack.arrangedSubviews.enumerated() {
            guard index < items.count else { break }
            let isOn = characteristicIsOn(items[index].characteristic)
            updatePillState(pill, isOn: isOn)
        }
    }

    @objc func backToGrid() {
        if isDoorbellMode {
            isDoorbellMode = false
            isPinned = false
            resetDoorbellButtonState()
            cleanupActiveStream()
            collectionView.isHidden = cameraCount == 0
            macOSController?.setCameraPanelPinned(false)
            macOSController?.dismissCameraPanel()
            return
        }

        if isPinned {
            isPinned = false
            pinButton.setImage(UIImage(systemName: "pin")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
            macOSController?.setCameraPanelPinned(false)
        }

        cleanupActiveStream()
        collectionView.isHidden = cameraCount == 0
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setContentOffset(.zero, animated: false)

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
        startSnapshotTimer()
    }

    /// Clean up both HK and HA streams
    private func cleanupActiveStream() {
        // HK cleanup
        activeStreamControl?.stopStream()
        activeStreamControl = nil
        activeStreamAccessory = nil
        streamCameraView.cameraSource = nil
        streamCameraView.isHidden = false

        // HA WebRTC cleanup
        if let videoView = webrtcClient?.videoView {
            videoView.removeFromSuperview()
        }
        webrtcClient?.disconnect()
        webrtcClient = nil

        // HA HLS cleanup
        if let videoView = hlsPlayer?.view {
            videoView.removeFromSuperview()
        }
        hlsPlayer?.stop()
        hlsPlayer = nil

        // HA snapshot polling cleanup
        snapshotStreamTimer?.invalidate()
        snapshotStreamTimer = nil
        snapshotStreamImageView?.removeFromSuperview()
        snapshotStreamImageView = nil

        haSignaling?.disconnect()
        haSignaling = nil
        activeHACameraId = nil
        activeHAEntityId = nil

        streamSpinner.stopAnimating()
        streamContainerView.isHidden = true
        streamOverlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        resetAudioState()
    }

    private func resetDoorbellButtonState() {
        backButton.setImage(UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        backButton.setTitle(" Back", for: .normal)
    }
}
