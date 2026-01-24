//
//  CameraViewController.swift
//  Itsyhome
//
//  Grid of camera snapshots with live streaming on tap
//

import UIKit
import HomeKit

class CameraViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var emptyLabel: UILabel!
    private var streamContainerView: UIView!
    private var streamCameraView: HMCameraView!
    private var streamErrorLabel: UILabel!
    private var backButton: UIButton!

    private var cameraAccessories: [HMAccessory] = []
    private var snapshotControls: [UUID: HMCameraSnapshotControl] = [:]
    private var activeStreamControl: HMCameraStreamControl?
    private var snapshotTimer: Timer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupEmptyState()
        setupStreamView()
        loadCameras()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSnapshotTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSnapshotTimer()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CameraSnapshotCell.self, forCellWithReuseIdentifier: CameraSnapshotCell.reuseId)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyLabel = UILabel()
        emptyLabel.text = "No cameras found"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 18, weight: .medium)
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

        streamCameraView = HMCameraView()
        streamCameraView.translatesAutoresizingMaskIntoConstraints = false
        streamContainerView.addSubview(streamCameraView)

        NSLayoutConstraint.activate([
            streamCameraView.topAnchor.constraint(equalTo: streamContainerView.topAnchor),
            streamCameraView.leadingAnchor.constraint(equalTo: streamContainerView.leadingAnchor),
            streamCameraView.trailingAnchor.constraint(equalTo: streamContainerView.trailingAnchor),
            streamCameraView.bottomAnchor.constraint(equalTo: streamContainerView.bottomAnchor)
        ])

        streamErrorLabel = UILabel()
        streamErrorLabel.textColor = .white
        streamErrorLabel.font = .systemFont(ofSize: 16, weight: .medium)
        streamErrorLabel.textAlignment = .center
        streamErrorLabel.numberOfLines = 0
        streamErrorLabel.translatesAutoresizingMaskIntoConstraints = false
        streamErrorLabel.isHidden = true
        streamContainerView.addSubview(streamErrorLabel)

        NSLayoutConstraint.activate([
            streamErrorLabel.centerXAnchor.constraint(equalTo: streamContainerView.centerXAnchor),
            streamErrorLabel.centerYAnchor.constraint(equalTo: streamContainerView.centerYAnchor),
            streamErrorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: streamContainerView.leadingAnchor, constant: 20),
            streamErrorLabel.trailingAnchor.constraint(lessThanOrEqualTo: streamContainerView.trailingAnchor, constant: -20)
        ])

        backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backToGrid), for: .touchUpInside)
        streamContainerView.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: streamContainerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: streamContainerView.leadingAnchor, constant: 16)
        ])
    }

    // MARK: - Camera loading

    private func loadCameras() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let homeKitManager = appDelegate.homeKitManager else { return }

        cameraAccessories = homeKitManager.cameraAccessories
        emptyLabel.isHidden = !cameraAccessories.isEmpty
        collectionView.isHidden = cameraAccessories.isEmpty
        collectionView.reloadData()
        takeAllSnapshots()
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

    // MARK: - Streaming

    private func startStream(for accessory: HMAccessory) {
        guard let profile = accessory.cameraProfiles?.first,
              let streamControl = profile.streamControl else {
            showStreamError("Camera does not support streaming")
            return
        }

        streamContainerView.isHidden = false
        collectionView.isHidden = true
        streamErrorLabel.isHidden = true
        stopSnapshotTimer()

        activeStreamControl = streamControl
        streamControl.delegate = self
        streamControl.startStream()
    }

    @objc private func backToGrid() {
        activeStreamControl?.stopStream()
        activeStreamControl = nil
        streamCameraView.cameraSource = nil
        streamContainerView.isHidden = true
        streamErrorLabel.isHidden = true
        collectionView.isHidden = cameraAccessories.isEmpty
        startSnapshotTimer()
    }

    private func showStreamError(_ message: String) {
        streamErrorLabel.text = message
        streamErrorLabel.isHidden = false
    }

    // MARK: - Public

    func stopAllStreams() {
        activeStreamControl?.stopStream()
        activeStreamControl = nil
        stopSnapshotTimer()
    }
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

        if let snapshotControl = snapshotControls[accessory.uniqueIdentifier],
           let snapshot = snapshotControl.mostRecentSnapshot {
            cell.cameraView.cameraSource = snapshot
        }

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
        let insets: CGFloat = 16 * 2
        let spacing: CGFloat = 12
        let availableWidth = collectionView.bounds.width - insets
        let tileWidth: CGFloat = 280
        let columns = max(1, floor((availableWidth + spacing) / (tileWidth + spacing)))
        let width = (availableWidth - spacing * (columns - 1)) / columns
        let height = width * 9.0 / 16.0 + 32 // 16:9 aspect ratio + label height
        return CGSize(width: width, height: height)
    }
}

// MARK: - HMCameraSnapshotControlDelegate

extension CameraViewController: HMCameraSnapshotControlDelegate {
    func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?) {
        guard error == nil else { return }
        // Find which accessory this snapshot belongs to and reload its cell
        for (index, accessory) in cameraAccessories.enumerated() {
            if snapshotControls[accessory.uniqueIdentifier] === cameraSnapshotControl {
                let indexPath = IndexPath(item: index, section: 0)
                DispatchQueue.main.async {
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
            self.streamCameraView.cameraSource = cameraStreamControl.cameraStream
            self.streamErrorLabel.isHidden = true
        }
    }

    func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.showStreamError("Stream stopped: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CameraSnapshotCell

private class CameraSnapshotCell: UICollectionViewCell {
    static let reuseId = "CameraSnapshotCell"

    let cameraView = HMCameraView()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        cameraView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cameraView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -4),

            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            nameLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(name: String) {
        nameLabel.text = name
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cameraView.cameraSource = nil
        nameLabel.text = nil
    }
}
