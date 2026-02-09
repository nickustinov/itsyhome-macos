//
//  WebhookServer+SSE.swift
//  macOSBridge
//
//  Server-Sent Events (SSE) support for streaming characteristic changes
//

import Foundation
import Network

extension WebhookServer {

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - SSE request handling

    /// Returns true if the path is the SSE events endpoint, sending SSE headers and registering the client.
    func handleSSERequest(path: String, connection: NWConnection) -> Bool {
        guard path == "events" else { return false }

        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: text/event-stream\r
        Cache-Control: no-cache\r
        Connection: keep-alive\r
        Access-Control-Allow-Origin: *\r
        \r

        """

        connection.send(content: Data(headers.utf8), completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else {
                connection.cancel()
                return
            }
            self.addSSEClient(connection)
        })

        return true
    }

    // MARK: - Client management

    private func addSSEClient(_ connection: NWConnection) {
        dispatchOnQueue { [weak self] in
            guard let self else { return }
            self.sseClients.append(connection)

            connection.viabilityUpdateHandler = { [weak self, weak connection] isViable in
                guard let self, let connection, !isViable else { return }
                self.removeSSEClient(connection)
            }

            if self.sseClients.count == 1 {
                self.startHeartbeat()
            }
        }
    }

    private func removeSSEClient(_ connection: NWConnection) {
        dispatchOnQueue { [weak self] in
            guard let self else { return }
            self.sseClients.removeAll { $0 === connection }
            connection.cancel()

            if self.sseClients.isEmpty {
                self.stopHeartbeat()
            }
        }
    }

    func disconnectAllSSEClients() {
        dispatchOnQueue { [weak self] in
            guard let self else { return }
            for client in self.sseClients {
                client.cancel()
            }
            self.sseClients.removeAll()
            self.stopHeartbeat()
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        guard heartbeatTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "com.nickustinov.itsyhome.sse.heartbeat"))
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        heartbeatTimer = timer
        timer.resume()
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func sendHeartbeat() {
        let comment = Data(": heartbeat\n\n".utf8)
        dispatchOnQueue { [weak self] in
            guard let self else { return }
            var deadClients: [NWConnection] = []

            for client in self.sseClients {
                client.send(content: comment, completion: .contentProcessed { error in
                    if error != nil {
                        deadClients.append(client)
                    }
                })
            }

            // Clean up dead clients after a short delay to let send completions fire
            if !deadClients.isEmpty {
                self.dispatchOnQueue { [weak self] in
                    guard let self else { return }
                    for dead in deadClients {
                        self.sseClients.removeAll { $0 === dead }
                        dead.cancel()
                    }
                    if self.sseClients.isEmpty {
                        self.stopHeartbeat()
                    }
                }
            }
        }
    }

    // MARK: - Event publishing

    /// Called from the main thread when a characteristic value changes.
    /// Only publishes when the value actually differs from the last published value.
    func publishCharacteristicChange(characteristicId: UUID, value: Any) {
        let idString = characteristicId.uuidString
        let encodedValue: String
        if let data = try? Self.jsonEncoder.encode(AnyEncodable(value)),
           let str = String(data: data, encoding: .utf8) {
            encodedValue = str
        } else {
            encodedValue = String(describing: value)
        }

        dispatchOnQueue { [weak self] in
            guard let self else { return }
            guard let context = self.characteristicIndex[idString] else { return }

            // Record first-seen values silently; only publish actual changes
            guard let previousValue = self.lastPublishedValues[idString] else {
                self.lastPublishedValues[idString] = encodedValue
                return
            }
            if previousValue == encodedValue { return }
            self.lastPublishedValues[idString] = encodedValue

            guard !self.sseClients.isEmpty else { return }

            var event = CharacteristicEvent(
                timestamp: Self.isoFormatter.string(from: Date()),
                device: context.deviceName,
                room: context.roomName,
                type: context.deviceType,
                characteristic: context.characteristicName,
                value: AnyEncodable(value),
                characteristicId: idString,
                serviceId: context.serviceId
            )
            event.entityId = context.entityId

            guard let jsonData = try? Self.jsonEncoder.encode(event),
                  let json = String(data: jsonData, encoding: .utf8) else { return }

            let sseData = Data("data: \(json)\n\n".utf8)

            for client in self.sseClients {
                client.send(content: sseData, completion: .contentProcessed { [weak self, weak client] error in
                    if error != nil, let self, let client {
                        self.removeSSEClient(client)
                    }
                })
            }
        }
    }

    // MARK: - Characteristic index

    /// Rebuilds the lookup table mapping characteristic UUID strings to their context.
    func rebuildCharacteristicIndex(from data: MenuData) {
        let roomLookup = data.roomLookup()

        var index: [String: CharacteristicContext] = [:]

        for accessory in data.accessories {
            let roomName = accessory.roomIdentifier.flatMap { roomLookup[$0] } ?? "Unknown"

            for service in accessory.services {
                let deviceType = serviceTypeLabel(service.serviceType)
                let serviceId = service.uniqueIdentifier
                let entityId = service.haEntityId

                func add(_ characteristicId: String?, name: String) {
                    guard let id = characteristicId else { return }
                    index[id] = CharacteristicContext(
                        deviceName: service.name,
                        roomName: roomName,
                        deviceType: deviceType,
                        characteristicName: name,
                        serviceId: serviceId,
                        entityId: entityId
                    )
                }

                add(service.powerStateId, name: "power")
                add(service.outletInUseId, name: "outlet-in-use")
                add(service.activeId, name: "active")
                add(service.brightnessId, name: "brightness")
                add(service.hueId, name: "hue")
                add(service.saturationId, name: "saturation")
                add(service.colorTemperatureId, name: "color-temperature")
                add(service.currentTemperatureId, name: "current-temperature")
                add(service.targetTemperatureId, name: "target-temperature")
                add(service.heatingCoolingStateId, name: "heating-cooling-state")
                add(service.targetHeatingCoolingStateId, name: "target-heating-cooling-state")
                add(service.lockCurrentStateId, name: "lock-current-state")
                add(service.lockTargetStateId, name: "lock-target-state")
                add(service.currentPositionId, name: "current-position")
                add(service.targetPositionId, name: "target-position")
                add(service.currentHorizontalTiltId, name: "current-horizontal-tilt")
                add(service.targetHorizontalTiltId, name: "target-horizontal-tilt")
                add(service.currentVerticalTiltId, name: "current-vertical-tilt")
                add(service.targetVerticalTiltId, name: "target-vertical-tilt")
                add(service.positionStateId, name: "position-state")
                add(service.humidityId, name: "humidity")
                add(service.motionDetectedId, name: "motion-detected")
                add(service.currentHeaterCoolerStateId, name: "current-heater-cooler-state")
                add(service.targetHeaterCoolerStateId, name: "target-heater-cooler-state")
                add(service.coolingThresholdTemperatureId, name: "cooling-threshold-temperature")
                add(service.heatingThresholdTemperatureId, name: "heating-threshold-temperature")
                add(service.rotationSpeedId, name: "rotation-speed")
                add(service.targetFanStateId, name: "target-fan-state")
                add(service.currentFanStateId, name: "current-fan-state")
                add(service.rotationDirectionId, name: "rotation-direction")
                add(service.swingModeId, name: "swing-mode")
                add(service.currentDoorStateId, name: "current-door-state")
                add(service.targetDoorStateId, name: "target-door-state")
                add(service.obstructionDetectedId, name: "obstruction-detected")
                add(service.contactSensorStateId, name: "contact-sensor-state")
                add(service.currentHumidifierDehumidifierStateId, name: "current-humidifier-dehumidifier-state")
                add(service.targetHumidifierDehumidifierStateId, name: "target-humidifier-dehumidifier-state")
                add(service.humidifierThresholdId, name: "humidifier-threshold")
                add(service.dehumidifierThresholdId, name: "dehumidifier-threshold")
                add(service.waterLevelId, name: "water-level")
                add(service.currentAirPurifierStateId, name: "current-air-purifier-state")
                add(service.targetAirPurifierStateId, name: "target-air-purifier-state")
                add(service.inUseId, name: "in-use")
                add(service.setDurationId, name: "set-duration")
                add(service.remainingDurationId, name: "remaining-duration")
                add(service.securitySystemCurrentStateId, name: "security-system-current-state")
                add(service.securitySystemTargetStateId, name: "security-system-target-state")
                add(service.currentTiltAngleId, name: "current-tilt-angle")
                add(service.targetTiltAngleId, name: "target-tilt-angle")
                add(service.currentSlatStateId, name: "current-slat-state")
            }
        }

        dispatchOnQueue { [weak self] in
            self?.characteristicIndex = index
            self?.lastPublishedValues.removeAll()
        }
    }
}
