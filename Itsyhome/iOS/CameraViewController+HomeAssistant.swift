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

    func startHAStream(cameraId: UUID, entityId: String) {
        activeHACameraId = cameraId
        activeHAEntityId = entityId

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
            do {
                let signaling = try await createHASignaling()
                let client = WebRTCStreamClient()
                self.webrtcClient = client

                client.onDisconnect = { [weak self] in
                    DispatchQueue.main.async {
                        self?.backToGrid()
                    }
                }

                try await client.connect(
                    entityId: entityId,
                    signaling: signaling
                )

                // Stream connected — show video view
                self.streamSpinner.stopAnimating()

                if let videoView = client.videoView {
                    videoView.translatesAutoresizingMaskIntoConstraints = false
                    self.streamContainerView.insertSubview(videoView, belowSubview: self.backButton)

                    NSLayoutConstraint.activate([
                        videoView.topAnchor.constraint(equalTo: self.streamContainerView.topAnchor),
                        videoView.leadingAnchor.constraint(equalTo: self.streamContainerView.leadingAnchor),
                        videoView.trailingAnchor.constraint(equalTo: self.streamContainerView.trailingAnchor),
                        videoView.bottomAnchor.constraint(equalTo: self.streamContainerView.bottomAnchor)
                    ])
                }

                // Show mute button for WebRTC audio
                audioControlsStack.isHidden = false
                talkButton.isHidden = true
                isMuted = false
                updateMuteButtonState()

            } catch {
                logger.error("Failed to start HA stream: \(error.localizedDescription)")
                self.streamSpinner.stopAnimating()
                self.backToGrid()
            }
        }
    }

    private func createHASignaling() async throws -> HACameraSignaling {
        let signaling = HACameraSignaling()
        try await signaling.connect()
        self.haSignaling = signaling
        return signaling
    }
}
