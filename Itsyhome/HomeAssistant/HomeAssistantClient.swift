//
//  HomeAssistantClient.swift
//  Itsyhome
//
//  Home Assistant REST + WebSocket API client
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeAssistantClient")

// MARK: - Client delegate

protocol HomeAssistantClientDelegate: AnyObject {
    func clientDidConnect(_ client: HomeAssistantClient)
    func clientDidDisconnect(_ client: HomeAssistantClient, error: Error?)
    func client(_ client: HomeAssistantClient, didReceiveStateChange entityId: String, newState: HAEntityState, oldState: HAEntityState?)
    func client(_ client: HomeAssistantClient, didReceiveEvent event: HAEvent)
    func client(_ client: HomeAssistantClient, didEncounterError error: Error)
}

// MARK: - Client errors

enum HomeAssistantClientError: LocalizedError {
    case notConnected
    case authenticationFailed(String)
    case connectionFailed(String)
    case invalidResponse
    case invalidURL(String)
    case serviceCallFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Home Assistant"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .invalidResponse:
            return "Invalid response from Home Assistant"
        case .invalidURL(let message):
            return "Invalid server URL: \(message)"
        case .serviceCallFailed(let message):
            return "Service call failed: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - Home Assistant client

final class HomeAssistantClient: NSObject {

    // MARK: - Properties

    private let serverURL: URL
    private let accessToken: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!

    private var messageId: Int = 1
    private var pendingRequests: [Int: (Result<Any, Error>) -> Void] = [:]
    private var subscriptionCallbacks: [Int: (HAEvent) -> Void] = [:]
    private var authContinuation: CheckedContinuation<Void, Error>?
    private let stateLock = NSLock()

    private var isAuthenticated = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0

    private var pingTimer: Timer?
    private var pingTimeout: DispatchWorkItem?

    weak var delegate: HomeAssistantClientDelegate?

    var isConnected: Bool {
        isAuthenticated && webSocketTask?.state == .running
    }

    // MARK: - Initialization

    init(serverURL: URL, accessToken: String) throws {
        // Convert to WebSocket URL
        var wsURL = serverURL
        switch wsURL.scheme {
        case "http":
            wsURL = URL(string: wsURL.absoluteString.replacingOccurrences(of: "http://", with: "ws://")) ?? serverURL
        case "https":
            wsURL = URL(string: wsURL.absoluteString.replacingOccurrences(of: "https://", with: "wss://")) ?? serverURL
        case "ws", "wss":
            break
        default:
            throw HomeAssistantClientError.invalidURL("URL scheme must be http, https, ws, or wss (got \(wsURL.scheme ?? "none"))")
        }

        // Validate scheme after conversion
        guard wsURL.scheme == "ws" || wsURL.scheme == "wss" else {
            throw HomeAssistantClientError.invalidURL("Failed to convert URL to WebSocket scheme")
        }

        guard wsURL.host != nil && !wsURL.host!.isEmpty else {
            throw HomeAssistantClientError.invalidURL("URL has no host")
        }

        // Append websocket path if not present
        if !wsURL.path.contains("api/websocket") {
            wsURL = wsURL.appendingPathComponent("api/websocket")
        }

        self.serverURL = wsURL
        self.accessToken = accessToken

        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    func connect() async throws {
        logger.info("Connecting to Home Assistant at \(self.serverURL.absoluteString, privacy: .public)")

        webSocketTask = urlSession.webSocketTask(with: serverURL)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()

        // Wait for authentication
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stateLock.lock()
            self.authContinuation = continuation
            stateLock.unlock()

            // Timeout for authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self else { return }
                if self.isAuthenticated != true {
                    self.stateLock.lock()
                    let cont = self.authContinuation
                    self.authContinuation = nil
                    self.stateLock.unlock()
                    cont?.resume(throwing: HomeAssistantClientError.timeout)
                }
            }
        }
    }

    func disconnect() {
        logger.info("Disconnecting from Home Assistant")

        stopPingPong()
        isAuthenticated = false

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        stateLock.lock()
        // Cancel auth continuation if pending
        let continuation = authContinuation
        authContinuation = nil

        // Cancel all pending requests
        let callbacks = pendingRequests
        pendingRequests.removeAll()
        subscriptionCallbacks.removeAll()
        stateLock.unlock()

        continuation?.resume(throwing: HomeAssistantClientError.notConnected)
        for (_, callback) in callbacks {
            callback(.failure(HomeAssistantClientError.notConnected))
        }
    }

    // MARK: - Message handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()  // Continue receiving

            case .failure(let error):
                logger.error("WebSocket receive error: \(error.localizedDescription)")
                self.handleDisconnection(error: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            logger.warning("Received non-JSON or invalid message")
            return
        }

        switch type {
        case "auth_required":
            sendAuthentication()

        case "auth_ok":
            handleAuthSuccess(json)

        case "auth_invalid":
            let message = json["message"] as? String ?? "Unknown error"
            handleAuthFailure(message: message)

        case "result":
            handleResult(json)

        case "event":
            handleEvent(json)

        case "pong":
            handlePong()

        default:
            logger.debug("Received message type: \(type)")
        }
    }

    private func sendAuthentication() {
        logger.info("Sending authentication")
        send(["type": "auth", "access_token": accessToken])
    }

    private func handleAuthSuccess(_ json: [String: Any]) {
        let haVersion = json["ha_version"] as? String ?? "unknown"
        logger.info("Authenticated successfully. HA version: \(haVersion, privacy: .public)")

        isAuthenticated = true
        reconnectAttempts = 0

        // Complete auth continuation
        stateLock.lock()
        let continuation = authContinuation
        authContinuation = nil
        stateLock.unlock()

        continuation?.resume(returning: ())

        startPingPong()
        delegate?.clientDidConnect(self)
    }

    private func handleAuthFailure(message: String) {
        logger.error("Authentication failed: \(message)")
        let error = HomeAssistantClientError.authenticationFailed(message)
        delegate?.client(self, didEncounterError: error)

        // Complete auth continuation with error
        stateLock.lock()
        let continuation = authContinuation
        authContinuation = nil
        stateLock.unlock()

        continuation?.resume(throwing: error)

        disconnect()
    }

    private func handleResult(_ json: [String: Any]) {
        guard let id = json["id"] as? Int else { return }

        stateLock.lock()
        let callback = pendingRequests.removeValue(forKey: id)
        stateLock.unlock()

        if let callback = callback {
            let success = json["success"] as? Bool ?? false
            if success {
                let result = json["result"] ?? [:]
                callback(.success(result))
            } else {
                let errorMessage = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                callback(.failure(HomeAssistantClientError.serviceCallFailed(errorMessage)))
            }
        }
    }

    private func handleEvent(_ json: [String: Any]) {
        guard let id = json["id"] as? Int,
              let eventData = json["event"] as? [String: Any] else { return }

        // Check if this is a subscribed event
        stateLock.lock()
        let callback = subscriptionCallbacks[id]
        stateLock.unlock()

        if let callback = callback {
            if let event = HAEvent(json: eventData) {
                callback(event)

                // Also notify delegate for state_changed events
                if event.eventType == "state_changed",
                   let entityId = event.data["entity_id"] as? String,
                   let newStateJson = event.data["new_state"] as? [String: Any],
                   let newState = HAEntityState(json: newStateJson) {
                    let oldState = (event.data["old_state"] as? [String: Any]).flatMap { HAEntityState(json: $0) }
                    delegate?.client(self, didReceiveStateChange: entityId, newState: newState, oldState: oldState)
                }
            }
        }
    }

    private func handleDisconnection(error: Error?) {
        isAuthenticated = false
        stopPingPong()

        // Resume auth continuation if pending (connection failed before auth completed)
        stateLock.lock()
        let continuation = authContinuation
        authContinuation = nil
        stateLock.unlock()

        if let continuation = continuation {
            continuation.resume(throwing: error ?? HomeAssistantClientError.connectionFailed("Connection lost"))
        }

        delegate?.clientDidDisconnect(self, error: error)

        // Schedule reconnection
        scheduleReconnect()
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            logger.error("Max reconnection attempts reached")
            return
        }

        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts)) + Double.random(in: 0...1), 30.0)
        reconnectAttempts += 1

        logger.info("Scheduling reconnect in \(delay, privacy: .public) seconds (attempt \(self.reconnectAttempts))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            Task {
                try? await self.connect()
            }
        }
    }

    // MARK: - Ping/Pong

    private func startPingPong() {
        stopPingPong()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopPingPong() {
        pingTimer?.invalidate()
        pingTimer = nil
        pingTimeout?.cancel()
        pingTimeout = nil
    }

    private func sendPing() {
        stateLock.lock()
        let id = messageId
        messageId += 1
        sendLocked(["id": id, "type": "ping"])
        stateLock.unlock()

        // Set timeout for pong
        let timeout = DispatchWorkItem { [weak self] in
            logger.warning("Pong timeout - connection may be dead")
            self?.handleDisconnection(error: HomeAssistantClientError.timeout)
        }
        pingTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
    }

    private func handlePong() {
        pingTimeout?.cancel()
        pingTimeout = nil
    }

    // MARK: - Sending messages

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            logger.error("Failed to serialize message")
            return
        }

        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error = error {
                logger.error("Send error: \(error.localizedDescription)")
                self?.handleDisconnection(error: error)
            }
        }
    }

    /// Send a message while already holding stateLock
    private func sendLocked(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            logger.error("Failed to serialize message")
            return
        }

        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error = error {
                logger.error("Send error: \(error.localizedDescription)")
                self?.handleDisconnection(error: error)
            }
        }
    }

    // MARK: - API Methods

    /// Helper to send a message and wait for response
    /// Pass message WITHOUT "id" - it will be added atomically
    private func sendAndWait(_ message: [String: Any]) async throws -> Any {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any, Error>) in
            stateLock.lock()
            // Generate ID while holding lock to ensure ordering
            let id = messageId
            messageId += 1

            var fullMessage = message
            fullMessage["id"] = id

            pendingRequests[id] = { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            // Send while holding lock to ensure messages go out in ID order
            sendLocked(fullMessage)
            stateLock.unlock()
        }
    }

    /// Subscribe to state change events
    func subscribeToStateChanges() async throws -> Int {
        let (id, _) = try await sendAndWaitReturningId([
            "type": "subscribe_events",
            "event_type": "state_changed"
        ]) { [weak self] id in
            // Register subscription callback before sending
            self?.subscriptionCallbacks[id] = { [weak self] event in
                self?.delegate?.client(self!, didReceiveEvent: event)
            }
        }

        return id
    }

    /// Helper to send a message and wait for response, returning the message ID
    /// The beforeSend closure is called while holding the lock, with the ID
    private func sendAndWaitReturningId(_ message: [String: Any], beforeSend: ((Int) -> Void)? = nil) async throws -> (Int, Any) {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int, Any), Error>) in
            stateLock.lock()
            let id = messageId
            messageId += 1

            var fullMessage = message
            fullMessage["id"] = id

            // Call beforeSend while holding lock
            beforeSend?(id)

            pendingRequests[id] = { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: (id, value))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            sendLocked(fullMessage)
            stateLock.unlock()
        }
    }

    /// Get all entity states
    func getStates() async throws -> [HAEntityState] {
        let result = try await sendAndWait(["type": "get_states"])

        guard let statesJson = result as? [[String: Any]] else {
            throw HomeAssistantClientError.invalidResponse
        }

        return statesJson.compactMap { HAEntityState(json: $0) }
    }

    /// Call a service
    func callService(domain: String, service: String, serviceData: [String: Any]? = nil, target: [String: Any]? = nil) async throws {
        var message: [String: Any] = [
            "type": "call_service",
            "domain": domain,
            "service": service
        ]

        if let serviceData = serviceData {
            message["service_data"] = serviceData
        }

        if let target = target {
            message["target"] = target
        }

        _ = try await sendAndWait(message)
    }

    /// Get HA configuration (unit system, location, etc.)
    func getConfig() async throws -> [String: Any] {
        let result = try await sendAndWait(["type": "get_config"])

        guard let config = result as? [String: Any] else {
            throw HomeAssistantClientError.invalidResponse
        }

        return config
    }

    /// Get areas from registry
    func getAreas() async throws -> [HAArea] {
        let result = try await sendAndWait(["type": "config/area_registry/list"])

        guard let areasJson = result as? [[String: Any]] else {
            throw HomeAssistantClientError.invalidResponse
        }

        return areasJson.compactMap { HAArea(json: $0) }
    }

    /// Get devices from registry
    func getDevices() async throws -> [HADevice] {
        let result = try await sendAndWait(["type": "config/device_registry/list"])

        guard let devicesJson = result as? [[String: Any]] else {
            throw HomeAssistantClientError.invalidResponse
        }

        return devicesJson.compactMap { HADevice(json: $0) }
    }

    /// Get entities from registry
    func getEntities() async throws -> [HAEntityRegistryEntry] {
        let result = try await sendAndWait(["type": "config/entity_registry/list"])

        guard let entitiesJson = result as? [[String: Any]] else {
            throw HomeAssistantClientError.invalidResponse
        }

        return entitiesJson.compactMap { HAEntityRegistryEntry(json: $0) }
    }

    /// Get scenes
    func getScenes() async throws -> [HAEntityState] {
        let states = try await getStates()
        return states.filter { $0.entityId.hasPrefix("scene.") }
    }

    /// Get scene configuration with target entity states
    /// - Parameter internalId: The internal scene ID from state attributes, not the entity_id
    func getSceneConfig(internalId: String) async throws -> HASceneConfig? {
        do {
            let data = try await restRequest(path: "api/config/scene/config/\(internalId)")
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return HASceneConfig(json: json)
        } catch {
            // Config endpoint may not exist for all scenes (e.g., YAML-defined scenes)
            return nil
        }
    }

    /// Get all scene configurations
    func getAllSceneConfigs() async throws -> [String: HASceneConfig] {
        let scenes = try await getScenes()
        var configs: [String: HASceneConfig] = [:]

        await withTaskGroup(of: (String, HASceneConfig?).self) { group in
            for scene in scenes {
                // The internal ID is in the state attributes, not the entity_id
                guard let internalId = scene.attributes["id"] as? String else {
                    continue
                }
                let entityId = scene.entityId
                group.addTask {
                    let config = try? await self.getSceneConfig(internalId: internalId)
                    return (entityId, config)
                }
            }

            for await (entityId, config) in group {
                if let config = config {
                    configs[entityId] = config
                }
            }
        }

        return configs
    }

    /// Get camera stream URL (HLS)
    func getCameraStreamURL(entityId: String) async throws -> URL {
        let result = try await sendAndWait([
            "type": "camera/stream",
            "entity_id": entityId,
            "format": "hls"
        ])

        guard let resultDict = result as? [String: Any],
              let urlString = resultDict["url"] as? String,
              let url = URL(string: urlString, relativeTo: restBaseURL) else {
            throw HomeAssistantClientError.invalidResponse
        }

        return url
    }

    /// WebRTC signaling - send offer
    func sendWebRTCOffer(entityId: String, offer: String) async throws -> String {
        let result = try await sendAndWait([
            "type": "camera/webrtc/offer",
            "entity_id": entityId,
            "offer": offer
        ])

        guard let resultDict = result as? [String: Any],
              let answer = resultDict["answer"] as? String else {
            throw HomeAssistantClientError.invalidResponse
        }

        return answer
    }

    /// WebRTC signaling - send ICE candidate
    func sendWebRTCCandidate(entityId: String, candidate: String) async throws {
        _ = try await sendAndWait([
            "type": "camera/webrtc/candidate",
            "entity_id": entityId,
            "candidate": candidate
        ])
    }

    // MARK: - REST API

    private var restBaseURL: URL {
        var url = serverURL
        if url.scheme == "ws" {
            url = URL(string: url.absoluteString.replacingOccurrences(of: "ws://", with: "http://"))!
        } else if url.scheme == "wss" {
            url = URL(string: url.absoluteString.replacingOccurrences(of: "wss://", with: "https://"))!
        }
        // Remove websocket path
        if url.path.contains("api/websocket") {
            url = url.deletingLastPathComponent().deletingLastPathComponent()
        }
        return url
    }

    /// Get camera snapshot URL
    func getCameraSnapshotURL(entityId: String) -> URL {
        return restBaseURL
            .appendingPathComponent("api/camera_proxy")
            .appendingPathComponent(entityId)
    }

    /// Make authenticated REST request
    func restRequest(path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        var url = restBaseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw HomeAssistantClientError.invalidResponse
        }

        return data
    }
}

// MARK: - URLSessionWebSocketDelegate

extension HomeAssistantClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("WebSocket connection opened")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("WebSocket connection closed: \(closeCode.rawValue)")
        handleDisconnection(error: nil)
    }
}
