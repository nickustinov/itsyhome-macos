//
//  CameraViewController+Streaming.swift
//  Itsyhome
//
//  Camera streaming functionality
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Streaming

    func startStream(for accessory: HMAccessory) {
        guard let profile = accessory.cameraProfiles?.first,
              let streamControl = profile.streamControl else { return }

        activeStreamAccessory = accessory

        streamContainerView.isHidden = false
        streamCameraView.isHidden = true
        streamSpinner.startAnimating()
        collectionView.isHidden = true
        stopSnapshotTimer()

        updatePanelSize(width: Self.streamWidth, height: Self.streamHeight, animated: false)
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
        if isPinned {
            isPinned = false
            pinButton.setImage(UIImage(systemName: "pin")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
            macOSController?.setCameraPanelPinned(false)
        }

        activeStreamControl?.stopStream()
        activeStreamControl = nil
        activeStreamAccessory = nil
        streamCameraView.cameraSource = nil
        streamCameraView.isHidden = false
        streamSpinner.stopAnimating()
        streamContainerView.isHidden = true
        streamOverlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        resetAudioState()
        collectionView.isHidden = cameraAccessories.isEmpty
        collectionView.setContentOffset(.zero, animated: false)

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
        startSnapshotTimer()
    }
}
