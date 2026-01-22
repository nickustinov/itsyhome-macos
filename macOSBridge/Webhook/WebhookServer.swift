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
        listener?.cancel()
        listener = nil
        state = .stopped
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }

            guard let request = String(data: data, encoding: .utf8) else {
                self.sendResponse(connection: connection, status: 400, body: self.errorJSON("Invalid request"))
                return
            }

            guard let path = self.parseHTTPPath(from: request) else {
                self.sendResponse(connection: connection, status: 400, body: self.errorJSON("Invalid HTTP request"))
                return
            }

            self.handleRequest(path: path, connection: connection)
        }
    }

    // MARK: - HTTP parsing

    private func parseHTTPPath(from request: String) -> String? {
        guard let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        return String(parts[1])
    }

    // MARK: - Request handling

    private func handleRequest(path: String, connection: NWConnection) {
        guard let actionEngine else {
            sendResponse(connection: connection, status: 500, body: errorJSON("Server not configured"))
            return
        }

        guard ProStatusCache.shared.isPro else {
            sendResponse(connection: connection, status: 403, body: errorJSON("Pro required"))
            return
        }

        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        guard !trimmedPath.isEmpty else {
            sendResponse(connection: connection, status: 400, body: errorJSON("Empty path"))
            return
        }

        // Handle read endpoints first
        if handleReadRequest(path: trimmedPath, connection: connection, engine: actionEngine) {
            return
        }

        // Control action via URLSchemeHandler
        guard let url = URL(string: "itsyhome://\(trimmedPath)") else {
            sendResponse(connection: connection, status: 400, body: errorJSON("Invalid path"))
            return
        }

        guard let command = URLSchemeHandler.handle(url) else {
            let displayPath = trimmedPath.removingPercentEncoding ?? trimmedPath
            sendResponse(connection: connection, status: 400, body: errorJSON("Unknown action: \(displayPath)"))
            return
        }

        switch ActionParser.parse(command) {
        case .success(let parsed):
            let result = actionEngine.execute(target: parsed.target, action: parsed.action)
            switch result {
            case .success:
                sendResponse(connection: connection, status: 200, body: successJSON())
            case .partial(let succeeded, let failed):
                sendResponse(connection: connection, status: 200, body: partialJSON(succeeded: succeeded, failed: failed))
            case .error(let actionError):
                let statusCode = actionError.isNotFound ? 404 : 400
                sendResponse(connection: connection, status: statusCode, body: errorJSON(actionError.message))
            }
        case .failure(let parseError):
            sendResponse(connection: connection, status: 400, body: errorJSON(parseError.localizedDescription))
        }
    }

    // MARK: - Read endpoints

    private func handleReadRequest(path: String, connection: NWConnection, engine: ActionEngine) -> Bool {
        let components = path.split(separator: "/", maxSplits: 3).map { String($0) }

        switch components.first {
        case "status":
            handleStatus(connection: connection, engine: engine)
            return true
        case "list":
            guard components.count >= 2 else {
                sendResponse(connection: connection, status: 400, body: errorJSON("Usage: /list/rooms|devices|scenes|groups"))
                return true
            }
            handleList(type: components[1], room: components.count > 2 ? components[2] : nil, connection: connection, engine: engine)
            return true
        case "info":
            let rest = path.dropFirst(5) // drop "info/"
            let decoded = String(rest).removingPercentEncoding ?? String(rest)
            handleInfo(target: decoded, connection: connection, engine: engine)
            return true
        default:
            return false
        }
    }

    private func handleStatus(connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: errorJSON("No data available"))
            return
        }

        let rooms = data.rooms
        let allServices = data.accessories.flatMap { $0.services }
        let reachable = data.accessories.filter { $0.isReachable }.count
        let unreachable = data.accessories.count - reachable
        let groups = PreferencesManager.shared.deviceGroups

        let json = "{\"rooms\":\(rooms.count),\"devices\":\(allServices.count),\"accessories\":\(data.accessories.count),\"reachable\":\(reachable),\"unreachable\":\(unreachable),\"scenes\":\(data.scenes.count),\"groups\":\(groups.count)}"
        sendResponse(connection: connection, status: 200, body: json)
    }

    private func handleList(type: String, room: String?, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: errorJSON("No data available"))
            return
        }

        switch type {
        case "rooms":
            let items = data.rooms.map { "{\"name\":\"\(escapeJSON($0.name))\"}" }
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")

        case "devices":
            let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })
            var services: [(ServiceData, String?, Bool)] = []

            for accessory in data.accessories {
                let roomName = accessory.roomIdentifier.flatMap { roomLookup[String(describing: $0)] }
                for service in accessory.services {
                    if let filterRoom = room?.removingPercentEncoding {
                        guard roomName?.lowercased() == filterRoom.lowercased() else { continue }
                    }
                    services.append((service, roomName, accessory.isReachable))
                }
            }

            let items = services.map { service, roomName, reachable in
                var fields = [
                    "\"name\":\"\(escapeJSON(service.name))\"",
                    "\"type\":\"\(escapeJSON(serviceTypeLabel(service.serviceType)))\"",
                    "\"reachable\":\(reachable)"
                ]
                if let room = roomName {
                    fields.append("\"room\":\"\(escapeJSON(room))\"")
                }
                return "{\(fields.joined(separator: ","))}"
            }
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")

        case "scenes":
            let items = data.scenes.map { "{\"name\":\"\(escapeJSON($0.name))\"}" }
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")

        case "groups":
            let groups = PreferencesManager.shared.deviceGroups
            let items = groups.map { group in
                let deviceCount = group.deviceIds.count
                return "{\"name\":\"\(escapeJSON(group.name))\",\"icon\":\"\(escapeJSON(group.icon))\",\"devices\":\(deviceCount)}"
            }
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")

        default:
            sendResponse(connection: connection, status: 400, body: errorJSON("Unknown list type: \(type). Use rooms, devices, scenes, or groups."))
        }
    }

    private func handleInfo(target: String, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: errorJSON("No data available"))
            return
        }

        let resolved = DeviceResolver.resolve(target, in: data, groups: PreferencesManager.shared.deviceGroups)

        switch resolved {
        case .services(let services):
            sendServiceInfoResponse(services, data: data, engine: engine, connection: connection)

        case .scene(let scene):
            let json = "{\"name\":\"\(escapeJSON(scene.name))\",\"type\":\"scene\"}"
            sendResponse(connection: connection, status: 200, body: json)

        case .notFound:
            // Fallback: try matching by room name (always returns array)
            let lowered = target.lowercased()
            let matchingRoom = data.rooms.first { $0.name.lowercased() == lowered }
            if let room = matchingRoom {
                let roomServices = data.accessories.filter { $0.roomIdentifier == room.uniqueIdentifier }
                    .flatMap { $0.services }
                if !roomServices.isEmpty {
                    let items = roomServices.map { buildServiceInfoJSON($0, in: data, engine: engine) }
                    sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")
                    return
                }
            }

            // Fallback: try matching by bare device name
            let matchingServices = data.accessories.flatMap { $0.services }
                .filter { $0.name.lowercased() == lowered }
            if !matchingServices.isEmpty {
                sendServiceInfoResponse(matchingServices, data: data, engine: engine, connection: connection)
                return
            }

            sendResponse(connection: connection, status: 404, body: errorJSON("Not found: \(target)"))

        case .ambiguous(let options):
            let names = options.map { "\"\(escapeJSON($0.name))\"" }
            sendResponse(connection: connection, status: 400, body: "{\"status\":\"error\",\"message\":\"Ambiguous target\",\"options\":[\(names.joined(separator: ","))]}")
        }
    }

    private func sendServiceInfoResponse(_ services: [ServiceData], data: MenuData, engine: ActionEngine, connection: NWConnection) {
        let items = services.map { buildServiceInfoJSON($0, in: data, engine: engine) }
        if items.count == 1 {
            sendResponse(connection: connection, status: 200, body: items[0])
        } else {
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")
        }
    }

    private func buildServiceInfoJSON(_ service: ServiceData, in data: MenuData, engine: ActionEngine) -> String {
        let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })
        let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
        let roomName = accessory?.roomIdentifier.flatMap { roomLookup[String(describing: $0)] }

        var fields: [String] = [
            "\"name\":\"\(escapeJSON(service.name))\"",
            "\"type\":\"\(escapeJSON(serviceTypeLabel(service.serviceType)))\"",
            "\"reachable\":\(accessory?.isReachable ?? false)"
        ]

        if let room = roomName {
            fields.append("\"room\":\"\(escapeJSON(room))\"")
        }

        // Add current state values
        var state: [String] = []

        if let idStr = service.powerStateId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"on\":\(boolValue(value))")
        }
        if let idStr = service.brightnessId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"brightness\":\(intValue(value))")
        }
        if let idStr = service.currentPositionId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"position\":\(intValue(value))")
        }
        if let idStr = service.currentTemperatureId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"temperature\":\(doubleValue(value))")
        }
        if let idStr = service.targetTemperatureId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"targetTemperature\":\(doubleValue(value))")
        }
        if let idStr = service.humidityId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"humidity\":\(doubleValue(value))")
        }
        if let idStr = service.hueId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"hue\":\(doubleValue(value))")
        }
        if let idStr = service.saturationId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"saturation\":\(doubleValue(value))")
        }
        if let idStr = service.lockCurrentStateId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            let locked = intValue(value) == 1
            state.append("\"locked\":\(locked)")
        }
        if let idStr = service.rotationSpeedId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"speed\":\(doubleValue(value))")
        }

        if !state.isEmpty {
            fields.append("\"state\":{\(state.joined(separator: ","))}")
        }

        return "{\(fields.joined(separator: ","))}"
    }

    // MARK: - Value conversion helpers

    private func boolValue(_ value: Any) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let i = value as? Int { return i != 0 }
        return false
    }

    private func intValue(_ value: Any) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }

    private func doubleValue(_ value: Any) -> Double {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        return 0
    }

    private func serviceTypeLabel(_ type: String) -> String {
        switch type {
        case ServiceTypes.lightbulb: return "light"
        case ServiceTypes.switch: return "switch"
        case ServiceTypes.outlet: return "outlet"
        case ServiceTypes.fan: return "fan"
        case ServiceTypes.thermostat: return "thermostat"
        case ServiceTypes.heaterCooler: return "heater-cooler"
        case ServiceTypes.windowCovering: return "blinds"
        case ServiceTypes.lock: return "lock"
        case ServiceTypes.garageDoorOpener: return "garage-door"
        case ServiceTypes.temperatureSensor: return "temperature-sensor"
        case ServiceTypes.humiditySensor: return "humidity-sensor"
        case ServiceTypes.securitySystem: return "security-system"
        default: return type
        }
    }

    // MARK: - HTTP response

    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        \r
        \(body)
        """

        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - JSON helpers

    private func successJSON() -> String {
        "{\"status\":\"success\"}"
    }

    private func partialJSON(succeeded: Int, failed: Int) -> String {
        "{\"status\":\"partial\",\"message\":\"\(succeeded) succeeded, \(failed) failed\"}"
    }

    private func errorJSON(_ message: String) -> String {
        let escaped = escapeJSON(message)
        return "{\"status\":\"error\",\"message\":\"\(escaped)\"}"
    }

    private func escapeJSON(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\")
              .replacingOccurrences(of: "\"", with: "\\\"")
              .replacingOccurrences(of: "\n", with: "\\n")
              .replacingOccurrences(of: "\r", with: "\\r")
              .replacingOccurrences(of: "\t", with: "\\t")
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
