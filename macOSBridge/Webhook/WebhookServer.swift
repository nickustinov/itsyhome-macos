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
        case "debug":
            let rest = path.dropFirst(6) // drop "debug/"
            let decoded = String(rest).removingPercentEncoding ?? String(rest)
            handleDebug(target: decoded, connection: connection, engine: engine)
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
            var groups = PreferencesManager.shared.deviceGroups
            let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })
            let roomIdLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.name.lowercased(), $0.uniqueIdentifier) })

            // Filter by room if specified
            if let filterRoom = room?.removingPercentEncoding {
                let filterRoomLower = filterRoom.lowercased()
                if let roomId = roomIdLookup[filterRoomLower] {
                    // Include room-scoped groups for this room AND global groups
                    groups = groups.filter { $0.roomId == roomId || $0.roomId == nil }
                }
            }

            let items = groups.map { group in
                let deviceCount = group.deviceIds.count
                var fields = [
                    "\"name\":\"\(escapeJSON(group.name))\"",
                    "\"icon\":\"\(escapeJSON(group.icon))\"",
                    "\"devices\":\(deviceCount)"
                ]
                if let roomId = group.roomId, let roomName = roomLookup[roomId] {
                    fields.append("\"room\":\"\(escapeJSON(roomName))\"")
                }
                return "{\(fields.joined(separator: ","))}"
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

        let lowered = target.lowercased()

        // Try exact room name match first (avoids space-splitting issues)
        if let room = data.rooms.first(where: { $0.name.lowercased() == lowered }) {
            let roomServices = data.accessories.filter { $0.roomIdentifier == room.uniqueIdentifier }
                .flatMap { $0.services }
            // Return empty array for rooms with no devices
            let items = roomServices.map { buildServiceInfoJSON($0, in: data, engine: engine) }
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")
            return
        }

        // Try exact device name match
        let exactDevices = data.accessories.flatMap { $0.services }
            .filter { $0.name.lowercased() == lowered }
        if !exactDevices.isEmpty {
            sendServiceInfoResponse(exactDevices, data: data, engine: engine, connection: connection)
            return
        }

        // Use DeviceResolver for Room/Device, group, scene, UUID formats
        let resolved = DeviceResolver.resolve(target, in: data, groups: PreferencesManager.shared.deviceGroups)

        switch resolved {
        case .services(let services):
            sendServiceInfoResponse(services, data: data, engine: engine, connection: connection)

        case .scene(let scene):
            let json = "{\"name\":\"\(escapeJSON(scene.name))\",\"type\":\"scene\"}"
            sendResponse(connection: connection, status: 200, body: json)

        case .notFound, .ambiguous:
            sendResponse(connection: connection, status: 404, body: errorJSON("Not found: \(target)"))
        }
    }

    private func handleDebug(target: String, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: errorJSON("No data available"))
            return
        }

        let lowered = target.lowercased()

        // Find matching services
        let matchingServices = data.accessories.flatMap { $0.services }
            .filter { $0.name.lowercased() == lowered || $0.accessoryName.lowercased() == lowered }

        if matchingServices.isEmpty {
            sendResponse(connection: connection, status: 404, body: errorJSON("Not found: \(target)"))
            return
        }

        let items = matchingServices.map { buildDebugJSON($0, in: data, engine: engine) }
        if items.count == 1 {
            sendResponse(connection: connection, status: 200, body: items[0])
        } else {
            sendResponse(connection: connection, status: 200, body: "[\(items.joined(separator: ","))]")
        }
    }

    private func buildDebugJSON(_ service: ServiceData, in data: MenuData, engine: ActionEngine) -> String {
        let roomLookup = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })
        let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
        let roomName = accessory?.roomIdentifier.flatMap { roomLookup[String(describing: $0)] }

        var fields: [String] = [
            "\"name\":\"\(escapeJSON(service.name))\"",
            "\"accessoryName\":\"\(escapeJSON(service.accessoryName))\"",
            "\"serviceType\":\"\(escapeJSON(service.serviceType))\"",
            "\"serviceTypeLabel\":\"\(escapeJSON(serviceTypeLabel(service.serviceType)))\"",
            "\"serviceId\":\"\(escapeJSON(service.uniqueIdentifier))\"",
            "\"reachable\":\(accessory?.isReachable ?? false)"
        ]

        if let room = roomName {
            fields.append("\"room\":\"\(escapeJSON(room))\"")
        }
        if let roomId = service.roomIdentifier {
            fields.append("\"roomId\":\"\(escapeJSON(roomId))\"")
        }

        // Build characteristics object with all available characteristic IDs and their values
        var chars: [String] = []

        func addChar(_ name: String, _ idString: String?) {
            guard let idStr = idString, let uuid = UUID(uuidString: idStr) else { return }
            let value = engine.bridge?.getCharacteristicValue(identifier: uuid)
            let valueStr: String
            if let v = value {
                if let b = v as? Bool {
                    valueStr = b ? "true" : "false"
                } else if let i = v as? Int {
                    valueStr = "\(i)"
                } else if let d = v as? Double {
                    valueStr = "\(d)"
                } else if let n = v as? NSNumber {
                    valueStr = "\(n)"
                } else {
                    valueStr = "\"\(escapeJSON(String(describing: v)))\""
                }
            } else {
                valueStr = "null"
            }
            chars.append("\"\(name)\":{\"id\":\"\(idStr)\",\"value\":\(valueStr)}")
        }

        // Power/Active
        addChar("powerState", service.powerStateId)
        addChar("active", service.activeId)

        // Light characteristics
        addChar("brightness", service.brightnessId)
        addChar("hue", service.hueId)
        addChar("saturation", service.saturationId)
        addChar("colorTemperature", service.colorTemperatureId)

        // Temperature
        addChar("currentTemperature", service.currentTemperatureId)
        addChar("targetTemperature", service.targetTemperatureId)

        // Thermostat modes
        addChar("heatingCoolingState", service.heatingCoolingStateId)
        addChar("targetHeatingCoolingState", service.targetHeatingCoolingStateId)

        // HeaterCooler (AC)
        addChar("currentHeaterCoolerState", service.currentHeaterCoolerStateId)
        addChar("targetHeaterCoolerState", service.targetHeaterCoolerStateId)
        addChar("coolingThresholdTemperature", service.coolingThresholdTemperatureId)
        addChar("heatingThresholdTemperature", service.heatingThresholdTemperatureId)

        // Lock
        addChar("lockCurrentState", service.lockCurrentStateId)
        addChar("lockTargetState", service.lockTargetStateId)

        // Position (blinds)
        addChar("currentPosition", service.currentPositionId)
        addChar("targetPosition", service.targetPositionId)

        // Humidity
        addChar("humidity", service.humidityId)

        // Motion
        addChar("motionDetected", service.motionDetectedId)

        // Fan
        addChar("rotationSpeed", service.rotationSpeedId)

        // Garage door
        addChar("currentDoorState", service.currentDoorStateId)
        addChar("targetDoorState", service.targetDoorStateId)
        addChar("obstructionDetected", service.obstructionDetectedId)

        // Contact sensor
        addChar("contactSensorState", service.contactSensorStateId)

        // Humidifier/Dehumidifier
        addChar("currentHumidifierDehumidifierState", service.currentHumidifierDehumidifierStateId)
        addChar("targetHumidifierDehumidifierState", service.targetHumidifierDehumidifierStateId)
        addChar("humidifierThreshold", service.humidifierThresholdId)
        addChar("dehumidifierThreshold", service.dehumidifierThresholdId)

        // Air Purifier
        addChar("currentAirPurifierState", service.currentAirPurifierStateId)
        addChar("targetAirPurifierState", service.targetAirPurifierStateId)

        // Valve
        addChar("inUse", service.inUseId)
        addChar("setDuration", service.setDurationId)
        addChar("remainingDuration", service.remainingDurationId)

        // Security System
        addChar("securitySystemCurrentState", service.securitySystemCurrentStateId)
        addChar("securitySystemTargetState", service.securitySystemTargetStateId)

        if !chars.isEmpty {
            fields.append("\"characteristics\":{\(chars.joined(separator: ","))}")
        }

        // Add min/max values if present
        var limits: [String] = []
        if let min = service.colorTemperatureMin {
            limits.append("\"colorTemperatureMin\":\(min)")
        }
        if let max = service.colorTemperatureMax {
            limits.append("\"colorTemperatureMax\":\(max)")
        }
        if let min = service.rotationSpeedMin {
            limits.append("\"rotationSpeedMin\":\(min)")
        }
        if let max = service.rotationSpeedMax {
            limits.append("\"rotationSpeedMax\":\(max)")
        }
        if let valveType = service.valveTypeValue {
            limits.append("\"valveType\":\(valveType)")
        }

        if !limits.isEmpty {
            fields.append("\"limits\":{\(limits.joined(separator: ","))}")
        }

        return "{\(fields.joined(separator: ","))}"
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
        } else if let idStr = service.activeId, let uuid = UUID(uuidString: idStr),
                  let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"on\":\(intValue(value) != 0)")
        } else if let idStr = service.targetHeatingCoolingStateId, let uuid = UUID(uuidString: idStr),
                  let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            state.append("\"on\":\(intValue(value) != 0)")
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
        } else {
            // AC uses cooling/heating threshold temperatures
            let targetMode = service.targetHeaterCoolerStateId.flatMap { UUID(uuidString: $0) }
                .flatMap { engine.bridge?.getCharacteristicValue(identifier: $0) }
                .map { intValue($0) }
            if targetMode == 1, let idStr = service.heatingThresholdTemperatureId,
               let uuid = UUID(uuidString: idStr),
               let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
                state.append("\"targetTemperature\":\(doubleValue(value))")
            } else if let idStr = service.coolingThresholdTemperatureId,
                      let uuid = UUID(uuidString: idStr),
                      let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
                state.append("\"targetTemperature\":\(doubleValue(value))")
            }
        }
        if let idStr = service.heatingCoolingStateId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            let mode = intValue(value)
            let modeStr = mode == 1 ? "heat" : mode == 2 ? "cool" : "off"
            state.append("\"mode\":\"\(modeStr)\"")
        } else if let idStr = service.targetHeaterCoolerStateId, let uuid = UUID(uuidString: idStr),
                  let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            let mode = intValue(value)
            let modeStr = mode == 0 ? "auto" : mode == 1 ? "heat" : mode == 2 ? "cool" : "off"
            state.append("\"mode\":\"\(modeStr)\"")
        } else if let idStr = service.targetHeatingCoolingStateId, let uuid = UUID(uuidString: idStr),
                  let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            let mode = intValue(value)
            let modeStr = mode == 1 ? "heat" : mode == 2 ? "cool" : mode == 3 ? "auto" : "off"
            state.append("\"mode\":\"\(modeStr)\"")
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
        if let idStr = service.currentDoorStateId, let uuid = UUID(uuidString: idStr),
           let value = engine.bridge?.getCharacteristicValue(identifier: uuid) {
            let doorState = intValue(value)
            // 0=open, 1=closed, 2=opening, 3=closing, 4=stopped
            let stateStr = doorState == 0 ? "open" : doorState == 1 ? "closed" : doorState == 2 ? "opening" : doorState == 3 ? "closing" : "stopped"
            state.append("\"doorState\":\"\(stateStr)\"")
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
