//
//  HubitatClient.swift
//  Itsyhome
//
//  Hubitat Maker API REST client + EventSocket WebSocket client
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatClient")

// MARK: - Client delegate

protocol HubitatClientDelegate: AnyObject {
    func clientDidConnect(_ client: HubitatClient)
    func clientDidDisconnect(_ client: HubitatClient, error: Error?)
    func client(_ client: HubitatClient, didReceiveDeviceEvent event: HubitatEvent)
    func client(_ client: HubitatClient, didEncounterError error: Error)
}

// MARK: - Client errors

enum HubitatClientError: LocalizedError {
    case notConnected
    case invalidURL(String)
    case invalidResponse
    case requestFailed(Int)
    case commandFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Hubitat"
        case .invalidURL(let message):
            return "Invalid hub URL: \(message)"
        case .invalidResponse:
            return "Invalid response from Hubitat"
        case .requestFailed(let statusCode):
            return "Request failed with status code \(statusCode)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - Hubitat client

final class HubitatClient: NSObject {

    // MARK: - Properties

    private let hubURL: URL
    private let appId: String
    private let accessToken: String
    private let baseURL: URL         // http://hub_ip/apps/api/{appId}
    let eventSocketURL: URL          // ws://hub_ip/eventsocket

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    private var pingTimer: Timer?

    /// Device IDs authorized in Maker API (for filtering EventSocket events)
    private(set) var authorizedDeviceIds: Set<String> = []
    private let stateLock = NSLock()

    weak var delegate: HubitatClientDelegate?
    private var _isConnected = false
    var isConnected: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isConnected
    }

    // MARK: - Initialization

    init(hubURL: URL, appId: String, accessToken: String) throws {
        // Validate URL scheme
        guard let scheme = hubURL.scheme, scheme == "http" || scheme == "https" else {
            throw HubitatClientError.invalidURL("URL scheme must be http or https (got \(hubURL.scheme ?? "none"))")
        }

        guard hubURL.host != nil && !hubURL.host!.isEmpty else {
            throw HubitatClientError.invalidURL("URL has no host")
        }

        self.hubURL = hubURL
        self.appId = appId
        self.accessToken = accessToken

        // Build base REST URL: http://hub_ip/apps/api/{appId}
        // Use URLComponents to build cleanly from just scheme+host+port
        var rootComponents = URLComponents()
        rootComponents.scheme = hubURL.scheme
        rootComponents.host = hubURL.host
        rootComponents.port = hubURL.port
        guard let rootURL = rootComponents.url else {
            throw HubitatClientError.invalidURL("Failed to construct root URL from hub URL")
        }
        self.baseURL = rootURL
            .appendingPathComponent("apps")
            .appendingPathComponent("api")
            .appendingPathComponent(appId)

        // Build EventSocket WebSocket URL: ws://hub_ip/eventsocket
        let wsScheme = (hubURL.scheme == "https") ? "wss" : "ws"
        let host = hubURL.host!
        let port = hubURL.port
        var wsURLString = "\(wsScheme)://\(host)"
        if let port = port {
            wsURLString += ":\(port)"
        }
        wsURLString += "/eventsocket"
        guard let wsURL = URL(string: wsURLString) else {
            throw HubitatClientError.invalidURL("Failed to construct EventSocket URL")
        }
        self.eventSocketURL = wsURL

        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    deinit {
        disconnect()
    }

    // MARK: - URL construction

    /// Builds: http://hub_ip/apps/api/{appId}/{endpoint}?access_token={token}
    func makeURL(endpoint: String) -> URL? {
        let url = baseURL.appendingPathComponent(endpoint)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "access_token", value: accessToken))
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - WebSocket (EventSocket) connection

    func connect() async throws {
        logger.info("Connecting EventSocket to \(self.eventSocketURL.absoluteString, privacy: .public)")

        let task = urlSession.webSocketTask(with: eventSocketURL)
        task.maximumMessageSize = 16 * 1024 * 1024
        stateLock.lock()
        webSocketTask = task
        stateLock.unlock()
        task.resume()

        // Start receiving messages
        receiveMessage()

        // EventSocket has no auth handshake — mark connected immediately
        // The delegate callback fires from the URLSessionWebSocketDelegate open callback
    }

    func disconnect() {
        logger.info("Disconnecting from Hubitat EventSocket")

        stopPing()

        stateLock.lock()
        _isConnected = false
        let task = webSocketTask
        webSocketTask = nil
        stateLock.unlock()

        task?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - WebSocket message handling

    private func receiveMessage() {
        stateLock.lock()
        let task = webSocketTask
        stateLock.unlock()

        task?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()  // Continue receiving

            case .failure(let error):
                logger.error("EventSocket receive error: \(error.localizedDescription)")
                self.handleDisconnection(error: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else {
                logger.warning("Received non-UTF8 string message")
                return
            }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            logger.warning("Received unknown WebSocket message type")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Received non-JSON EventSocket message")
            return
        }

        guard let event = HubitatEvent(json: json) else {
            logger.debug("Received EventSocket message that could not be parsed as HubitatEvent")
            return
        }

        // Filter: forward DEVICE events only for authorized device IDs,
        // and LOCATION events (HSM, mode changes) unconditionally
        if event.source == "DEVICE" {
            guard let deviceId = event.deviceId else { return }
            stateLock.lock()
            let isAuthorized = authorizedDeviceIds.contains(deviceId)
            stateLock.unlock()
            guard isAuthorized else { return }
        }

        logger.debug("EventSocket event: source=\(event.source, privacy: .public) name=\(event.name, privacy: .public)")
        delegate?.client(self, didReceiveDeviceEvent: event)
    }

    private func handleDisconnection(error: Error?) {
        stateLock.lock()
        _isConnected = false
        stateLock.unlock()

        stopPing()
        delegate?.clientDidDisconnect(self, error: error)

        // Schedule reconnection
        scheduleReconnect()
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        stateLock.lock()
        let attempts = reconnectAttempts
        stateLock.unlock()

        guard attempts < maxReconnectAttempts else {
            logger.error("Max reconnection attempts reached")
            return
        }

        let delay = min(baseReconnectDelay * pow(2.0, Double(attempts)) + Double.random(in: 0...1), 30.0)

        stateLock.lock()
        reconnectAttempts += 1
        stateLock.unlock()

        logger.info("Scheduling EventSocket reconnect in \(delay, privacy: .public) seconds (attempt \(attempts + 1))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            Task {
                try? await self.connect()
            }
        }
    }

    // MARK: - Ping

    private func startPing() {
        stopPing()

        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        stateLock.lock()
        let task = webSocketTask
        stateLock.unlock()

        task?.sendPing { [weak self] error in
            if let error = error {
                logger.warning("Ping failed: \(error.localizedDescription)")
                self?.handleDisconnection(error: error)
            }
        }
    }

    // MARK: - REST helpers

    private func get(endpoint: String) async throws -> Data {
        guard let url = makeURL(endpoint: endpoint) else {
            throw HubitatClientError.invalidURL("Could not construct URL for endpoint: \(endpoint)")
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HubitatClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw HubitatClientError.requestFailed(httpResponse.statusCode)
        }

        return data
    }

    private func getJSON(endpoint: String) async throws -> [[String: Any]] {
        let data = try await get(endpoint: endpoint)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw HubitatClientError.invalidResponse
        }
        return json
    }

    private func getJSONObject(endpoint: String) async throws -> [String: Any] {
        let data = try await get(endpoint: endpoint)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HubitatClientError.invalidResponse
        }
        return json
    }

    // MARK: - REST API methods

    /// Get all devices. Also populates `authorizedDeviceIds` for EventSocket filtering.
    func getAllDevices() async throws -> [HubitatDevice] {
        let jsonArray = try await getJSON(endpoint: "devices/all")
        let devices = jsonArray.compactMap { HubitatDevice(json: $0) }

        stateLock.lock()
        authorizedDeviceIds = Set(devices.map { $0.id })
        stateLock.unlock()

        logger.info("Loaded \(devices.count) devices, authorized IDs populated")
        return devices
    }

    /// Get a single device by ID.
    func getDevice(id: String) async throws -> HubitatDevice? {
        let json = try await getJSONObject(endpoint: "devices/\(id)")
        return HubitatDevice(json: json)
    }

    /// Send a command with no parameters.
    func sendCommand(deviceId: String, command: String) async throws {
        _ = try await get(endpoint: "devices/\(deviceId)/\(command)")
    }

    /// Send a command with a single value parameter.
    func sendCommand(deviceId: String, command: String, value: String) async throws {
        guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HubitatClientError.commandFailed("Could not URL-encode value: \(value)")
        }
        _ = try await get(endpoint: "devices/\(deviceId)/\(command)/\(encodedValue)")
    }

    /// Send a command with multiple value parameters (joined with comma).
    func sendCommand(deviceId: String, command: String, values: [String]) async throws {
        let joined = values.joined(separator: ",")
        try await sendCommand(deviceId: deviceId, command: command, value: joined)
    }

    /// Get the current Hubitat Safety Monitor status.
    func getHSMStatus() async throws -> HubitatHSMStatus? {
        let json = try await getJSONObject(endpoint: "hsm")
        return HubitatHSMStatus(json: json)
    }

    /// Set the HSM arm/disarm status.
    func setHSM(status: String) async throws {
        _ = try await get(endpoint: "hsm/\(status)")
    }

    /// Get all location modes.
    func getModes() async throws -> [HubitatMode] {
        let jsonArray = try await getJSON(endpoint: "modes")
        return jsonArray.compactMap { HubitatMode(json: $0) }
    }

}

// MARK: - URLSessionWebSocketDelegate

extension HubitatClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("EventSocket connection opened")

        stateLock.lock()
        _isConnected = true
        reconnectAttempts = 0
        stateLock.unlock()

        startPing()
        delegate?.clientDidConnect(self)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("EventSocket connection closed: \(closeCode.rawValue)")
        handleDisconnection(error: nil)
    }
}
