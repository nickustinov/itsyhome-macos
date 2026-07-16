//
//  CameraViewController.swift
//  Itsyhome
//
//  Grid of camera views displayed in the menu bar panel
//

import UIKit
import HomeKit

extension Notification.Name {
    static let cameraPanelDidShow = Notification.Name("cameraPanelDidShow")
    static let cameraPanelDidHide = Notification.Name("cameraPanelDidHide")
    static let homeDidChange = Notification.Name("homeDidChange")
}

class CameraViewController: UIViewController {

    // MARK: - UI elements

    var collectionView: UICollectionView!
    var emptyLabel: UILabel!
    var streamContainerView: UIView!
    var zoomScrollView: UIScrollView!
    var streamSpinner: UIActivityIndicatorView!
    var backButton: UIButton!
    var pinButton: UIButton!
    var streamOverlayStack: UIStackView!

    // Audio controls
    var audioControlsStack: UIStackView!
    var muteButton: UIButton!
    var talkButton: UIButton!

    // MARK: - Layout constants

    static let columnWidth: CGFloat = 276
    static let streamWidth: CGFloat = 530
    static let defaultAspectRatio: CGFloat = 16.0 / 9.0

    static let sectionTop: CGFloat = 15
    static let sectionBottom: CGFloat = 15
    static let sectionSide: CGFloat = 12
    static let lineSpacing: CGFloat = 8
    static let labelHeight: CGFloat = 0

    // MARK: - State

    var cameraAccessories: [HMAccessory] = []
    var snapshotControls: [UUID: HMCameraSnapshotControl] = [:]
    let streamEngine = CameraStreamEngine()
    var activeStreamAccessory: HMAccessory?
    /// The engine render view currently claimed by the detail view.
    var activeLiveView: HMCameraView?
    /// Whether the panel window is currently on screen (streams are only
    /// started while it is, and released with a grace period after it hides).
    var panelVisible = false

    /// The detail view's stream control – nil whenever no detail is open,
    /// even while grid streams run.
    var activeStreamControl: HMCameraStreamControl? {
        activeStreamAccessory.flatMap { streamEngine.control(for: $0.uniqueIdentifier) }
    }

    // MARK: - Grid preferences (written by Settings → Cameras via
    // PreferencesManager; same process, same UserDefaults)

    var gridColumns: Int {
        let stored = UserDefaults.standard.object(forKey: "cameraGridColumns") as? Int ?? 2
        return max(1, min(3, stored))
    }

    var liveGridEnabled: Bool {
        UserDefaults.standard.object(forKey: "cameraGridLive") as? Bool ?? true
    }

    var fullWidthCameraIds: Set<String> {
        let key: String
        if isHomeAssistant {
            key = "fullWidthCameraIds"
        } else {
            let homeId = homeKitManager?.selectedHomeIdentifier?.uuidString ?? ""
            key = "fullWidthCameraIds_\(homeId)"
        }
        return Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    /// Default panel width for the columns setting – the size the panel opens
    /// at until the user drags a corner (their size then takes precedence,
    /// kept on the AppKit side).
    var gridPanelWidth: CGFloat {
        Self.sectionSide * 2 + CGFloat(gridColumns) * Self.columnWidth + CGFloat(gridColumns - 1) * Self.lineSpacing
    }

    /// Width the tiles actually flow into – the live view width once the
    /// window exists (it can differ from the default after a corner drag).
    var gridContentWidth: CGFloat {
        let viewWidth = view.bounds.width
        return (viewWidth > 0 ? viewWidth : gridPanelWidth) - Self.sectionSide * 2
    }

    /// A tile spans one column, or the full row when marked full-width
    /// (single-column grids are always full width). Column tiles divide the
    /// current content width evenly so the grid scales with the window.
    func tileSize(at index: Int) -> CGSize {
        let uuid = cameraUUID(at: index)
        let columns = gridColumns
        let contentWidth = gridContentWidth
        let isFull = columns == 1 || fullWidthCameraIds.contains(uuid.uuidString)
        let columnWidth = floor((contentWidth - CGFloat(columns - 1) * Self.lineSpacing) / CGFloat(columns))
        let width = isFull ? contentWidth : columnWidth
        let ratio = cameraAspectRatios[uuid] ?? Self.defaultAspectRatio
        return CGSize(width: width, height: width / ratio + Self.labelHeight)
    }

    // HA camera state
    var haCameras: [CameraData] = []
    var haSnapshotImages: [UUID: UIImage] = [:]
    var haSnapshotTimer: Timer?

    var isHomeAssistant: Bool {
        PlatformManager.shared.selectedPlatform == .homeAssistant
    }

    var cameraCount: Int {
        isHomeAssistant ? haCameras.count : cameraAccessories.count
    }

    func cameraUUID(at index: Int) -> UUID {
        if isHomeAssistant {
            return UUID(uuidString: haCameras[index].uniqueIdentifier)!
        } else {
            return cameraAccessories[index].uniqueIdentifier
        }
    }

    func cameraName(at index: Int) -> String {
        if isHomeAssistant {
            return haCameras[index].name
        } else {
            return cameraAccessories[index].name
        }
    }

    // Audio state
    var isMuted: Bool = false
    var isTalking: Bool = false
    var microphoneControl: HMCameraAudioControl?
    var speakerControl: HMCameraAudioControl?
    var snapshotTimer: Timer?
    var timestampTimer: Timer?
    var snapshotTimestamps: [UUID: Date] = [:]
    var cameraAspectRatios: [UUID: CGFloat] = [:]
    var streamConfirmedRatios: Set<UUID> = []
    var isPinned = false
    var isDoorbellMode = false
    var hasLoadedInitialData = false

    // HA streaming state (WebRTC, HLS, or snapshot polling)
    var webrtcClient: WebRTCStreamClient?
    var hlsPlayer: HLSStreamPlayer?
    var haSignaling: HACameraSignaling?
    var activeHACameraId: UUID?
    var activeHAEntityId: String?
    var snapshotStreamImageView: UIImageView?
    var snapshotStreamTimer: Timer?

    var hasActiveHAStream: Bool {
        webrtcClient != nil || hlsPlayer != nil || snapshotStreamTimer != nil
    }

    var hasPendingOrActiveStream: Bool {
        activeStreamAccessory != nil ||
        activeStreamControl != nil ||
        activeHACameraId != nil ||
        activeHAEntityId != nil ||
        hasActiveHAStream ||
        streamContainerView?.isHidden == false
    }

    /// Resolved overlay data per camera: [cameraUUID: [(characteristic, service name, service type)]]
    var overlayData: [UUID: [(characteristic: HMCharacteristic, name: String, serviceType: String)]] = [:]

    /// HA overlay data per camera: [cameraUUID: [(entityId, name, serviceType, isOn)]]
    var haOverlayData: [UUID: [(entityId: String, name: String, serviceType: String, isOn: Bool)]] = [:]

    /// Cached MenuData for HA overlay resolution
    var cachedMenuData: MenuData?

    var macOSController: iOS2Mac? {
        (UIApplication.shared.delegate as? AppDelegate)?.macOSController
    }

    var homeKitManager: HomeKitManager? {
        (UIApplication.shared.delegate as? AppDelegate)?.homeKitManager
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        streamEngine.delegate = self
        loadPersistedAspectRatios()
        setupCollectionView()
        setupEmptyState()
        setupStreamView()
        loadCameras()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: Notification.Name("PreferencesManagerDidChange"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidShow),
            name: .cameraPanelDidShow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidHide),
            name: .cameraPanelDidHide,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(homeDidChange),
            name: .homeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDoorbellRang(_:)),
            name: .doorbellRang,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHACameraDataUpdated(_:)),
            name: NSNotification.Name("HACameraDataUpdated"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoOpenCamera(_:)),
            name: .autoOpenCamera,
            object: nil
        )
    }

    @objc private func preferencesDidChange() {
        guard !hasPendingOrActiveStream else { return }
        loadCameras()
        reconcileGridStreams()
        emptyLabel.isHidden = cameraCount > 0
        collectionView.isHidden = cameraCount == 0
        collectionView.reloadData()

        let height = computeGridHeight()
        updatePanelSize(width: gridPanelWidth, height: height, animated: false)
    }

    @objc private func homeDidChange() {
        if hasPendingOrActiveStream {
            backToGrid()
        }
        streamEngine.stopAll()
        loadCameras()
        reconcileGridStreams()
        emptyLabel.isHidden = cameraCount > 0
        collectionView.isHidden = cameraCount == 0
        collectionView.reloadData()

        let height = computeGridHeight()
        updatePanelSize(width: gridPanelWidth, height: height, animated: false)
    }

    /// Aligns running streams with the current camera list and the live-grid
    /// preference: stops streams for cameras that left the list (or all of
    /// them in snapshot mode) and, while the panel is visible, starts the rest.
    func reconcileGridStreams() {
        guard !isHomeAssistant, liveGridEnabled else {
            streamEngine.stopAll()
            // Live tiles suppressed snapshot capture, so without a refresh
            // the grid would sit on black/stale tiles until the next timer
            // tick (up to 30s).
            if !isHomeAssistant, panelVisible {
                takeAllSnapshots()
            }
            return
        }
        streamEngine.stopStreams(notIn: Set(cameraAccessories.map { $0.uniqueIdentifier }))
        if panelVisible {
            streamEngine.startStreams(for: cameraAccessories)
        }
    }

    @objc private func panelDidShow() {
        panelVisible = true
        streamEngine.cancelScheduledRelease()
        // Check for pending auto-open (motion/doorbell from macOS controller, both platforms)
        if let cameraId = Self.pendingAutoOpenCameraId {
            Self.pendingAutoOpenCameraId = nil
            streamDoorbellCamera(id: cameraId)
            return
        }
        // HomeKit doorbell: pending ID set directly by HomeKitManager
        if !isHomeAssistant, let doorbellId = homeKitManager?.pendingDoorbellCameraId {
            homeKitManager?.pendingDoorbellCameraId = nil
            streamDoorbellCamera(id: doorbellId)
            return
        }
        guard !hasPendingOrActiveStream else { return }
        takeAllSnapshots()
        startSnapshotTimer()
        startTimestampTimer()
        if isHomeAssistant {
            refreshHAOverlayStates()
        } else if liveGridEnabled {
            streamEngine.startStreams(for: cameraAccessories)
        }
        let height = computeGridHeight()
        updatePanelSize(width: gridPanelWidth, height: height, animated: false)
    }

    @objc private func panelDidHide() {
        panelVisible = false
        stopSnapshotTimer()
        stopTimestampTimer()
        streamEngine.scheduleRelease()
        if hasPendingOrActiveStream {
            backToGrid()
        }
    }

    @objc private func handleDoorbellRang(_ notification: Notification) {
        guard let cameraId = notification.userInfo?["cameraIdentifier"] as? UUID else { return }
        homeKitManager?.pendingDoorbellCameraId = nil
        streamDoorbellCamera(id: cameraId)
    }

    /// Pending camera ID for auto-open (motion/doorbell, both platforms).
    /// Static so it survives before the view controller is created.
    static var pendingAutoOpenCameraId: UUID?

    @objc private func handleAutoOpenCamera(_ notification: Notification) {
        guard let cameraId = notification.userInfo?["cameraIdentifier"] as? UUID else { return }
        // If already streaming, switch to the new camera directly
        if hasPendingOrActiveStream {
            streamDoorbellCamera(id: cameraId)
        } else {
            Self.pendingAutoOpenCameraId = cameraId
        }
    }

    @objc private func handleHACameraDataUpdated(_ notification: Notification) {
        guard let jsonData = notification.userInfo?["camerasJSON"] as? Data,
              let cameras = try? JSONDecoder().decode([CameraData].self, from: jsonData) else {
            return
        }

        // Cache MenuData for overlay resolution (instance and static)
        if let menuDataJSON = notification.userInfo?["menuDataJSON"] as? Data,
           let menuData = try? JSONDecoder().decode(MenuData.self, from: menuDataJSON) {
            cachedMenuData = menuData
            Self.cachedHAMenuData = menuData
        }

        Self.cachedHACameras = cameras
        if isHomeAssistant {
            loadCameras()
            emptyLabel.isHidden = cameraCount > 0
            collectionView.isHidden = cameraCount == 0
            collectionView.reloadData()
        }
    }

    private func streamDoorbellCamera(id cameraId: UUID) {
        isDoorbellMode = true
        backButton.setImage(UIImage(systemName: "xmark")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        backButton.setTitle(" " + String(localized: "camera.panel.close", defaultValue: "Close", bundle: .macOSBridge), for: .normal)

        if isHomeAssistant {
            // If already streaming this camera, just ensure pinned
            if activeHACameraId == cameraId {
                ensurePinned()
                return
            }

            // If streaming another camera, stop it first
            if hasActiveHAStream {
                webrtcClient?.disconnect()
                webrtcClient = nil
                hlsPlayer?.stop()
                hlsPlayer = nil
                snapshotStreamTimer?.invalidate()
                snapshotStreamTimer = nil
                snapshotStreamImageView?.removeFromSuperview()
                snapshotStreamImageView = nil
                haSignaling?.disconnect()
                haSignaling = nil
            }

            // Find the doorbell camera entity
            guard let camera = haCameras.first(where: { $0.uniqueIdentifier == cameraId.uuidString }),
                  let entityId = camera.entityId else { return }

            startHAStream(cameraId: cameraId, entityId: entityId)
            ensurePinned()
        } else {
            // If already streaming this camera, just ensure pinned
            if activeStreamAccessory?.uniqueIdentifier == cameraId {
                ensurePinned()
                return
            }

            // Find the doorbell camera accessory. startStream hands any
            // previously claimed camera back to the grid, stream still live.
            guard let accessory = homeKitManager?.cameraAccessories.first(where: {
                $0.uniqueIdentifier == cameraId
            }) else { return }

            startStream(for: accessory)
            ensurePinned()
        }
    }

    private func ensurePinned() {
        guard !isPinned else { return }
        isPinned = true
        pinButton.setImage(UIImage(systemName: "pin.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        macOSController?.setCameraPanelPinned(true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        panelVisible = true
        streamEngine.cancelScheduledRelease()

        if !hasLoadedInitialData && cameraCount > 0 {
            hasLoadedInitialData = true
            emptyLabel.isHidden = cameraCount > 0
            collectionView.isHidden = cameraCount == 0
            collectionView.reloadData()
            takeAllSnapshots()
        }

        // Check for pending auto-open camera (motion/doorbell, both platforms)
        if let cameraId = Self.pendingAutoOpenCameraId {
            Self.pendingAutoOpenCameraId = nil
            streamDoorbellCamera(id: cameraId)
            return
        }
        if !isHomeAssistant, let doorbellId = homeKitManager?.pendingDoorbellCameraId {
            homeKitManager?.pendingDoorbellCameraId = nil
            streamDoorbellCamera(id: doorbellId)
            return
        }

        // Don't reset to grid if a stream is already active (e.g. doorbell triggered from panelDidShow)
        guard !hasPendingOrActiveStream else { return }

        let height = computeGridHeight()
        updatePanelSize(width: gridPanelWidth, height: height, animated: false)

        collectionView.setContentOffset(.zero, animated: false)
        startSnapshotTimer()
        startTimestampTimer()
        if !isHomeAssistant && liveGridEnabled {
            streamEngine.startStreams(for: cameraAccessories)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        panelVisible = false
        stopSnapshotTimer()
        stopTimestampTimer()
        streamEngine.scheduleRelease()
    }

    /// Reflow the grid when the window width changes (corner drag).
    private var lastLayoutWidth: CGFloat = 0

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width
        guard width > 0, width != lastLayoutWidth else { return }
        lastLayoutWidth = width
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Self.lineSpacing
        layout.minimumLineSpacing = Self.lineSpacing
        layout.sectionInset = UIEdgeInsets(top: Self.sectionTop, left: Self.sectionSide, bottom: Self.sectionBottom, right: Self.sectionSide)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CameraSnapshotCell.self, forCellWithReuseIdentifier: CameraSnapshotCell.reuseId)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyLabel = UILabel()
        emptyLabel.text = String(localized: "camera.panel.no_cameras", defaultValue: "No cameras found", bundle: .macOSBridge)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupStreamView() {
        streamContainerView = UIView()
        streamContainerView.translatesAutoresizingMaskIntoConstraints = false
        streamContainerView.backgroundColor = .black
        streamContainerView.isHidden = true
        view.addSubview(streamContainerView)

        NSLayoutConstraint.activate([
            streamContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            streamContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            streamContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            streamContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Zoom scroll view sits at the bottom of streamContainerView's subview stack
        zoomScrollView = UIScrollView()
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.minimumZoomScale = 1.0
        zoomScrollView.maximumZoomScale = 3.0
        zoomScrollView.bouncesZoom = true
        zoomScrollView.showsHorizontalScrollIndicator = false
        zoomScrollView.showsVerticalScrollIndicator = false
        zoomScrollView.delegate = self
        streamContainerView.insertSubview(zoomScrollView, at: 0)

        NSLayoutConstraint.activate([
            zoomScrollView.topAnchor.constraint(equalTo: streamContainerView.topAnchor),
            zoomScrollView.leadingAnchor.constraint(equalTo: streamContainerView.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: streamContainerView.trailingAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: streamContainerView.bottomAnchor)
        ])

        // Double-tap to zoom in/out
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        zoomScrollView.addGestureRecognizer(doubleTap)

        streamSpinner = UIActivityIndicatorView(style: .medium)
        streamSpinner.color = .white
        streamSpinner.translatesAutoresizingMaskIntoConstraints = false
        streamSpinner.hidesWhenStopped = true
        streamContainerView.addSubview(streamSpinner)

        NSLayoutConstraint.activate([
            streamSpinner.centerXAnchor.constraint(equalTo: streamContainerView.centerXAnchor),
            streamSpinner.centerYAnchor.constraint(equalTo: streamContainerView.centerYAnchor)
        ])

        backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        backButton.setTitle(" " + String(localized: "common.back", defaultValue: "Back", bundle: .macOSBridge), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        backButton.backgroundColor = UIColor(white: 0, alpha: 0.5)
        backButton.layer.cornerRadius = 14
        backButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 12)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backToGrid), for: .touchUpInside)
        streamContainerView.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: streamContainerView.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: streamContainerView.leadingAnchor, constant: 8)
        ])

        pinButton = UIButton(type: .custom)
        pinButton.setImage(UIImage(systemName: "pin")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        pinButton.backgroundColor = UIColor(white: 0, alpha: 0.5)
        pinButton.layer.cornerRadius = 14
        pinButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.addTarget(self, action: #selector(togglePin), for: .touchUpInside)
        streamContainerView.addSubview(pinButton)

        NSLayoutConstraint.activate([
            pinButton.topAnchor.constraint(equalTo: streamContainerView.topAnchor, constant: 8),
            pinButton.trailingAnchor.constraint(equalTo: streamContainerView.trailingAnchor, constant: -8)
        ])

        // Stream overlay stack (bottom-left, horizontal pills)
        streamOverlayStack = UIStackView()
        streamOverlayStack.axis = .horizontal
        streamOverlayStack.spacing = 6
        streamOverlayStack.alignment = .center
        streamOverlayStack.translatesAutoresizingMaskIntoConstraints = false
        streamContainerView.addSubview(streamOverlayStack)

        NSLayoutConstraint.activate([
            streamOverlayStack.leadingAnchor.constraint(equalTo: streamContainerView.leadingAnchor, constant: 8),
            streamOverlayStack.bottomAnchor.constraint(equalTo: streamContainerView.bottomAnchor, constant: -8)
        ])

        setupAudioControls()
    }

    // MARK: - Panel size

    func updatePanelSize(width: CGFloat, height: CGFloat, aspectRatio: CGFloat = 16.0 / 9.0, isStream: Bool = false, animated: Bool) {
        #if targetEnvironment(macCatalyst)
        if let windowScene = view.window?.windowScene {
            if isStream {
                let minWidth: CGFloat = 400
                let maxWidth: CGFloat = 1200
                windowScene.sizeRestrictions?.minimumSize = CGSize(width: minWidth, height: minWidth / aspectRatio)
                windowScene.sizeRestrictions?.maximumSize = CGSize(width: maxWidth, height: maxWidth / aspectRatio)
            } else {
                // Grid mode is freely resizable by corner drag; shared
                // constants keep these identical to the NSWindow min/max.
                windowScene.sizeRestrictions?.minimumSize = CGSize(width: CameraPanelBounds.minWidth, height: CameraPanelBounds.minHeight)
                windowScene.sizeRestrictions?.maximumSize = CGSize(width: CameraPanelBounds.maxWidth, height: CameraPanelBounds.maxHeight)
            }
        }
        #endif
        macOSController?.resizeCameraPanel(width: width, height: height, aspectRatio: aspectRatio, isStream: isStream, animated: animated)
    }

    func computeGridHeight() -> CGFloat {
        let count = cameraCount
        guard count > 0 else { return 150 }

        // Simulate the flow layout's row wrapping: tiles fill a row until the
        // next one doesn't fit; the row is as tall as its tallest tile.
        let contentWidth = gridContentWidth
        var rowHeights: [CGFloat] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for i in 0..<count {
            let size = tileSize(at: i)
            let needed = rowWidth == 0 ? size.width : rowWidth + Self.lineSpacing + size.width
            if needed > contentWidth + 0.5, rowWidth > 0 {
                rowHeights.append(rowHeight)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = needed
                rowHeight = max(rowHeight, size.height)
            }
        }
        rowHeights.append(rowHeight)

        // Cap at the window's maximum height (portrait cameras produce very
        // tall rows) – anything beyond scrolls. The AppKit side additionally
        // clamps to the actual screen.
        let maxHeight = CameraPanelBounds.maxHeight
        if rowHeights.count <= 3 {
            let total = rowHeights.reduce(0, +)
            return min(maxHeight, Self.sectionTop + total + CGFloat(rowHeights.count - 1) * Self.lineSpacing + Self.sectionBottom)
        } else {
            // Show first 3 rows plus half of the 4th to hint at scrollability
            let firstThree = rowHeights.prefix(3).reduce(0, +)
            return min(maxHeight, Self.sectionTop + firstThree + 2 * Self.lineSpacing + Self.lineSpacing + rowHeights[3] * 0.5)
        }
    }

    // MARK: - Public

    func stopAllStreams() {
        streamEngine.stopAll()
        activeStreamAccessory = nil
        activeLiveView = nil
        webrtcClient?.disconnect()
        webrtcClient = nil
        hlsPlayer?.stop()
        hlsPlayer = nil
        snapshotStreamTimer?.invalidate()
        snapshotStreamTimer = nil
        snapshotStreamImageView?.removeFromSuperview()
        snapshotStreamImageView = nil
        haSignaling?.disconnect()
        haSignaling = nil
        activeHACameraId = nil
        activeHAEntityId = nil
        stopSnapshotTimer()
    }

    @objc func togglePin() {
        isPinned.toggle()
        let iconName = isPinned ? "pin.fill" : "pin"
        pinButton.setImage(UIImage(systemName: iconName)?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        macOSController?.setCameraPanelPinned(isPinned)
    }
}

// MARK: - Zoom

extension CameraViewController {

    @objc func handleZoomDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScrollView.zoomScale > zoomScrollView.minimumZoomScale {
            zoomScrollView.setZoomScale(1.0, animated: true)
        } else {
            let location = gesture.location(in: zoomScrollView)
            let zoomScale: CGFloat = 2.0
            let size = CGSize(
                width: zoomScrollView.bounds.width / zoomScale,
                height: zoomScrollView.bounds.height / zoomScale
            )
            let origin = CGPoint(
                x: location.x - size.width / 2,
                y: location.y - size.height / 2
            )
            zoomScrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate (zoom)

extension CameraViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // Return whichever video view is currently showing
        if let webrtcView = webrtcClient?.videoView, webrtcView.superview == zoomScrollView {
            return webrtcView
        }
        if let hlsView = hlsPlayer?.view, hlsView.superview == zoomScrollView {
            return hlsView
        }
        if let snapshotView = snapshotStreamImageView, snapshotView.superview == zoomScrollView {
            return snapshotView
        }
        if let liveView = activeLiveView, liveView.superview == zoomScrollView {
            return liveView
        }
        return nil
    }
}

// MARK: - Associated keys

struct CameraAssociatedKeys {
    static var characteristic = "overlayCharacteristic"
    static var haEntityId = "overlayHAEntityId"
}
