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

    /// Opens the detail view for a camera by claiming its grid stream – the
    /// engine keeps the session; no second stream is started. If the stream
    /// isn't live yet the engine starts one and the spinner waits for it.
    func startStream(for accessory: HMAccessory) {
        // Snapshot-only cameras have no stream control – the engine would
        // silently do nothing and strand the user on an endless spinner.
        guard streamEngine.canStream(accessory) else { return }

        // A previously claimed camera (doorbell switch) goes back to the grid
        // with its stream still running.
        if let previous = activeStreamAccessory, previous.uniqueIdentifier != accessory.uniqueIdentifier {
            releaseDetailLiveView()
        }

        activeStreamAccessory = accessory

        streamContainerView.isHidden = false
        collectionView.isHidden = true
        stopSnapshotTimer()

        macOSController?.notifyStreamStarted(cameraIdentifier: accessory.uniqueIdentifier)

        let ratio = cameraAspectRatios[accessory.uniqueIdentifier] ?? Self.defaultAspectRatio
        let streamHeight = Self.streamWidth / ratio
        updatePanelSize(width: Self.streamWidth, height: streamHeight, aspectRatio: ratio, isStream: true, animated: false)
        updateStreamOverlays(for: accessory)
        updateAudioControls(for: accessory)

        if streamEngine.stream(for: accessory.uniqueIdentifier) != nil {
            detailStreamDidStart(for: accessory)
        } else {
            streamSpinner.startAnimating()
            streamEngine.startStream(for: accessory)
        }
    }

    /// Reparents the camera's render view into the zoom container and applies
    /// the saved audio setting. Called immediately when the grid stream is
    /// already live, or from the engine delegate once it starts.
    func detailStreamDidStart(for accessory: HMAccessory) {
        guard let liveView = streamEngine.liveRenderView(for: accessory.uniqueIdentifier) else { return }
        streamSpinner.stopAnimating()
        activeLiveView = liveView
        liveView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.addSubview(liveView)
        NSLayoutConstraint.activate([
            liveView.topAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.topAnchor),
            liveView.leadingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.leadingAnchor),
            liveView.trailingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.trailingAnchor),
            liveView.bottomAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.bottomAnchor),
            liveView.widthAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.widthAnchor),
            liveView.heightAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.heightAnchor)
        ])

        let savedMuted = loadMuteSetting(for: accessory)
        isMuted = savedMuted
        updateMuteButtonState()
        let audioSetting: HMCameraAudioStreamSetting = savedMuted ? .muted : (HMCameraAudioStreamSetting(rawValue: 2) ?? .muted)
        streamEngine.setAudio(audioSetting, for: accessory.uniqueIdentifier)

        // The stream source's aspect ratio is authoritative – resize if it
        // differs from the cached one used for the initial panel size.
        if let ratio = cameraAspectRatios[accessory.uniqueIdentifier] {
            updatePanelSize(width: Self.streamWidth, height: Self.streamWidth / ratio, aspectRatio: ratio, isStream: true, animated: true)
        }
    }

    /// Returns the detail view's render view to the grid, re-muting the
    /// stream (grid streams play silent). The stream itself stays live.
    func releaseDetailLiveView() {
        if let accessory = activeStreamAccessory {
            streamEngine.setAudio(.muted, for: accessory.uniqueIdentifier)
        }
        if let liveView = activeLiveView, liveView.superview == zoomScrollView {
            liveView.removeFromSuperview()
        }
        activeLiveView = nil
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
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)

        let height = computeGridHeight()
        updatePanelSize(width: gridPanelWidth, height: height, animated: false)
        startSnapshotTimer()
        // Covers the doorbell case where the panel opened straight into the
        // detail view and the rest of the grid never started streaming. Only
        // while the panel is visible – when backToGrid runs as part of the
        // panel hiding, starting streams here would cancel the release grace
        // panelDidHide just scheduled and leave streams running forever. In
        // snapshot mode the detail stream must not linger as a live tile.
        if !isHomeAssistant {
            if !liveGridEnabled {
                streamEngine.stopAll()
            } else if panelVisible {
                streamEngine.startStreams(for: cameraAccessories)
            }
        }
    }

    /// Clean up both HK and HA streams
    private func cleanupActiveStream() {
        // Reset zoom
        zoomScrollView.setZoomScale(1.0, animated: false)

        // HK: hand the render view back to the grid; the stream stays live
        // in the engine and is released by the panel-hide grace if unused.
        releaseDetailLiveView()
        activeStreamAccessory = nil

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
        backButton.setTitle(" " + String(localized: "common.back", defaultValue: "Back", bundle: .macOSBridge), for: .normal)
    }
}
