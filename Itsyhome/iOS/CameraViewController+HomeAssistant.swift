//
//  CameraViewController+HomeAssistant.swift
//  Itsyhome
//
//  HA camera loading, snapshot fetching, and streaming
//

import UIKit
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "CameraHA")

extension CameraViewController {

    // MARK: - Camera loading

    func loadHACameras() {
        let allCameras = Self.cachedHACameras

        // Apply ordering (same keys as PreferencesManager — no home suffix for HA)
        let order = UserDefaults.standard.stringArray(forKey: "cameraOrder") ?? []
        var ordered: [CameraData] = []
        var remaining = allCameras
        for id in order {
            if let index = remaining.firstIndex(where: { $0.uniqueIdentifier == id }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        ordered.append(contentsOf: remaining)

        // Filter hidden cameras
        let hiddenIds = Set(UserDefaults.standard.stringArray(forKey: "hiddenCameraIds") ?? [])
        haCameras = ordered.filter { !hiddenIds.contains($0.uniqueIdentifier) }

        // Resolve HA overlay data
        resolveHAOverlayData()

        if webrtcClient == nil {
            let height = computeGridHeight()
            macOSController?.resizeCameraPanel(width: Self.gridWidth, height: height, aspectRatio: Self.defaultAspectRatio, animated: false)
        }
    }

    // MARK: - Cached camera data (populated when MenuData arrives)

    private static var _cachedHACameras: [CameraData] = []
    private static let cameraDataLock = NSLock()

    static var cachedHACameras: [CameraData] {
        get {
            cameraDataLock.lock()
            defer { cameraDataLock.unlock() }
            return _cachedHACameras
        }
        set {
            cameraDataLock.lock()
            _cachedHACameras = newValue
            cameraDataLock.unlock()
        }
    }

    private static var _cachedHAMenuData: MenuData?
    private static let menuDataLock = NSLock()

    static var cachedHAMenuData: MenuData? {
        get {
            menuDataLock.lock()
            defer { menuDataLock.unlock() }
            return _cachedHAMenuData
        }
        set {
            menuDataLock.lock()
            _cachedHAMenuData = newValue
            menuDataLock.unlock()
        }
    }

    // MARK: - HA snapshot fetching

    func takeAllHASnapshots() {
        guard let serverURL = HAAuthManager.shared.serverURL,
              let token = HAAuthManager.shared.accessToken else {
            logger.error("HA credentials not available for snapshot fetch")
            return
        }

        for camera in haCameras {
            guard let entityId = camera.entityId,
                  let uuid = UUID(uuidString: camera.uniqueIdentifier) else { continue }

            let snapshotURL = serverURL
                .appendingPathComponent("api/camera_proxy")
                .appendingPathComponent(entityId)

            var request = URLRequest(url: snapshotURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }

                if let error = error {
                    logger.error("Snapshot fetch failed for \(entityId): \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode,
                      let image = UIImage(data: data) else {
                    logger.warning("Invalid snapshot response for \(entityId)")
                    return
                }

                DispatchQueue.main.async {
                    self.haSnapshotImages[uuid] = image
                    self.snapshotTimestamps[uuid] = Date()
                    self.cacheAspectRatio(from: image, for: uuid)

                    // Reload specific cell if visible
                    if let index = self.haCameras.firstIndex(where: { $0.uniqueIdentifier == uuid.uuidString }) {
                        let indexPath = IndexPath(item: index, section: 0)
                        if self.collectionView.cellForItem(at: indexPath) != nil {
                            self.collectionView.reloadItems(at: [indexPath])
                        }
                    }
                }
            }.resume()
        }
    }

    func startHASnapshotTimer() {
        haSnapshotTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.takeAllHASnapshots()
        }
    }

    // MARK: - HA streaming

    /// Debug flag: set to true to test HLS before WebRTC
    private static let preferHLSOverWebRTC = false

    func startHAStream(cameraId: UUID, entityId: String) {
        // Clean up any existing stream
        cleanupExistingHAStream()

        activeHACameraId = cameraId
        activeHAEntityId = entityId

        macOSController?.notifyStreamStarted(cameraIdentifier: cameraId)

        streamContainerView.isHidden = false
        streamCameraView.isHidden = true
        streamSpinner.startAnimating()
        collectionView.isHidden = true
        stopSnapshotTimer()

        // Hide HK audio controls (HA audio handled differently)
        audioControlsStack.isHidden = true

        let ratio = cameraAspectRatios[cameraId] ?? Self.defaultAspectRatio
        let streamHeight = Self.streamWidth / ratio
        updatePanelSize(width: Self.streamWidth, height: streamHeight, aspectRatio: ratio, animated: false)

        // Show HA stream overlays
        updateHAStreamOverlays(cameraId: cameraId)

        Task { @MainActor in
            if Self.preferHLSOverWebRTC {
                let hlsSuccess = await tryHLSStream(entityId: entityId)
                if !hlsSuccess {
                    logger.info("HLS failed, trying WebRTC for \(entityId)")
                    let webrtcSuccess = await tryWebRTCStream(entityId: entityId)
                    if !webrtcSuccess {
                        self.streamSpinner.stopAnimating()
                        self.backToGrid()
                    }
                }
            } else {
                let webrtcSuccess = await tryWebRTCStream(entityId: entityId)
                if !webrtcSuccess {
                    logger.info("WebRTC failed, trying HLS for \(entityId)")
                    let hlsSuccess = await tryHLSStream(entityId: entityId)
                    if !hlsSuccess {
                        self.streamSpinner.stopAnimating()
                        self.backToGrid()
                    }
                }
            }
        }
    }

    private func tryWebRTCStream(entityId: String) async -> Bool {
        do {
            let signaling = try await createHASignaling()

            // Fetch client config to check if a data channel is needed (e.g. Nest cameras)
            let dataChannelLabel: String?
            do {
                dataChannelLabel = try await signaling.getWebRTCClientConfig(entityId: entityId)
            } catch {
                logger.info("WebRTC client config unavailable, proceeding without data channel")
                dataChannelLabel = nil
            }

            let client = WebRTCStreamClient()
            self.webrtcClient = client

            client.onDisconnect = { [weak self] in
                DispatchQueue.main.async {
                    if self?.hlsPlayer == nil {
                        self?.backToGrid()
                    }
                }
            }

            try await client.connect(entityId: entityId, signaling: signaling, dataChannelLabel: dataChannelLabel)

            self.streamSpinner.stopAnimating()

            if let videoView = client.videoView {
                videoView.translatesAutoresizingMaskIntoConstraints = false
                self.streamContainerView.insertSubview(videoView, at: 0)
                NSLayoutConstraint.activate([
                    videoView.topAnchor.constraint(equalTo: self.streamContainerView.topAnchor),
                    videoView.leadingAnchor.constraint(equalTo: self.streamContainerView.leadingAnchor),
                    videoView.trailingAnchor.constraint(equalTo: self.streamContainerView.trailingAnchor),
                    videoView.bottomAnchor.constraint(equalTo: self.streamContainerView.bottomAnchor)
                ])
            }

            audioControlsStack.isHidden = false
            talkButton.isHidden = true
            isMuted = false
            updateMuteButtonState()
            return true

        } catch {
            logger.warning("WebRTC failed: \(error.localizedDescription)")
            webrtcClient?.disconnect()
            webrtcClient = nil
            haSignaling?.disconnect()
            haSignaling = nil
            return false
        }
    }

    private func tryHLSStream(entityId: String) async -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()
        func elapsed() -> String {
            String(format: "%.1fs", CFAbsoluteTimeGetCurrent() - startTime)
        }

        do {
            logger.info("[HLS \(elapsed())] Connecting signaling...")
            let signaling = try await createHASignaling()

            logger.info("[HLS \(elapsed())] Requesting stream URL...")
            let hlsURL = try await signaling.getHLSStreamURL(entityId: entityId)

            var fullURL = hlsURL
            if hlsURL.host == nil, let serverURL = HAAuthManager.shared.serverURL {
                fullURL = serverURL.appendingPathComponent(hlsURL.path)
            }
            logger.info("[HLS \(elapsed())] Got URL: \(fullURL.absoluteString)")

            let player = HLSStreamPlayer()
            self.hlsPlayer = player

            player.onReady = { [weak self] in
                logger.info("[HLS \(elapsed())] Stream ready to play")
                self?.streamSpinner.stopAnimating()
            }

            player.onError = { [weak self] error in
                logger.error("[HLS \(elapsed())] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.backToGrid()
                }
            }

            logger.info("[HLS \(elapsed())] Starting playback...")
            player.play(url: fullURL)

            if let videoView = player.view {
                logger.info("[HLS \(elapsed())] Adding video view to container")
                videoView.translatesAutoresizingMaskIntoConstraints = false
                self.streamContainerView.insertSubview(videoView, at: 0)
                NSLayoutConstraint.activate([
                    videoView.topAnchor.constraint(equalTo: self.streamContainerView.topAnchor),
                    videoView.leadingAnchor.constraint(equalTo: self.streamContainerView.leadingAnchor),
                    videoView.trailingAnchor.constraint(equalTo: self.streamContainerView.trailingAnchor),
                    videoView.bottomAnchor.constraint(equalTo: self.streamContainerView.bottomAnchor)
                ])
                // Bring spinner to front so it's visible over video
                self.streamContainerView.bringSubviewToFront(self.streamSpinner)
            } else {
                logger.error("[HLS \(elapsed())] No video view available!")
            }

            audioControlsStack.isHidden = false
            talkButton.isHidden = true
            isMuted = false
            updateMuteButtonState()
            logger.info("[HLS \(elapsed())] Setup complete, returning true")
            return true

        } catch {
            logger.warning("[HLS \(elapsed())] Failed: \(error.localizedDescription)")
            hlsPlayer?.stop()
            hlsPlayer = nil
            haSignaling?.disconnect()
            haSignaling = nil
            return false
        }
    }

    private func cleanupExistingHAStream() {
        if let videoView = webrtcClient?.videoView {
            videoView.removeFromSuperview()
        }
        webrtcClient?.disconnect()
        webrtcClient = nil

        if let videoView = hlsPlayer?.view {
            videoView.removeFromSuperview()
        }
        hlsPlayer?.stop()
        hlsPlayer = nil

        haSignaling?.disconnect()
        haSignaling = nil
    }

    private func createHASignaling() async throws -> HACameraSignaling {
        let signaling = HACameraSignaling()
        try await signaling.connect()
        self.haSignaling = signaling
        return signaling
    }
}
