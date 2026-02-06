//
//  WebRTCStreamClient.swift
//  Itsyhome
//
//  WebRTC peer connection wrapper for Home Assistant camera streaming
//

import UIKit
import LiveKitWebRTC
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "WebRTCStream")

final class WebRTCStreamClient: NSObject {

    // MARK: - Properties

    private var peerConnection: LKRTCPeerConnection?
    private var videoTrack: LKRTCVideoTrack?
    private let factory: LKRTCPeerConnectionFactory

    private(set) var videoView: UIView?
    var onDisconnect: (() -> Void)?

    private var entityId: String?
    private var signaling: HACameraSignaling?

    // MARK: - Initialization

    override init() {
        LKRTCInitializeSSL()
        let decoderFactory = LKRTCDefaultVideoDecoderFactory()
        let encoderFactory = LKRTCDefaultVideoEncoderFactory()
        factory = LKRTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        super.init()
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    func connect(entityId: String, signaling: HACameraSignaling) async throws {
        self.entityId = entityId
        self.signaling = signaling

        // Configure ICE servers (STUN only — HA WebRTC typically uses direct connectivity)
        let stunServer = LKRTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        let config = LKRTCConfiguration()
        config.iceServers = [stunServer]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw HomeAssistantClientError.connectionFailed("Failed to create RTCPeerConnection")
        }
        peerConnection = pc

        // Add receive-only video transceiver
        let videoTransceiverInit = LKRTCRtpTransceiverInit()
        videoTransceiverInit.direction = .recvOnly
        pc.addTransceiver(of: .video, init: videoTransceiverInit)

        // Add receive-only audio transceiver
        let audioTransceiverInit = LKRTCRtpTransceiverInit()
        audioTransceiverInit.direction = .recvOnly
        pc.addTransceiver(of: .audio, init: audioTransceiverInit)

        // Create SDP offer
        let offerConstraints = LKRTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveVideo": "true",
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )

        let offer = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LKRTCSessionDescription, Error>) in
            pc.offer(for: offerConstraints) { sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sdp = sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: HomeAssistantClientError.invalidResponse)
                }
            }
        }

        // Set local description
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setLocalDescription(offer) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        logger.info("Sending WebRTC offer to HA for \(entityId)")

        // Send offer to HA and get answer
        let answerSDP = try await signaling.sendWebRTCOffer(entityId: entityId, offer: offer.sdp)

        let answer = LKRTCSessionDescription(type: .answer, sdp: answerSDP)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setRemoteDescription(answer) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        logger.info("WebRTC connection established for \(entityId)")

        // Create video view (Metal-based renderer)
        await MainActor.run {
            let metalView = LKRTCMTLVideoView(frame: .zero)
            metalView.videoContentMode = .scaleAspectFit
            self.videoView = metalView
            self.videoTrack?.add(metalView)
        }
    }

    // MARK: - Audio control

    func setAudioEnabled(_ enabled: Bool) {
        guard let pc = peerConnection else { return }
        for transceiver in pc.transceivers {
            if transceiver.mediaType == .audio,
               let audioTrack = transceiver.receiver.track as? LKRTCAudioTrack {
                audioTrack.isEnabled = enabled
            }
        }

        // Deactivate/activate audio session to restore system volume when muted
        let audioSession = LKRTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        if enabled {
            try? audioSession.setActive(true)
        } else {
            try? audioSession.setActive(false)
        }
        audioSession.unlockForConfiguration()
    }

    // MARK: - Disconnection

    func disconnect() {
        videoTrack = nil
        peerConnection?.close()
        peerConnection = nil
        videoView = nil
    }
}

// MARK: - LKRTCPeerConnectionDelegate

extension WebRTCStreamClient: LKRTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {
        logger.debug("Signaling state: \(String(describing: stateChanged))")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
        logger.info("Stream added with \(stream.videoTracks.count) video tracks")
        if let track = stream.videoTracks.first {
            DispatchQueue.main.async { [weak self] in
                self?.videoTrack = track
                if let metalView = self?.videoView as? LKRTCMTLVideoView {
                    track.add(metalView)
                }
            }
        }
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {
        logger.info("Stream removed")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {
        logger.debug("Negotiation needed")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        logger.info("ICE connection state: \(String(describing: newState))")
        switch newState {
        case .disconnected, .failed, .closed:
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnect?()
            }
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {
        logger.debug("ICE gathering state: \(String(describing: newState))")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        guard let entityId = entityId, let signaling = signaling else { return }
        signaling.sendWebRTCCandidate(
            entityId: entityId,
            candidate: candidate.sdp,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex
        )
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {
        logger.debug("ICE candidates removed")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {
        logger.debug("Data channel opened")
    }
}
