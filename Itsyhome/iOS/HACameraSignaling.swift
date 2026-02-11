//
//  HACameraSignaling.swift
//  Itsyhome
//
//  Lightweight HA WebSocket client for camera WebRTC signaling.
//  Creates a second WebSocket connection (only open during streaming)
//  to avoid cross-bundle signaling complexity.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HACameraSignaling")

final class HACameraSignaling: NSObject {

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var messageId: Int = 1
    private var pendingRequests: [Int: (Result<Any, Error>) -> Void] = [:]
    private let lock = NSLock()
    private var isAuthenticated = false
    private var authContinuation: CheckedContinuation<Void, Error>?

    /// Session ID returned by HA after sending an offer — required for ICE candidates
    private(set) var sessionId: String?

    /// ICE candidates queued before session_id arrives
    private var pendingCandidates: [(entityId: String, candidate: String, sdpMid: String?, sdpMLineIndex: Int32)] = []

    /// Subscription-based offer: HA sends events (session, answer, candidate) via subscription
    private var offerContinuation: CheckedContinuation<String, Error>?
    private var subscriptionId: Int?

    // MARK: - Initialization

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    func connect() async throws {
        guard let serverURL = HAAuthManager.shared.serverURL,
              let token = HAAuthManager.shared.accessToken else {
            throw HomeAssistantClientError.authenticationFailed("HA credentials not available")
        }

        // Build WebSocket URL
        var wsURL: URL
        let urlString = serverURL.absoluteString
        switch serverURL.scheme {
        case "http":
            wsURL = URL(string: urlString.replacingOccurrences(of: "http://", with: "ws://")) ?? serverURL
        case "https":
            wsURL = URL(string: urlString.replacingOccurrences(of: "https://", with: "wss://")) ?? serverURL
        case "ws", "wss":
            wsURL = serverURL
        default:
            throw HomeAssistantClientError.invalidURL("URL scheme must be http, https, ws, or wss")
        }

        guard wsURL.scheme == "ws" || wsURL.scheme == "wss" else {
            throw HomeAssistantClientError.invalidURL("Failed to convert URL to WebSocket scheme")
        }

        if !wsURL.path.contains("api/websocket") {
            wsURL = wsURL.appendingPathComponent("api/websocket")
        }

        logger.info("Connecting signaling WebSocket to \(wsURL.absoluteString, privacy: .public)")

        webSocketTask = urlSession.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        receiveMessage()

        // Wait for authentication
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            self.authContinuation = continuation
            lock.unlock()

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self, !self.isAuthenticated else { return }
                self.lock.lock()
                let cont = self.authContinuation
                self.authContinuation = nil
                self.lock.unlock()
                cont?.resume(throwing: HomeAssistantClientError.timeout)
            }
        }

        logger.info("Signaling WebSocket authenticated")
    }

    func disconnect() {
        isAuthenticated = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        lock.lock()
        let authCont = authContinuation
        authContinuation = nil
        let offerCont = offerContinuation
        offerContinuation = nil
        let callbacks = pendingRequests
        pendingRequests.removeAll()
        lock.unlock()

        authCont?.resume(throwing: HomeAssistantClientError.notConnected)
        offerCont?.resume(throwing: HomeAssistantClientError.notConnected)
        for (_, callback) in callbacks {
            callback(.failure(HomeAssistantClientError.notConnected))
        }
    }

    // MARK: - WebRTC signaling

    /// Sends a WebRTC offer and waits for the answer SDP.
    /// HA uses a subscription model: the offer message subscribes to events,
    /// then HA sends back "session", "answer", and "candidate" events.
    func sendWebRTCOffer(entityId: String, offer: String) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            lock.lock()
            let id = messageId
            messageId += 1
            self.offerContinuation = continuation
            self.subscriptionId = id
            lock.unlock()

            let message: [String: Any] = [
                "id": id,
                "type": "camera/webrtc/offer",
                "entity_id": entityId,
                "offer": offer
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: message),
                  let string = String(data: data, encoding: .utf8) else {
                lock.lock()
                self.offerContinuation = nil
                lock.unlock()
                continuation.resume(throwing: HomeAssistantClientError.invalidResponse)
                return
            }

            logger.info("Sending WebRTC offer (msg id=\(id)) for \(entityId)")
            webSocketTask?.send(.string(string)) { error in
                if let error = error {
                    logger.error("Signaling send error: \(error.localizedDescription)")
                }
            }

            // Timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                let cont = self.offerContinuation
                self.offerContinuation = nil
                self.lock.unlock()
                cont?.resume(throwing: HomeAssistantClientError.timeout)
            }
        }
    }

    // MARK: - HLS streaming

    /// Requests an HLS stream URL for a camera entity.
    func getHLSStreamURL(entityId: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            lock.lock()
            let id = messageId
            messageId += 1
            pendingRequests[id] = { result in
                switch result {
                case .success(let response):
                    if let dict = response as? [String: Any],
                       let urlString = dict["url"] as? String,
                       let url = URL(string: urlString) {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: HomeAssistantClientError.invalidResponse)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            lock.unlock()

            let message: [String: Any] = [
                "id": id,
                "type": "camera/stream",
                "entity_id": entityId
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: message),
                  let string = String(data: data, encoding: .utf8) else {
                lock.lock()
                pendingRequests.removeValue(forKey: id)
                lock.unlock()
                continuation.resume(throwing: HomeAssistantClientError.invalidResponse)
                return
            }

            logger.info("Requesting HLS stream for \(entityId)")
            webSocketTask?.send(.string(string)) { error in
                if let error = error {
                    logger.error("HLS request send error: \(error.localizedDescription)")
                }
            }

            // Timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                if let callback = self.pendingRequests.removeValue(forKey: id) {
                    self.lock.unlock()
                    callback(.failure(HomeAssistantClientError.timeout))
                } else {
                    self.lock.unlock()
                }
            }
        }
    }

    /// Sends an ICE candidate to HA. Queues if session_id is not yet available.
    func sendWebRTCCandidate(entityId: String, candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        guard let sessionId = sessionId else {
            lock.lock()
            pendingCandidates.append((entityId: entityId, candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex))
            lock.unlock()
            logger.debug("Queued ICE candidate (no session_id yet), queue size=\(self.pendingCandidates.count)")
            return
        }

        lock.lock()
        let id = messageId
        messageId += 1
        lock.unlock()

        var candidateDict: [String: Any] = ["candidate": candidate]
        if let sdpMid = sdpMid {
            candidateDict["sdpMid"] = sdpMid
        }
        candidateDict["sdpMLineIndex"] = sdpMLineIndex

        let message: [String: Any] = [
            "id": id,
            "type": "camera/webrtc/candidate",
            "entity_id": entityId,
            "session_id": sessionId,
            "candidate": candidateDict
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(string)) { error in
            if let error = error {
                logger.error("Signaling send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Message handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()
            case .failure(let error):
                logger.error("Signaling receive error: \(error.localizedDescription)")
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "auth_required":
            sendAuthentication()
        case "auth_ok":
            isAuthenticated = true
            lock.lock()
            let cont = authContinuation
            authContinuation = nil
            lock.unlock()
            cont?.resume(returning: ())
        case "auth_invalid":
            let msg = json["message"] as? String ?? "Unknown error"
            lock.lock()
            let cont = authContinuation
            authContinuation = nil
            lock.unlock()
            cont?.resume(throwing: HomeAssistantClientError.authenticationFailed(msg))
        case "result":
            handleResult(json)
        case "event":
            handleEvent(json)
        default:
            break
        }
    }

    private func sendAuthentication() {
        guard let token = HAAuthManager.shared.accessToken else { return }
        send(["type": "auth", "access_token": token])
    }

    private func handleResult(_ json: [String: Any]) {
        guard let id = json["id"] as? Int else { return }
        let success = json["success"] as? Bool ?? false

        if !success {
            let errorMessage = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            logger.error("WebSocket result error (id=\(id)): \(errorMessage)")

            // Check pending requests (HLS)
            lock.lock()
            if let callback = pendingRequests.removeValue(forKey: id) {
                lock.unlock()
                callback(.failure(HomeAssistantClientError.serviceCallFailed(errorMessage)))
                return
            }
            // If this was the offer subscription, fail it
            if id == subscriptionId {
                let cont = offerContinuation
                offerContinuation = nil
                lock.unlock()
                cont?.resume(throwing: HomeAssistantClientError.serviceCallFailed(errorMessage))
            } else {
                lock.unlock()
            }
            return
        }

        // Handle successful result with data (HLS stream URL)
        if let result = json["result"] as? [String: Any] {
            lock.lock()
            if let callback = pendingRequests.removeValue(forKey: id) {
                lock.unlock()
                callback(.success(result))
                return
            }
            lock.unlock()
        }
        // Success result for subscription just means the subscription was accepted — events come separately
    }

    private func handleEvent(_ json: [String: Any]) {
        guard let id = json["id"] as? Int, id == subscriptionId,
              let event = json["event"] as? [String: Any],
              let eventType = event["type"] as? String else { return }

        switch eventType {
        case "session":
            if let sid = event["session_id"] as? String {
                sessionId = sid
                logger.info("Received session_id: \(sid)")

                // Flush queued ICE candidates
                lock.lock()
                let queued = pendingCandidates
                pendingCandidates.removeAll()
                lock.unlock()
                if !queued.isEmpty {
                    logger.info("Flushing \(queued.count) queued ICE candidates")
                    for c in queued {
                        sendWebRTCCandidate(entityId: c.entityId, candidate: c.candidate, sdpMid: c.sdpMid, sdpMLineIndex: c.sdpMLineIndex)
                    }
                }
            }
        case "answer":
            if let answer = event["answer"] as? String {
                logger.info("Received SDP answer (\(answer.count) chars)")
                lock.lock()
                let cont = offerContinuation
                offerContinuation = nil
                lock.unlock()
                cont?.resume(returning: answer)
            }
        case "candidate":
            // Server-side ICE candidate — we don't need to handle these for receive-only
            logger.debug("Received server ICE candidate")
        case "error":
            let code = event["code"] as? String ?? "unknown"
            let msg = event["message"] as? String ?? "Unknown error"
            logger.error("WebRTC event error: \(code) - \(msg)")
            lock.lock()
            let cont = offerContinuation
            offerContinuation = nil
            lock.unlock()
            cont?.resume(throwing: HomeAssistantClientError.serviceCallFailed("\(code): \(msg)"))
        default:
            logger.debug("Unknown WebRTC event type: \(eventType)")
        }
    }

    // MARK: - Send helpers

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(string)) { error in
            if let error = error {
                logger.error("Signaling send error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension HACameraSignaling: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("Signaling WebSocket opened")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("Signaling WebSocket closed: \(closeCode.rawValue)")
    }
}
