//
//  CameraViewController+AspectRatio.swift
//  Itsyhome
//
//  Aspect ratio detection for camera views
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Aspect ratio detection

    /// Captures the camera view content and detects the actual aspect ratio by scanning for non-black content.
    func detectAspectRatio(from cameraView: HMCameraView, for uuid: UUID) {
        guard cameraAspectRatios[uuid] == nil else { return }

        let size = cameraView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            cameraView.drawHierarchy(in: cameraView.bounds, afterScreenUpdates: true)
        }

        guard let cgImage = image.cgImage else { return }
        guard let contentRect = findContentRect(in: cgImage) else { return }

        let contentWidth = CGFloat(contentRect.width)
        let contentHeight = CGFloat(contentRect.height)
        guard contentHeight > 0 else { return }

        let ratio = contentWidth / contentHeight

        // Ignore degenerate ratios (too narrow or too wide)
        guard ratio > 0.3, ratio < 4.0 else { return }

        // Skip if the content area is too small (likely no real content yet)
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        guard contentWidth > imageWidth * 0.2, contentHeight > imageHeight * 0.2 else { return }

        cameraAspectRatios[uuid] = ratio

        // Find camera name for logging
        let name = cameraAccessories.first { $0.uniqueIdentifier == uuid }?.name ?? uuid.uuidString
        NSLog("[Itsyhome] Camera \"%@\" aspect ratio: %.0fx%.0f (ratio=%.2f)", name, contentWidth, contentHeight, ratio)

        // Reload grid layout if we're in grid mode (not streaming)
        if activeStreamControl == nil {
            collectionView.collectionViewLayout.invalidateLayout()
            let height = computeGridHeight()
            updatePanelSize(width: Self.gridWidth, height: height, animated: false)
        }
    }

    /// Logs all detected camera aspect ratios.
    func logCameraAspectRatios() {
        for (uuid, ratio) in cameraAspectRatios {
            let name = cameraAccessories.first { $0.uniqueIdentifier == uuid }?.name ?? uuid.uuidString
            NSLog("[Itsyhome] Camera \"%@\" detected ratio=%.2f", name, ratio)
        }
    }

    // MARK: - Pixel scanning

    /// Scans a CGImage from edges inward to find the bounding rect of non-black content.
    /// Uses a brightness threshold to account for compression artifacts.
    private func findContentRect(in image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let threshold: UInt8 = 30 // brightness threshold to distinguish content from black bars

        func isNonBlack(x: Int, y: Int) -> Bool {
            let offset = y * bytesPerRow + x * bytesPerPixel
            // Check RGB channels (skip alpha if present)
            for c in 0..<min(3, bytesPerPixel) {
                if ptr[offset + c] > threshold { return true }
            }
            return false
        }

        func rowHasContent(_ y: Int) -> Bool {
            // Sample every 4th pixel for speed
            let step = max(1, width / 80)
            for x in stride(from: 0, to: width, by: step) {
                if isNonBlack(x: x, y: y) { return true }
            }
            return false
        }

        func columnHasContent(_ x: Int) -> Bool {
            let step = max(1, height / 80)
            for y in stride(from: 0, to: height, by: step) {
                if isNonBlack(x: x, y: y) { return true }
            }
            return false
        }

        // Find top edge
        var top = 0
        for y in 0..<height {
            if rowHasContent(y) { top = y; break }
        }

        // Find bottom edge
        var bottom = height - 1
        for y in stride(from: height - 1, through: 0, by: -1) {
            if rowHasContent(y) { bottom = y; break }
        }

        // Find left edge
        var left = 0
        for x in 0..<width {
            if columnHasContent(x) { left = x; break }
        }

        // Find right edge
        var right = width - 1
        for x in stride(from: width - 1, through: 0, by: -1) {
            if columnHasContent(x) { right = x; break }
        }

        let contentWidth = right - left + 1
        let contentHeight = bottom - top + 1
        guard contentWidth > 0, contentHeight > 0 else { return nil }

        return CGRect(x: left, y: top, width: contentWidth, height: contentHeight)
    }
}
