//
//  CameraStreamEngine.swift
//  Itsyhome
//
//  Concurrent HomeKit camera stream lifecycle for the multi-stream grid
//

import UIKit
import HomeKit

protocol CameraStreamEngineDelegate: AnyObject {
    func streamEngine(_ engine: CameraStreamEngine, didStartStreamFor cameraId: UUID)
    func streamEngine(_ engine: CameraStreamEngine, didStopStreamFor cameraId: UUID, error: Error?)
}

/// Owns every live HomeKit camera stream and its render view, independent of
/// cell/view churn. Streams are reused across quick panel reopens (release
/// grace) because cameras hold a couple of session slots that drain slowly –
/// stop/start cycling stacks draining sessions until the camera degrades.
/// Each camera keeps one persistent HMCameraView that is reparented rather
/// than recreated: binding a running stream into a fresh view degrades
/// playback. The HMCameraStream is only adopted in the delegate callback –
/// the one on the control can be stale right after a stop.
final class CameraStreamEngine: NSObject {

    static let releaseGrace: TimeInterval = 10

    weak var delegate: CameraStreamEngineDelegate?

    private var streams: [UUID: HMCameraStream] = [:]
    private var controls: [UUID: HMCameraStreamControl] = [:]
    private var renderViews: [UUID: HMCameraView] = [:]
    private var releaseWorkItem: DispatchWorkItem?

    func stream(for cameraId: UUID) -> HMCameraStream? { streams[cameraId] }
    func control(for cameraId: UUID) -> HMCameraStreamControl? { controls[cameraId] }

    /// The camera's persistent render view, only once its stream is live.
    func liveRenderView(for cameraId: UUID) -> HMCameraView? {
        guard streams[cameraId] != nil else { return nil }
        return renderView(for: cameraId)
    }

    private func renderView(for cameraId: UUID) -> HMCameraView {
        if let view = renderViews[cameraId] { return view }
        let view = HMCameraView()
        view.isUserInteractionEnabled = false
        renderViews[cameraId] = view
        return view
    }

    func startStreams(for accessories: [HMAccessory]) {
        for accessory in accessories {
            startStream(for: accessory)
        }
    }

    func startStream(for accessory: HMAccessory) {
        cancelScheduledRelease()
        let cameraId = accessory.uniqueIdentifier
        guard controls[cameraId] == nil else { return } // live or negotiating
        guard let control = accessory.cameraProfiles?.first?.streamControl else { return }
        controls[cameraId] = control
        control.delegate = self
        control.startStream()
    }

    /// Stops streams for cameras that are no longer in the visible set
    /// (hidden by the user, removed from the home).
    func stopStreams(notIn keep: Set<UUID>) {
        for cameraId in controls.keys where !keep.contains(cameraId) {
            stopStream(for: cameraId)
        }
    }

    func setAudio(_ setting: HMCameraAudioStreamSetting, for cameraId: UUID) {
        streams[cameraId]?.updateAudioStreamSetting(setting) { _ in }
    }

    /// Keeps sessions alive briefly after the panel hides so reopening is
    /// instant and open/close churn doesn't accumulate draining sessions.
    func scheduleRelease() {
        releaseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.stopAll() }
        releaseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.releaseGrace, execute: item)
    }

    func cancelScheduledRelease() {
        releaseWorkItem?.cancel()
        releaseWorkItem = nil
    }

    func stopAll() {
        cancelScheduledRelease()
        for cameraId in Array(controls.keys) {
            stopStream(for: cameraId)
        }
    }

    private func stopStream(for cameraId: UUID) {
        guard let control = controls.removeValue(forKey: cameraId) else { return }
        control.delegate = nil
        control.stopStream()
        streams.removeValue(forKey: cameraId)
        renderViews[cameraId]?.cameraSource = nil
    }

    private func cameraId(for control: HMCameraStreamControl) -> UUID? {
        controls.first { $0.value === control }?.key
    }
}

// MARK: - HMCameraStreamControlDelegate

extension CameraStreamEngine: HMCameraStreamControlDelegate {

    func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        DispatchQueue.main.async {
            guard let cameraId = self.cameraId(for: cameraStreamControl),
                  let stream = cameraStreamControl.cameraStream else { return }
            self.streams[cameraId] = stream
            // Grid streams play muted; the detail view opts into audio.
            stream.updateAudioStreamSetting(.muted) { _ in }
            self.renderView(for: cameraId).cameraSource = stream
            self.delegate?.streamEngine(self, didStartStreamFor: cameraId)
        }
    }

    func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        DispatchQueue.main.async {
            guard let cameraId = self.cameraId(for: cameraStreamControl) else { return }
            self.controls.removeValue(forKey: cameraId)
            self.streams.removeValue(forKey: cameraId)
            self.renderViews[cameraId]?.cameraSource = nil
            self.delegate?.streamEngine(self, didStopStreamFor: cameraId, error: error)
        }
    }
}
