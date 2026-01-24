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
}

class CameraViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var emptyLabel: UILabel!
    private var streamContainerView: UIView!
    private var streamCameraView: HMCameraView!
    private var streamSpinner: UIActivityIndicatorView!
    private var backButton: UIButton!
    private var streamOverlayStack: UIStackView!

    private static let gridWidth: CGFloat = 300
    private static let streamWidth: CGFloat = 530
    private static let streamHeight: CGFloat = 298 // 16:9

    private static let sectionTop: CGFloat = 15
    private static let sectionBottom: CGFloat = 15
    private static let sectionSide: CGFloat = 12
    private static let lineSpacing: CGFloat = 8
    private static let labelHeight: CGFloat = 0

    private var cameraAccessories: [HMAccessory] = []
    private var snapshotControls: [UUID: HMCameraSnapshotControl] = [:]
    private var activeStreamControl: HMCameraStreamControl?
    private var activeStreamAccessory: HMAccessory?
    private var snapshotTimer: Timer?
    private var timestampTimer: Timer?
    private var snapshotTimestamps: [UUID: Date] = [:]
    private var hasLoadedInitialData = false

    /// Resolved overlay data per camera: [cameraUUID: [(characteristic, service name, service type)]]
    private var overlayData: [UUID: [(characteristic: HMCharacteristic, name: String, serviceType: String)]] = [:]

    private var macOSController: iOS2Mac? {
        (UIApplication.shared.delegate as? AppDelegate)?.macOSController
    }

    private var homeKitManager: HomeKitManager? {
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
    }

    @objc private func preferencesDidChange() {
        // Only reload grid if not currently streaming
        guard activeStreamControl == nil else { return }
        loadCameras()
        emptyLabel.isHidden = !cameraAccessories.isEmpty
        collectionView.isHidden = cameraAccessories.isEmpty
        collectionView.reloadData()

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
    }

    @objc private func panelDidShow() {
        takeAllSnapshots()
        // Ensure correct size when panel re-appears
        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
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

        // Ensure correct window size now that view.window exists
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
    }

    // MARK: - Camera loading

    private func loadCameras() {
        guard let manager = homeKitManager else { return }

        let allCameras = manager.cameraAccessories
        let homeId = manager.selectedHomeIdentifier?.uuidString ?? ""

        // Read order and hidden from UserDefaults
        let orderKey = "cameraOrder_\(homeId)"
        let hiddenKey = "hiddenCameraIds_\(homeId)"
        let order = UserDefaults.standard.stringArray(forKey: orderKey) ?? []
        let hiddenIds = Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])

        // Apply order
        var ordered: [HMAccessory] = []
        var remaining = allCameras
        for id in order {
            if let uuid = UUID(uuidString: id),
               let index = remaining.firstIndex(where: { $0.uniqueIdentifier == uuid }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        ordered.append(contentsOf: remaining)

        // Filter hidden
        cameraAccessories = ordered.filter { !hiddenIds.contains($0.uniqueIdentifier.uuidString) }

        // Resolve overlay data
        resolveOverlayData(homeId: homeId)

        let height = computeGridHeight()
        macOSController?.resizeCameraPanel(width: Self.gridWidth, height: height, animated: false)
    }

    private func resolveOverlayData(homeId: String) {
        overlayData = [:]
        let overlayKey = "cameraOverlayAccessories_\(homeId)"
        guard let data = UserDefaults.standard.data(forKey: overlayKey),
              let mapping = try? JSONDecoder().decode([String: [String]].self, from: data),
              let home = homeKitManager?.selectedHome else { return }

        for camera in cameraAccessories {
            let cameraId = camera.uniqueIdentifier.uuidString
            guard let serviceIds = mapping[cameraId], !serviceIds.isEmpty else { continue }

            var resolved: [(characteristic: HMCharacteristic, name: String, serviceType: String)] = []
            for serviceIdStr in serviceIds {
                guard let serviceUUID = UUID(uuidString: serviceIdStr) else { continue }
                if let (characteristic, name, type) = findToggleCharacteristic(serviceUUID: serviceUUID, in: home) {
                    resolved.append((characteristic: characteristic, name: name, serviceType: type))
                }
            }
            if !resolved.isEmpty {
                overlayData[camera.uniqueIdentifier] = resolved
            }
        }

        // Read fresh values for all overlay characteristics
        readOverlayCharacteristicValues()
    }

    private func readOverlayCharacteristicValues() {
        for (_, items) in overlayData {
            for item in items {
                item.characteristic.readValue { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.collectionView.reloadData()
                    }
                }
            }
        }
    }

    private func findToggleCharacteristic(serviceUUID: UUID, in home: HMHome) -> (HMCharacteristic, String, String)? {
        for accessory in home.accessories {
            for service in accessory.services {
                if service.uniqueIdentifier == serviceUUID {
                    let type = service.serviceType
                    let name = service.name

                    // Find the primary toggle characteristic
                    let powerState = service.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }
                    if let c = powerState { return (c, name, type) }

                    let targetDoor = service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetDoorState }
                    if let c = targetDoor { return (c, name, type) }

                    return nil
                }
            }
        }
        return nil
    }

    private func updatePanelSize(width: CGFloat, height: CGFloat, animated: Bool) {
        #if targetEnvironment(macCatalyst)
        if let windowScene = view.window?.windowScene {
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: width, height: height)
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: width, height: height)
        }
        #endif
        macOSController?.resizeCameraPanel(width: width, height: height, animated: animated)
    }

    private func computeGridHeight() -> CGFloat {
        let count = cameraAccessories.count
        guard count > 0 else { return 150 }

        let cellWidth = Self.gridWidth - Self.sectionSide * 2
        let cellHeight = cellWidth * 9.0 / 16.0 + Self.labelHeight

        if count <= 3 {
            // Show all cameras fully
            return Self.sectionTop + CGFloat(count) * cellHeight + CGFloat(count - 1) * Self.lineSpacing + Self.sectionBottom
        } else {
            // Show 3 full + half of 4th to hint at scrollability
            return Self.sectionTop + 3 * cellHeight + 2 * Self.lineSpacing + Self.lineSpacing + cellHeight * 0.5
        }
    }

    // MARK: - Snapshots

    private func takeAllSnapshots() {
        for accessory in cameraAccessories {
            guard let profile = accessory.cameraProfiles?.first,
                  let snapshotControl = profile.snapshotControl else { continue }

            snapshotControl.delegate = self
            snapshotControls[accessory.uniqueIdentifier] = snapshotControl
            snapshotControl.takeSnapshot()
        }
    }

    private func startSnapshotTimer() {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.takeAllSnapshots()
        }
    }

    private func stopSnapshotTimer() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    private func startTimestampTimer() {
        timestampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimestampLabels()
        }
    }

    private func stopTimestampTimer() {
        timestampTimer?.invalidate()
        timestampTimer = nil
    }

    private func updateTimestampLabels() {
        for cell in collectionView.visibleCells {
            guard let snapshotCell = cell as? CameraSnapshotCell,
                  let indexPath = collectionView.indexPath(for: cell),
                  indexPath.item < cameraAccessories.count else { continue }
            let uuid = cameraAccessories[indexPath.item].uniqueIdentifier
            snapshotCell.updateTimestamp(since: snapshotTimestamps[uuid])
        }
    }

    // MARK: - Streaming

    private func startStream(for accessory: HMAccessory) {
        guard let profile = accessory.cameraProfiles?.first,
              let streamControl = profile.streamControl else { return }

        activeStreamAccessory = accessory

        streamContainerView.isHidden = false
        streamCameraView.isHidden = true
        streamSpinner.startAnimating()
        collectionView.isHidden = true
        stopSnapshotTimer()

        updatePanelSize(width: Self.streamWidth, height: Self.streamHeight, animated: true)
        updateStreamOverlays(for: accessory)

        activeStreamControl = streamControl
        streamControl.delegate = self
        streamControl.startStream()
    }

    private func updateStreamOverlays(for accessory: HMAccessory) {
        streamOverlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let items = overlayData[accessory.uniqueIdentifier] else { return }

        for item in items {
            let pill = createOverlayPill(characteristic: item.characteristic, name: item.name, serviceType: item.serviceType, size: .large)
            streamOverlayStack.addArrangedSubview(pill)
        }

        // Read current values
        for item in items {
            item.characteristic.readValue { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshStreamOverlayStates()
                }
            }
        }
    }

    private func refreshStreamOverlayStates() {
        guard let accessory = activeStreamAccessory,
              let items = overlayData[accessory.uniqueIdentifier] else { return }

        for (index, pill) in streamOverlayStack.arrangedSubviews.enumerated() {
            guard index < items.count else { break }
            let isOn = characteristicIsOn(items[index].characteristic)
            updatePillState(pill, isOn: isOn)
        }
    }

    @objc private func backToGrid() {
        activeStreamControl?.stopStream()
        activeStreamControl = nil
        activeStreamAccessory = nil
        streamCameraView.cameraSource = nil
        streamCameraView.isHidden = false
        streamSpinner.stopAnimating()
        streamContainerView.isHidden = true
        streamOverlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        collectionView.isHidden = cameraAccessories.isEmpty
        collectionView.setContentOffset(.zero, animated: false)

        let height = computeGridHeight()
        updatePanelSize(width: Self.gridWidth, height: height, animated: false)
        startSnapshotTimer()
    }

    // MARK: - Overlay pills

    private enum PillSize {
        case large  // Stream view: matches Back button (28px, font 13)
        case small  // Grid view: compact (24px, font 10)
    }

    private func createOverlayPill(characteristic: HMCharacteristic, name: String, serviceType: String, size: PillSize) -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false

        let isLarge = size == .large
        let pillHeight: CGFloat = isLarge ? 28 : 24
        let iconSize: CGFloat = isLarge ? 14 : 12
        let fontSize: CGFloat = isLarge ? 13 : 10
        let leadingPad: CGFloat = isLarge ? 10 : 6
        let trailingPad: CGFloat = isLarge ? 12 : 6
        let iconLabelGap: CGFloat = isLarge ? 4 : 3

        pill.layer.cornerRadius = pillHeight / 2

        let iconImage = iconForServiceType(serviceType)
        let iconView = UIImageView(image: iconImage)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 1
        pill.addSubview(iconView)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: fontSize, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 2
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: pillHeight),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: leadingPad),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: iconLabelGap),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -trailingPad)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(overlayPillTapped(_:)))
        pill.addGestureRecognizer(tap)
        pill.isUserInteractionEnabled = true

        objc_setAssociatedObject(pill, &AssociatedKeys.characteristic, characteristic, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let isOn = characteristicIsOn(characteristic)
        updatePillState(pill, isOn: isOn)

        return pill
    }

    private func updatePillState(_ pill: UIView, isOn: Bool) {
        if isOn {
            pill.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
            if let icon = pill.viewWithTag(1) as? UIImageView { icon.tintColor = .black }
            if let label = pill.viewWithTag(2) as? UILabel { label.textColor = .black }
        } else {
            pill.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            if let icon = pill.viewWithTag(1) as? UIImageView { icon.tintColor = .white }
            if let label = pill.viewWithTag(2) as? UILabel { label.textColor = .white }
        }
    }

    @objc private func overlayPillTapped(_ gesture: UITapGestureRecognizer) {
        guard let pill = gesture.view,
              let characteristic = objc_getAssociatedObject(pill, &AssociatedKeys.characteristic) as? HMCharacteristic else { return }

        let isOn = characteristicIsOn(characteristic)
        let newValue = toggleValue(for: characteristic, currentlyOn: isOn)

        // Optimistic update
        updatePillState(pill, isOn: !isOn)

        characteristic.writeValue(newValue) { [weak self] error in
            DispatchQueue.main.async {
                if error != nil {
                    self?.updatePillState(pill, isOn: isOn)
                } else {
                    self?.collectionView.reloadData()
                    // Re-read after delay for garage doors (state transitions asynchronously)
                    if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.readOverlayCharacteristicValues()
                        }
                    }
                }
            }
        }
    }

    private func characteristicIsOn(_ characteristic: HMCharacteristic) -> Bool {
        // Door state must be checked as Int first (NSNumber bridges to Bool incorrectly)
        if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState {
            let intVal = (characteristic.value as? NSNumber)?.intValue ?? 1
            // 0=open=ON, 1=closed=OFF
            return intVal == 0
        }
        if let intVal = (characteristic.value as? NSNumber)?.intValue {
            return intVal != 0
        }
        return false
    }

    private func toggleValue(for characteristic: HMCharacteristic, currentlyOn: Bool) -> Any {
        if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState {
            // currentlyOn means door is open (0), so toggle to closed (1)
            return currentlyOn ? 1 : 0
        }
        return currentlyOn ? false : true
    }

    private func iconForServiceType(_ type: String) -> UIImage? {
        let name: String
        switch type {
        case HMServiceTypeLightbulb: name = "lightbulb.fill"
        case HMServiceTypeSwitch: name = "power"
        case HMServiceTypeOutlet: name = "poweroutlet.type.b.fill"
        case HMServiceTypeGarageDoorOpener: name = "door.garage.closed"
        default: name = "bolt.fill"
        }
        return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Public

    func stopAllStreams() {
        activeStreamControl?.stopStream()
        activeStreamControl = nil
        activeStreamAccessory = nil
        stopSnapshotTimer()
    }
}

// MARK: - Associated keys

private struct AssociatedKeys {
    static var characteristic = "overlayCharacteristic"
}

// MARK: - UICollectionViewDataSource

extension CameraViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cameraAccessories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraSnapshotCell.reuseId, for: indexPath) as! CameraSnapshotCell
        let accessory = cameraAccessories[indexPath.item]
        cell.configure(name: accessory.name)
        cell.updateTimestamp(since: snapshotTimestamps[accessory.uniqueIdentifier])

        if let snapshotControl = snapshotControls[accessory.uniqueIdentifier],
           let snapshot = snapshotControl.mostRecentSnapshot {
            cell.cameraView.cameraSource = snapshot
        }

        let items = overlayData[accessory.uniqueIdentifier] ?? []
        cell.configureOverlays(items: items, target: self, action: #selector(overlayPillTapped(_:)))

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension CameraViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let accessory = cameraAccessories[indexPath.item]
        startStream(for: accessory)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CameraViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = CameraViewController.gridWidth - CameraViewController.sectionSide * 2
        let height = width * 9.0 / 16.0 + CameraViewController.labelHeight
        return CGSize(width: width, height: height)
    }
}

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

// MARK: - CameraSnapshotCell

private class CameraSnapshotCell: UICollectionViewCell {
    static let reuseId = "CameraSnapshotCell"

    let cameraView = HMCameraView()
    private let nameLabel = UILabel()
    private let timestampLabel = UILabel()
    private var overlayStack: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        contentView.layer.cornerRadius = 6
        contentView.clipsToBounds = true

        cameraView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.isUserInteractionEnabled = false
        contentView.addSubview(cameraView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        nameLabel.layer.shadowOpacity = 0.8
        nameLabel.layer.shadowRadius = 2
        contentView.addSubview(nameLabel)

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        timestampLabel.textColor = .white
        timestampLabel.layer.shadowColor = UIColor.black.cgColor
        timestampLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        timestampLabel.layer.shadowOpacity = 0.8
        timestampLabel.layer.shadowRadius = 2
        timestampLabel.textAlignment = .right
        contentView.addSubview(timestampLabel)

        overlayStack = UIStackView()
        overlayStack.axis = .horizontal
        overlayStack.spacing = 4
        overlayStack.alignment = .center
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlayStack)

        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 6),

            timestampLabel.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 4),
            timestampLabel.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -6),

            overlayStack.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 4),
            overlayStack.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -4)
        ])
    }

    func configure(name: String) {
        nameLabel.text = name
    }

    func updateTimestamp(since date: Date?) {
        guard let date = date else {
            timestampLabel.text = nil
            return
        }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            timestampLabel.text = "\(seconds)s"
        } else {
            timestampLabel.text = "\(seconds / 60)m"
        }
    }

    func configureOverlays(items: [(characteristic: HMCharacteristic, name: String, serviceType: String)], target: AnyObject, action: Selector) {
        overlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for item in items {
            let pill = createGridPill(characteristic: item.characteristic, name: item.name, serviceType: item.serviceType, target: target, action: action)
            overlayStack.addArrangedSubview(pill)
        }
    }

    private func createGridPill(characteristic: HMCharacteristic, name: String, serviceType: String, target: AnyObject, action: Selector) -> UIView {
        let pill = UIView()
        pill.layer.cornerRadius = 12
        pill.translatesAutoresizingMaskIntoConstraints = false

        let iconImage = iconForType(serviceType)
        let iconView = UIImageView(image: iconImage)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 1
        pill.addSubview(iconView)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 2
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 24),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])

        let tap = UITapGestureRecognizer(target: target, action: action)
        pill.addGestureRecognizer(tap)
        pill.isUserInteractionEnabled = true

        objc_setAssociatedObject(pill, &AssociatedKeys.characteristic, characteristic, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Determine state and apply colors
        let isOn = characteristicIsOn(characteristic)
        if isOn {
            pill.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
            iconView.tintColor = .black
            label.textColor = .black
        } else {
            pill.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            iconView.tintColor = .white
            label.textColor = .white
        }

        return pill
    }

    private func characteristicIsOn(_ characteristic: HMCharacteristic) -> Bool {
        if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState {
            let intVal = (characteristic.value as? NSNumber)?.intValue ?? 1
            return intVal == 0
        }
        if let intVal = (characteristic.value as? NSNumber)?.intValue {
            return intVal != 0
        }
        return false
    }

    private func iconForType(_ type: String) -> UIImage? {
        let name: String
        switch type {
        case HMServiceTypeLightbulb: name = "lightbulb.fill"
        case HMServiceTypeSwitch: name = "power"
        case HMServiceTypeOutlet: name = "poweroutlet.type.b.fill"
        case HMServiceTypeGarageDoorOpener: name = "door.garage.closed"
        default: name = "bolt.fill"
        }
        return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cameraView.cameraSource = nil
        nameLabel.text = nil
        timestampLabel.text = nil
        overlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}
