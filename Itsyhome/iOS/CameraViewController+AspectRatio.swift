//
//  CameraViewController+AspectRatio.swift
//  Itsyhome
//
//  Aspect ratio detection for camera views
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Aspect ratio

    private static let persistedRatiosKey = "CameraStreamAspectRatios"

    /// Loads persisted stream-confirmed aspect ratios from UserDefaults.
    func loadPersistedAspectRatios() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.persistedRatiosKey) as? [String: Double] else { return }
        for (key, value) in dict {
            guard let uuid = UUID(uuidString: key) else { continue }
            let ratio = CGFloat(value)
            cameraAspectRatios[uuid] = ratio
            streamConfirmedRatios.insert(uuid)
        }
    }

    private func persistStreamRatio(_ ratio: CGFloat, for uuid: UUID) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.persistedRatiosKey) as? [String: Double] ?? [:]
        dict[uuid.uuidString] = Double(ratio)
        UserDefaults.standard.set(dict, forKey: Self.persistedRatiosKey)
    }

    /// Caches aspect ratio from a UIImage (used for HA camera snapshots).
    func cacheAspectRatio(from image: UIImage, for uuid: UUID) {
        let ratio = image.size.width / image.size.height
        guard ratio > 0.3, ratio < 4.0 else { return }

        if let existing = cameraAspectRatios[uuid], abs(existing - ratio) < 0.05 { return }

        cameraAspectRatios[uuid] = ratio

        if activeStreamControl == nil && webrtcClient == nil {
            collectionView.collectionViewLayout.invalidateLayout()
            let height = computeGridHeight()
            updatePanelSize(width: Self.gridWidth, height: height, animated: false)
        }
    }

    /// Reads the aspect ratio from a camera source and caches it.
    /// When `fromStream` is true, the ratio is treated as authoritative and
    /// snapshots will not overwrite it.
    func cacheAspectRatio(from source: HMCameraSource, for uuid: UUID, fromStream: Bool = false) {
        let name = cameraAccessories.first { $0.uniqueIdentifier == uuid }?.name ?? uuid.uuidString
        let rawRatio = source.aspectRatio
        NSLog("[Itsyhome] Camera \"%@\" aspectRatio=%.4f stream=%d", name, rawRatio, fromStream ? 1 : 0)

        let ratio = CGFloat(rawRatio)
        guard ratio > 0.3, ratio < 4.0 else { return }

        // Don't let snapshots overwrite a ratio confirmed by a stream
        if !fromStream && streamConfirmedRatios.contains(uuid) { return }

        if let existing = cameraAspectRatios[uuid], abs(existing - ratio) < 0.05 {
            if fromStream { streamConfirmedRatios.insert(uuid) }
            return
        }

        cameraAspectRatios[uuid] = ratio
        if fromStream {
            streamConfirmedRatios.insert(uuid)
            persistStreamRatio(ratio, for: uuid)
        }
        NSLog("[Itsyhome] Camera \"%@\" cached ratio=%.2f stream=%d", name, ratio, fromStream ? 1 : 0)

        // Reload grid layout if we're in grid mode (not streaming)
        if activeStreamControl == nil && webrtcClient == nil {
            collectionView.collectionViewLayout.invalidateLayout()
            let height = computeGridHeight()
            updatePanelSize(width: Self.gridWidth, height: height, animated: false)
        }
    }
}
