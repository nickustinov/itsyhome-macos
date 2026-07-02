//
//  HLSStreamPlayer.swift
//  Itsyhome
//
//  HLS video player for cameras that don't support WebRTC
//

import UIKit
import AVFoundation
import AVKit
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HLSStream")

/// UIView subclass that uses AVPlayerLayer as its backing layer
private class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

final class HLSStreamPlayer: NSObject {

    // MARK: - Properties

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerView: UIView?
    private var statusObserver: NSKeyValueObservation?
    private var errorObserver: NSKeyValueObservation?
    private var didActivateAudioSession = false

    var onError: ((Error) -> Void)?
    var onReady: (() -> Void)?

    var view: UIView? { playerView }

    deinit {
        stop()
    }

    // MARK: - Playback

    func play(url: URL) {
        logger.info("Starting HLS playback: \(url.absoluteString)")

        activateAudioSessionIfNeeded()

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        // Observe player item status
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    logger.info("HLS player status: readyToPlay, rate=\(self?.player?.rate ?? -1)")
                    self?.onReady?()
                    // Ensure playback is happening
                    if self?.player?.rate == 0 {
                        logger.info("HLS player was paused, resuming...")
                        self?.player?.play()
                    }
                case .failed:
                    if let error = item.error {
                        logger.error("HLS stream failed: \(error.localizedDescription)")
                        self?.onError?(error)
                    }
                case .unknown:
                    logger.info("HLS player status: unknown")
                @unknown default:
                    break
                }
            }
        }

        // Observe errors
        errorObserver = playerItem.observe(\.error, options: [.new]) { [weak self] item, _ in
            if let error = item.error {
                DispatchQueue.main.async {
                    logger.error("HLS player error: \(error.localizedDescription)")
                    self?.onError?(error)
                }
            }
        }

        // Low latency settings - set on playerItem BEFORE creating player
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            playerItem.preferredForwardBufferDuration = 1.0  // Minimal buffer
        }

        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = false
        player?.automaticallyWaitsToMinimizeStalling = false

        // Create player view with custom layer class
        let view = PlayerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        playerLayer = view.playerLayer
        playerView = view

        // Start playback immediately - use playImmediately to skip waiting
        player?.playImmediately(atRate: 1.0)
        let initialRate = player?.rate ?? -1
        logger.info("HLS playImmediately called, rate=\(initialRate)")
    }

    func stop() {
        logger.info("Stopping HLS playback")
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        statusObserver?.invalidate()
        errorObserver?.invalidate()
        statusObserver = nil
        errorObserver = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        playerView = nil
        player = nil

        deactivateAudioSessionIfNeeded()
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    private func activateAudioSessionIfNeeded() {
        guard !didActivateAudioSession else { return }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: [.mixWithOthers])
            try audioSession.setActive(true)
            didActivateAudioSession = true
        } catch {
            logger.error("Failed to activate HLS audio session: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        guard didActivateAudioSession else { return }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            didActivateAudioSession = false
        } catch {
            logger.error("Failed to deactivate HLS audio session: \(error.localizedDescription)")
        }
    }
}
