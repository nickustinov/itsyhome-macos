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
    var streamCameraView: HMCameraView!
    var streamSpinner: UIActivityIndicatorView!
    var backButton: UIButton!
    var pinButton: UIButton!
    var streamOverlayStack: UIStackView!

    // Audio controls
    var audioControlsStack: UIStackView!
    var muteButton: UIButton!
    var talkButton: UIButton!

    // MARK: - Layout constants

    static let gridWidth: CGFloat = 300
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
    var activeStreamControl: HMCameraStreamControl?
    var activeStreamAccessory: HMAccessory?

    // Audio state
    var isMuted: Bool = false
    var isTalking: Bool = false
    var microphoneControl: HMCameraAudioControl?
    var speakerControl: HMCameraAudioControl?
    var snapshotTimer: Timer?
    var timestampTimer: Timer?
    var snapshotTimestamps: [UUID: Date] = [:]
    var cameraAspectRatios: [UUID: CGFloat] = [:]
    var isPinned = false
    var hasLoadedInitialData = false

    /// Resolved overlay data per camera: [cameraUUID: [(characteristic, service name, service type)]]
    var overlayData: [UUID: [(characteristic: HMCharacteristic, name: String, serviceType: String)]] = [:]

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
    }

    @objc private func preferencesDidChange() {
        guard activeStreamControl == nil else { return }
        loadCameras()
        emptyLabel.isHidden = !cameraAccessories.isEmpty
        collectionView.isHidden = cameraAccessories.isEmpty
        collectionView.reloadData()

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
    }

    @objc private func homeDidChange() {
        if activeStreamControl != nil {
            backToGrid()
        }
        loadCameras()
        emptyLabel.isHidden = !cameraAccessories.isEmpty
        collectionView.isHidden = cameraAccessories.isEmpty
        collectionView.reloadData()

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
    }

    @objc private func panelDidShow() {
        takeAllSnapshots()
        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
    }

    @objc private func panelDidHide() {
        if activeStreamControl != nil {
            backToGrid()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !hasLoadedInitialData && !cameraAccessories.isEmpty {
            hasLoadedInitialData = true
            emptyLabel.isHidden = !cameraAccessories.isEmpty
            collectionView.isHidden = cameraAccessories.isEmpty
            collectionView.reloadData()
            takeAllSnapshots()
        }

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)

        collectionView.setContentOffset(.zero, animated: false)
        startSnapshotTimer()
        startTimestampTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSnapshotTimer()
        stopTimestampTimer()
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
        emptyLabel.text = "No cameras found"
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

        streamSpinner = UIActivityIndicatorView(style: .medium)
        streamSpinner.color = .white
        streamSpinner.translatesAutoresizingMaskIntoConstraints = false
        streamSpinner.hidesWhenStopped = true
        streamContainerView.addSubview(streamSpinner)

        NSLayoutConstraint.activate([
            streamSpinner.centerXAnchor.constraint(equalTo: streamContainerView.centerXAnchor),
            streamSpinner.centerYAnchor.constraint(equalTo: streamContainerView.centerYAnchor)
        ])

        streamCameraView = HMCameraView()
        streamCameraView.translatesAutoresizingMaskIntoConstraints = false
        streamCameraView.isUserInteractionEnabled = false
        streamContainerView.addSubview(streamCameraView)

        NSLayoutConstraint.activate([
            streamCameraView.topAnchor.constraint(equalTo: streamContainerView.topAnchor),
            streamCameraView.leadingAnchor.constraint(equalTo: streamContainerView.leadingAnchor),
            streamCameraView.trailingAnchor.constraint(equalTo: streamContainerView.trailingAnchor),
            streamCameraView.bottomAnchor.constraint(equalTo: streamContainerView.bottomAnchor)
        ])

        backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        backButton.setTitle(" Back", for: .normal)
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

    func updatePanelSize(width: CGFloat, height: CGFloat, aspectRatio: CGFloat = 16.0 / 9.0, cameraId: String = "", animated: Bool) {
        #if targetEnvironment(macCatalyst)
        if let windowScene = view.window?.windowScene {
            let isStreamMode = width > 400
            if isStreamMode {
                let minWidth: CGFloat = 400
                let maxWidth: CGFloat = 1200
                windowScene.sizeRestrictions?.minimumSize = CGSize(width: minWidth, height: minWidth / aspectRatio)
                windowScene.sizeRestrictions?.maximumSize = CGSize(width: maxWidth, height: maxWidth / aspectRatio)
            } else {
                windowScene.sizeRestrictions?.minimumSize = CGSize(width: width, height: height)
                windowScene.sizeRestrictions?.maximumSize = CGSize(width: width, height: height)
            }
        }
        #endif
        macOSController?.resizeCameraPanel(width: width, height: height, aspectRatio: aspectRatio, cameraId: cameraId, animated: animated)
    }

    func computeGridHeight() -> CGFloat {
        let count = cameraAccessories.count
        guard count > 0 else { return 150 }

        let cellWidth = Self.gridWidth - Self.sectionSide * 2

        // Compute individual cell heights based on detected aspect ratios
        var cellHeights: [CGFloat] = []
        for accessory in cameraAccessories {
            let ratio = cameraAspectRatios[accessory.uniqueIdentifier] ?? Self.defaultAspectRatio
            cellHeights.append(cellWidth / ratio + Self.labelHeight)
        }

        if count <= 3 {
            let totalCells = cellHeights.reduce(0, +)
            return Self.sectionTop + totalCells + CGFloat(count - 1) * Self.lineSpacing + Self.sectionBottom
        } else {
            // Show first 3 cells plus half of the 4th to hint at scrollability
            let firstThree = cellHeights.prefix(3).reduce(0, +)
            let fourth = cellHeights.count > 3 ? cellHeights[3] : cellHeights.last!
            return Self.sectionTop + firstThree + 2 * Self.lineSpacing + Self.lineSpacing + fourth * 0.5
        }
    }

    // MARK: - Public

    func stopAllStreams() {
        activeStreamControl?.stopStream()
        activeStreamControl = nil
        activeStreamAccessory = nil
        stopSnapshotTimer()
    }

    @objc func togglePin() {
        isPinned.toggle()
        let iconName = isPinned ? "pin.fill" : "pin"
        pinButton.setImage(UIImage(systemName: iconName)?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        macOSController?.setCameraPanelPinned(isPinned)
    }
}

// MARK: - Associated keys

struct CameraAssociatedKeys {
    static var characteristic = "overlayCharacteristic"
}
