//
//  WebhookServer+Endpoints.swift
//  macOSBridge
//
//  Read endpoint handlers for webhook server
//

import Foundation
import Network

extension WebhookServer {

    // MARK: - Read endpoints

    func handleReadRequest(path: String, connection: NWConnection, engine: ActionEngine) -> Bool {
        let components = path.split(separator: "/", maxSplits: 3).map { String($0) }

        switch components.first {
        case "status":
            handleStatus(connection: connection, engine: engine)
            return true
        case "list":
            guard components.count >= 2 else {
                sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Usage: /list/rooms|devices|scenes|groups")))
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
            if decoded == "raw" {
                handleDebugRaw(connection: connection, engine: engine)
            } else if decoded == "all" {
                handleDebugAll(connection: connection, engine: engine)
            } else if decoded == "cameras" || decoded.hasPrefix("cameras/") {
                let entityFilter = decoded.hasPrefix("cameras/") ? String(decoded.dropFirst(8)) : nil
                handleDebugCameras(connection: connection, engine: engine, entityId: entityFilter)
            } else {
                handleDebug(target: decoded, connection: connection, engine: engine)
            }
            return true
        default:
            return false
        }
    }

    // MARK: - Status

    private func handleStatus(connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let allServices = data.accessories.flatMap { $0.services }
        let reachableCount = data.accessories.filter { $0.isReachable }.count

        let response = StatusResponse(
            rooms: data.rooms.count,
            devices: allServices.count,
            accessories: data.accessories.count,
            reachable: reachableCount,
            unreachable: data.accessories.count - reachableCount,
            scenes: data.scenes.count,
            groups: PreferencesManager.shared.deviceGroups.count
        )
        sendResponse(connection: connection, status: 200, body: encode(response))
    }

    // MARK: - List

    private func handleList(type: String, room: String?, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        switch type {
        case "rooms":
            let items = data.rooms.map { RoomListItem(name: $0.name) }
            sendResponse(connection: connection, status: 200, body: encode(items))

        case "devices":
            let roomLookup = data.roomLookup()
            var items: [DeviceListItem] = []

            for accessory in data.accessories {
                let roomName = accessory.roomIdentifier.flatMap { roomLookup[$0] }
                for service in accessory.services {
                    if let filterRoom = room?.removingPercentEncoding {
                        guard roomName?.lowercased() == filterRoom.lowercased() else { continue }
                    }
                    items.append(DeviceListItem(
                        name: service.name,
                        type: serviceTypeLabel(service.serviceType),
                        icon: IconResolver.iconName(for: service),
                        reachable: accessory.isReachable,
                        room: roomName
                    ))
                }
            }
            sendResponse(connection: connection, status: 200, body: encode(items))

        case "scenes":
            let items = data.scenes.map { scene in
                SceneListItem(name: scene.name, icon: IconResolver.iconName(for: scene))
            }
            sendResponse(connection: connection, status: 200, body: encode(items))

        case "groups":
            var groups = PreferencesManager.shared.deviceGroups
            let roomLookup = data.roomLookup()
            let roomIdLookup = Dictionary(data.rooms.map { ($0.name.lowercased(), $0.uniqueIdentifier) }, uniquingKeysWith: { first, _ in first })

            // Filter by room if specified
            if let filterRoom = room?.removingPercentEncoding {
                let filterRoomLower = filterRoom.lowercased()
                if let roomId = roomIdLookup[filterRoomLower] {
                    groups = groups.filter { $0.roomId == roomId || $0.roomId == nil }
                }
            }

            let items = groups.map { group in
                GroupListItem(
                    name: group.name,
                    icon: group.icon,
                    devices: group.deviceIds.count,
                    room: group.roomId.flatMap { roomLookup[$0] }
                )
            }
            sendResponse(connection: connection, status: 200, body: encode(items))

        default:
            sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Unknown list type: \(type). Use rooms, devices, scenes, or groups.")))
        }
    }

    // MARK: - Info

    private func handleInfo(target: String, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let lowered = target.lowercased()

        // Try exact room name match first (avoids space-splitting issues)
        if let room = data.rooms.first(where: { $0.name.lowercased() == lowered }) {
            let roomServices = data.accessories.filter { $0.roomIdentifier == room.uniqueIdentifier }
                .flatMap { $0.services }
            let items = roomServices.map { buildServiceInfo($0, in: data, engine: engine) }
            sendResponse(connection: connection, status: 200, body: encode(items))
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
            let response = SceneInfoResponse(
                name: scene.name,
                type: "scene",
                icon: IconResolver.iconName(for: scene)
            )
            sendResponse(connection: connection, status: 200, body: encode(response))

        case .notFound, .ambiguous:
            sendResponse(connection: connection, status: 404, body: encode(APIResponse.error("Not found: \(target)")))
        }
    }

    // MARK: - Debug

    private func handleDebug(target: String, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let lowered = target.lowercased()

        // Find matching services
        let matchingServices = data.accessories.flatMap { $0.services }
            .filter { $0.name.lowercased() == lowered || $0.accessoryName.lowercased() == lowered }

        if matchingServices.isEmpty {
            sendResponse(connection: connection, status: 404, body: encode(APIResponse.error("Not found: \(target)")))
            return
        }

        let items = matchingServices.map { buildDebugService($0, in: data, engine: engine) }
        if items.count == 1 {
            sendResponse(connection: connection, status: 200, body: encode(items[0]))
        } else {
            sendResponse(connection: connection, status: 200, body: encode(items))
        }
    }

    private func handleDebugAll(connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let roomLookup = data.roomLookup()

        let accessoryInfos = data.accessories.map { accessory in
            DebugAccessoryInfo(
                name: accessory.name,
                reachable: accessory.isReachable,
                services: accessory.services.map { buildDebugService($0, in: data, engine: engine) },
                room: accessory.roomIdentifier.flatMap { roomLookup[$0] }
            )
        }

        let response = DebugAllResponse(
            accessories: accessoryInfos,
            rooms: data.rooms.count,
            scenes: data.scenes.count
        )
        sendResponse(connection: connection, status: 200, body: encode(response))
    }

    private func handleDebugCameras(connection: NWConnection, engine: ActionEngine, entityId: String? = nil) {
        guard let bridge = engine.bridge else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("Bridge unavailable")))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                connection.cancel()
                return
            }
            bridge.getCameraDebugJSON(entityId: entityId) { json in
                if let json = json {
                    self.sendResponse(connection: connection, status: 200, body: json)
                } else {
                    self.sendResponse(connection: connection, status: 500, body: self.encode(APIResponse.error("Camera debug not available (HomeKit mode?)")))
                }
            }
        }
    }

    private func handleDebugRaw(connection: NWConnection, engine: ActionEngine) {
        guard let bridge = engine.bridge else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("Bridge unavailable")))
            return
        }

        // Request raw HomeKit dump from iOS - must run on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                connection.cancel()
                return
            }
            if let rawData = bridge.getRawHomeKitDump() {
                self.sendResponse(connection: connection, status: 200, body: rawData)
            } else {
                self.sendResponse(connection: connection, status: 500, body: self.encode(APIResponse.error("Failed to get raw HomeKit data")))
            }
        }
    }

    // MARK: - Response builders

    private func sendServiceInfoResponse(_ services: [ServiceData], data: MenuData, engine: ActionEngine, connection: NWConnection) {
        let items = services.map { buildServiceInfo($0, in: data, engine: engine) }
        if items.count == 1 {
            sendResponse(connection: connection, status: 200, body: encode(items[0]))
        } else {
            sendResponse(connection: connection, status: 200, body: encode(items))
        }
    }

    private func buildServiceInfo(_ service: ServiceData, in data: MenuData, engine: ActionEngine) -> ServiceInfoResponse {
        let roomLookup = data.roomLookup()
        let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
        let roomName = accessory?.roomIdentifier.flatMap { roomLookup[$0] }

        // Helper to get characteristic value
        func getValue(_ idString: String?) -> Any? {
            guard let idStr = idString, let uuid = UUID(uuidString: idStr) else { return nil }
            return engine.bridge?.getCharacteristicValue(identifier: uuid)
        }

        // Build state
        var state = ServiceState()

        // Power state
        if let value = getValue(service.powerStateId) {
            state.on = boolValue(value)
        } else if let value = getValue(service.activeId) {
            state.on = intValue(value) != 0
        } else if let value = getValue(service.targetHeatingCoolingStateId) {
            state.on = intValue(value) != 0
        }

        if let value = getValue(service.brightnessId) {
            state.brightness = intValue(value)
        }
        if let value = getValue(service.currentPositionId) {
            state.position = intValue(value)
        }
        if let value = getValue(service.currentTemperatureId) {
            state.temperature = doubleValue(value)
        }
        if let value = getValue(service.targetTemperatureId) {
            state.targetTemperature = doubleValue(value)
        } else {
            // AC uses cooling/heating threshold temperatures
            let targetMode = getValue(service.targetHeaterCoolerStateId).map { intValue($0) }
            if targetMode == 1, let value = getValue(service.heatingThresholdTemperatureId) {
                state.targetTemperature = doubleValue(value)
            } else if let value = getValue(service.coolingThresholdTemperatureId) {
                state.targetTemperature = doubleValue(value)
            }
        }

        // Mode
        if let value = getValue(service.heatingCoolingStateId) {
            state.mode = ThermostatState(rawValue: intValue(value))?.label ?? "off"
        } else if let value = getValue(service.targetHeaterCoolerStateId) {
            state.mode = HeaterCoolerState(rawValue: intValue(value))?.label ?? "off"
        } else if let value = getValue(service.targetHeatingCoolingStateId) {
            state.mode = TargetThermostatState(rawValue: intValue(value))?.label ?? "off"
        }

        if let value = getValue(service.humidityId) {
            state.humidity = doubleValue(value)
        }
        if let value = getValue(service.hueId) {
            state.hue = doubleValue(value)
        }
        if let value = getValue(service.saturationId) {
            state.saturation = doubleValue(value)
        }
        if let value = getValue(service.lockCurrentStateId) {
            if let strValue = value as? String {
                // HA sends raw state strings: "locked", "unlocked", "locking", "unlocking", "jammed"
                state.locked = strValue == "locked"
            } else {
                state.locked = LockState(rawValue: intValue(value))?.isLocked ?? false
            }
        }
        if let value = getValue(service.currentDoorStateId) {
            state.doorState = DoorState(rawValue: intValue(value))?.label ?? "stopped"
        }
        if let value = getValue(service.rotationSpeedId) {
            state.speed = doubleValue(value)
        }

        // Check if state has any values
        let hasState = state.on != nil || state.brightness != nil || state.position != nil ||
                       state.temperature != nil || state.targetTemperature != nil || state.mode != nil ||
                       state.humidity != nil || state.hue != nil || state.saturation != nil ||
                       state.locked != nil || state.doorState != nil || state.speed != nil

        return ServiceInfoResponse(
            name: service.name,
            type: serviceTypeLabel(service.serviceType),
            icon: IconResolver.iconName(for: service),
            reachable: accessory?.isReachable ?? false,
            room: roomName,
            state: hasState ? state : nil
        )
    }

    private func buildDebugService(_ service: ServiceData, in data: MenuData, engine: ActionEngine) -> DebugServiceResponse {
        let roomLookup = data.roomLookup()
        let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
        let roomName = accessory?.roomIdentifier.flatMap { roomLookup[$0] }

        // Build characteristics dictionary
        var chars: [String: CharacteristicDebugInfo] = [:]

        func addChar(_ name: String, _ idString: String?) {
            guard let idStr = idString, let uuid = UUID(uuidString: idStr) else { return }
            let value = engine.bridge?.getCharacteristicValue(identifier: uuid)
            chars[name] = CharacteristicDebugInfo(id: idStr, value: AnyEncodable(value))
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

        // Build limits
        let limits = ServiceLimits(
            colorTemperatureMin: service.colorTemperatureMin,
            colorTemperatureMax: service.colorTemperatureMax,
            rotationSpeedMin: service.rotationSpeedMin,
            rotationSpeedMax: service.rotationSpeedMax,
            valveType: service.valveTypeValue
        )

        return DebugServiceResponse(
            name: service.name,
            accessoryName: service.accessoryName,
            serviceType: service.serviceType,
            serviceTypeLabel: serviceTypeLabel(service.serviceType),
            serviceId: service.uniqueIdentifier,
            reachable: accessory?.isReachable ?? false,
            room: roomName,
            roomId: service.roomIdentifier,
            characteristics: chars.isEmpty ? nil : chars,
            limits: limits.isEmpty ? nil : limits
        )
    }
}
