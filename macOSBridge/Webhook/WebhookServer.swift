//
//  WebhookServer.swift
//  macOSBridge
//
//  Lightweight HTTP server for webhook-based HomeKit control and status queries
//

import Foundation
import Network

final class WebhookServer {

    static let shared = WebhookServer(port: configuredPort)

    static let defaultPort: UInt16 = 8423
    static let portKey = "webhookServerPort"
    static let statusChangedNotification = Notification.Name("webhookStatusChangedNotification")
    static let enabledKey = "webhookServerEnabled"

    static var configuredPort: UInt16 {
        let stored = UserDefaults.standard.integer(forKey: portKey)
        return stored > 0 ? UInt16(stored) : defaultPort
    }

    let port: UInt16

    enum State: Equatable {
        case stopped
        case running
        case error(String)
    }

    private(set) var state: State = .stopped {
        didSet {
            NotificationCenter.default.post(name: Self.statusChangedNotification, object: nil)
        }
    }

    private var listener: NWListener?
    private var actionEngine: ActionEngine?
    private let queue = DispatchQueue(label: "com.nickustinov.itsyhome.webhook", qos: .userInitiated)

    // SSE state
    var sseClients: [NWConnection] = []
    var characteristicIndex: [String: CharacteristicContext] = [:]
    var lastPublishedValues: [String: String] = [:]
    var heartbeatTimer: DispatchSourceTimer?

    init(port: UInt16) {
        self.port = port
    }

    // MARK: - Configuration

    func configure(actionEngine: ActionEngine) {
        self.actionEngine = actionEngine
    }

    // MARK: - Lifecycle

    func startIfEnabled() {
        guard ProStatusCache.shared.isPro else { return }
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        start()
    }

    func start() {
        guard listener == nil else { return }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] newState in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .running
                case .failed(let error):
                    self.state = .error(error.localizedDescription)
                    self.listener = nil
                case .cancelled:
                    self.state = .stopped
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.start(queue: queue)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stop() {
        disconnectAllSSEClients()
        listener?.cancel()
        listener = nil
        state = .stopped
    }

    /// Dispatch a block on the webhook queue from extensions
    func dispatchOnQueue(_ block: @escaping () -> Void) {
        queue.async(execute: block)
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveLoop(connection: connection, buffer: Data())
    }

    /// Accumulates incoming bytes until we have a full HTTP request
    /// (headers + content-length bytes of body). Replaces the old single-
    /// chunk reader so POST bodies larger than one TCP read (e.g. PCM
    /// audio for /voice/transcribe — ~160 KB for a 5 s utterance) can be
    /// reassembled before dispatch.
    private func receiveLoop(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            guard error == nil else { connection.cancel(); return }
            var buf = buffer
            if let d = data { buf.append(d) }

            if let headerEnd = self.findHeaderEnd(in: buf) {
                let headData = buf.subdata(in: 0..<headerEnd)
                guard let headStr = String(data: headData, encoding: .utf8),
                      let parsed = self.parseHead(headStr) else {
                    self.sendResponse(connection: connection, status: 400, body: self.encode(APIResponse.error("Invalid HTTP request")))
                    return
                }
                let bodyStart = headerEnd + 4  // skip "\r\n\r\n"
                let contentLength = Int(parsed.headers["content-length"] ?? "0") ?? 0
                let availableBody = buf.count - bodyStart
                if availableBody >= contentLength {
                    let body: Data = contentLength > 0
                        ? buf.subdata(in: bodyStart..<bodyStart + contentLength)
                        : Data()
                    self.handleRequest(method: parsed.method, path: parsed.path, body: body, connection: connection)
                    return
                }
            }

            if isComplete {
                connection.cancel()
                return
            }
            self.receiveLoop(connection: connection, buffer: buf)
        }
    }

    // MARK: - HTTP parsing

    private func findHeaderEnd(in data: Data) -> Int? {
        let crlf: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A]
        guard data.count >= crlf.count else { return nil }
        return data.withUnsafeBytes { rawBuf -> Int? in
            let bytes = rawBuf.bindMemory(to: UInt8.self)
            var i = 0
            let end = bytes.count - crlf.count
            while i <= end {
                if bytes[i] == crlf[0] && bytes[i+1] == crlf[1]
                    && bytes[i+2] == crlf[2] && bytes[i+3] == crlf[3] {
                    return i
                }
                i += 1
            }
            return nil
        }
    }

    private func parseHead(_ head: String) -> (method: String, path: String, headers: [String: String])? {
        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0]).uppercased()
        let path = String(parts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return (method, path, headers)
    }

    // MARK: - Request handling

    private func handleRequest(method: String, path: String, body: Data, connection: NWConnection) {
        // CORS preflight: browsers (and Even Hub's WebView) fire an
        // OPTIONS request before any "non-simple" POST. Answer it with
        // the headers needed for the actual request to follow. Cheap and
        // independent of Pro / engine state, so handle it early.
        if method == "OPTIONS" {
            sendPreflightResponse(connection: connection)
            return
        }
        guard let actionEngine else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("Server not configured")))
            return
        }

        guard ProStatusCache.shared.isPro else {
            sendResponse(connection: connection, status: 403, body: encode(APIResponse.error("Pro required")))
            return
        }

        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        guard !trimmedPath.isEmpty else {
            sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Empty path")))
            return
        }

        // POST endpoints. /voice/transcribe accepts a raw 16 kHz mono
        // int16 LE PCM payload; everything else gets a 405.
        if method == "POST" {
            if trimmedPath == "voice/transcribe" {
                handleVoiceTranscribe(body: body, connection: connection)
                return
            }
            sendResponse(connection: connection, status: 405, body: encode(APIResponse.error("Method not allowed")))
            return
        }
        if method != "GET" {
            sendResponse(connection: connection, status: 405, body: encode(APIResponse.error("Method not allowed")))
            return
        }

        // Handle SSE endpoint before read endpoints
        if handleSSERequest(path: trimmedPath, connection: connection) {
            return
        }

        // Handle read endpoints first
        if handleReadRequest(path: trimmedPath, connection: connection, engine: actionEngine) {
            return
        }

        // Control action via URLSchemeHandler
        guard let url = URL(string: "itsyhome://\(trimmedPath)") else {
            sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Invalid path")))
            return
        }

        guard let command = URLSchemeHandler.handle(url) else {
            let displayPath = trimmedPath.removingPercentEncoding ?? trimmedPath
            sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Unknown action: \(displayPath)")))
            return
        }

        switch ActionParser.parse(command) {
        case .success(let parsed):
            let result = actionEngine.execute(target: parsed.target, action: parsed.action)
            switch result {
            case .success:
                sendResponse(connection: connection, status: 200, body: encode(APIResponse.success))
            case .partial(let succeeded, let failed):
                sendResponse(connection: connection, status: 200, body: encode(APIResponse.partial(succeeded: succeeded, failed: failed)))
            case .error(let actionError):
                let statusCode = actionError.isNotFound ? 404 : 400
                sendResponse(connection: connection, status: statusCode, body: encode(APIResponse.error(actionError.message)))
            }
        case .failure(let parseError):
            sendResponse(connection: connection, status: 400, body: encode(APIResponse.error(parseError.localizedDescription)))
        }
    }

    // MARK: - Voice transcription

    /// POST /voice/transcribe — body is a raw 16 kHz mono int16 LE PCM
    /// payload captured on the glasses. We hand it to SFSpeechRecognizer
    /// (on-device) and return the transcript. The glasses app does its own
    /// fuzzy matching against rooms / devices / scenes from there.
    private func handleVoiceTranscribe(body: Data, connection: NWConnection) {
        guard UserDefaults.standard.bool(forKey: SpeechTranscriber.voiceEnabledKey) else {
            let resp = VoiceTranscribeResponse(status: "error", text: nil, confidence: nil,
                message: "Voice control is disabled. Enable it in Itsyhome on Mac: Settings → Webhooks/CLI.")
            sendResponse(connection: connection, status: 403, body: encode(resp))
            return
        }
        guard !body.isEmpty else {
            let resp = VoiceTranscribeResponse(status: "error", text: nil, confidence: nil,
                message: "Empty audio payload")
            sendResponse(connection: connection, status: 400, body: encode(resp))
            return
        }
        // Build a catalog prompt (rooms + scenes + service names + groups)
        // so Whisper biases its decoder toward the user's actual device
        // names. ~200-char budget — Whisper's prefill context is ~244
        // tokens, and shorter is better (less drift). Devices first since
        // they're the most common command target.
        let catalogPrompt = buildCatalogPrompt(maxChars: 200)
        // Bridge to async. The TCP connection stays open until we send the
        // response back from the completion.
        Task { [weak self] in
            guard let self else { return }
            do {
                let (text, confidence) = try await SpeechTranscriber.transcribe(pcm: body, prompt: catalogPrompt)
                let resp = VoiceTranscribeResponse(status: "success", text: text,
                                                    confidence: confidence, message: nil)
                self.queue.async {
                    self.sendResponse(connection: connection, status: 200, body: self.encode(resp))
                }
            } catch {
                let msg: String
                switch error {
                case SpeechTranscribeError.bufferConversionFailed:
                    msg = "Failed to decode audio payload"
                case SpeechTranscribeError.modelLoadFailed(let detail):
                    msg = "Voice model failed to load: \(detail)"
                case SpeechTranscribeError.underlying(let underlying):
                    msg = underlying.localizedDescription
                default:
                    msg = "Speech recognition failed: \(error)"
                }
                let resp = VoiceTranscribeResponse(status: "error", text: nil,
                                                    confidence: nil, message: msg)
                self.queue.async {
                    self.sendResponse(connection: connection, status: 500, body: self.encode(resp))
                }
            }
        }
    }

    /// Build a short, comma-separated string of catalog names (devices →
    /// rooms → scenes → groups) used as Whisper's prefill prompt for
    /// /voice/transcribe. The order biases more important / more often
    /// spoken names into the budget first. Returns "" when no engine is
    /// configured yet (e.g. before HomeKit loads).
    private func buildCatalogPrompt(maxChars: Int) -> String {
        guard let data = actionEngine?.menuData else { return "" }
        var pieces: [String] = []
        var seen = Set<String>()
        func add(_ s: String) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            pieces.append(trimmed)
        }
        // Devices first: most commonly spoken.
        for accessory in data.accessories {
            for service in accessory.services {
                add(service.name)
            }
        }
        // Rooms next — often qualify the device ("office lamp").
        for room in data.rooms { add(room.name) }
        // Scenes — momentary commands.
        for scene in data.scenes { add(scene.name) }
        // Device groups — power user feature.
        for group in PreferencesManager.shared.deviceGroups { add(group.name) }

        // Pack into the budget, comma-separated.
        var out = ""
        for p in pieces {
            let nextLen = out.isEmpty ? p.count : out.count + 2 + p.count
            if nextLen > maxChars { break }
            out = out.isEmpty ? p : "\(out), \(p)"
        }
        return out
    }

    // MARK: - Value conversion helpers

    func boolValue(_ value: Any) -> Bool {
        ValueConversion.toBool(value, default: false)
    }

    func intValue(_ value: Any) -> Int {
        ValueConversion.toInt(value, default: 0)
    }

    func doubleValue(_ value: Any) -> Double {
        ValueConversion.toDouble(value, default: 0)
    }

    func serviceTypeLabel(_ type: String) -> String {
        switch type {
        case ServiceTypes.lightbulb: return "light"
        case ServiceTypes.switch: return "switch"
        case ServiceTypes.outlet: return "outlet"
        case ServiceTypes.fan, ServiceTypes.fanV2: return "fan"
        case ServiceTypes.thermostat: return "thermostat"
        case ServiceTypes.heaterCooler: return "heater-cooler"
        case ServiceTypes.windowCovering: return "blinds"
        case ServiceTypes.door: return "door"
        case ServiceTypes.window: return "window"
        case ServiceTypes.lock: return "lock"
        case ServiceTypes.garageDoorOpener: return "garage-door"
        case ServiceTypes.temperatureSensor: return "temperature-sensor"
        case ServiceTypes.humiditySensor: return "humidity-sensor"
        case ServiceTypes.securitySystem: return "security-system"
        case ServiceTypes.humidifierDehumidifier: return "humidifier-dehumidifier"
        case ServiceTypes.faucet: return "faucet"
        case ServiceTypes.slat: return "slat"
        default: return type
        }
    }

    // MARK: - HTTP response

    /// Send a raw binary response with a custom content type. Used by the
    /// `/icon/<name>` endpoint to deliver PNG bytes without JSON-wrapping.
    func sendBinaryResponse(connection: NWConnection, contentType: String, body: Data) {
        // no-store on the response: client-side WebViews persist HTTP cache
        // across icon-render fixes, and stale 172-byte renders shadow the
        // good output once we ship a server update. Clients (glasses + this
        // app) keep their own in-memory cache so the per-icon hit is fine.
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Cache-Control: no-store\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        \r

        """
        var data = Data(header.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    func sendResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        \r
        \(body)
        """

        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// 204 No Content reply to a CORS preflight (OPTIONS). Must include
    /// the same Allow-Origin / Allow-Methods / Allow-Headers that the
    /// real response will carry, so the browser accepts the upcoming POST.
    func sendPreflightResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 204 No Content\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Access-Control-Max-Age: 600\r
        Content-Length: 0\r
        Connection: close\r
        \r

        """
        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Network info

    static func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            guard addrFamily == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" || name == "en1" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            address = String(cString: hostname)
            break
        }

        return address
    }
}

// MARK: - ActionError helpers

private extension ActionError {
    var isNotFound: Bool {
        if case .targetNotFound = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .targetNotFound(let target): return "Target not found: \(target)"
        case .ambiguousTarget(let options): return "Ambiguous target, options: \(options.joined(separator: ", "))"
        case .unsupportedAction(let action): return "Unsupported action: \(action)"
        case .bridgeUnavailable: return "Bridge unavailable"
        case .executionFailed(let reason): return reason
        }
    }
}
