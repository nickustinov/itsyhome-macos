//
//  PinnedStatusItem+StatusDisplay.swift
//  macOSBridge
//
//  Status display formatting for different service types in pinned status items
//

import AppKit

extension PinnedStatusItem {

    // MARK: - Status display for services

    func statusDisplay(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        switch service.serviceType {
        case ServiceTypes.heaterCooler:
            return heaterCoolerStatus(for: service)
        case ServiceTypes.thermostat:
            return thermostatStatus(for: service)
        case ServiceTypes.humidifierDehumidifier:
            return humidifierStatus(for: service)
        case ServiceTypes.windowCovering:
            return windowCoveringStatus(for: service)
        case ServiceTypes.lock:
            return lockStatus(for: service)
        case ServiceTypes.garageDoorOpener:
            return garageDoorStatus(for: service)
        case ServiceTypes.securitySystem:
            return securitySystemStatus(for: service)
        case ServiceTypes.airPurifier:
            return airPurifierStatus(for: service)
        default:
            // For lights, switches, outlets, fans, valves, etc. - check on/off state
            let isOn = getOnOffState(for: service)
            return (IconResolver.icon(for: service, filled: isOn), nil)
        }
    }

    /// Get on/off state for a service by checking powerStateId or activeId
    func getOnOffState(for service: ServiceData) -> Bool {
        // Check powerStateId first (lights, switches, outlets)
        if let powerId = service.powerStateId.flatMap({ UUID(uuidString: $0) }),
           let power = cachedValues[powerId] as? Int ?? (cachedValues[powerId] as? Double).map({ Int($0) }) ?? (cachedValues[powerId] as? Bool).map({ $0 ? 1 : 0 }) {
            return power != 0
        }
        // Check activeId (fans, valves, purifiers)
        if let activeId = service.activeId.flatMap({ UUID(uuidString: $0) }),
           let active = cachedValues[activeId] as? Int ?? (cachedValues[activeId] as? Double).map({ Int($0) }) ?? (cachedValues[activeId] as? Bool).map({ $0 ? 1 : 0 }) {
            return active != 0
        }
        return false
    }

    private func heaterCoolerStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        // Get current temperature
        var tempText: String?
        if let tempId = service.currentTemperatureId.flatMap({ UUID(uuidString: $0) }),
           let temp = cachedValues[tempId] as? Double ?? (cachedValues[tempId] as? Int).map({ Double($0) }) {
            tempText = formatTemperature(temp)
        }

        // Check if active (on/off)
        var isActive = false
        if let activeId = service.activeId.flatMap({ UUID(uuidString: $0) }),
           let active = cachedValues[activeId] as? Int ?? (cachedValues[activeId] as? Double).map({ Int($0) }) ?? (cachedValues[activeId] as? Bool).map({ $0 ? 1 : 0 }) {
            isActive = active != 0
        }

        // When OFF, use default icon from centralized config
        if !isActive {
            return (IconResolver.icon(for: service, filled: false), tempText)
        }

        // Get mode icon from centralized config
        var modeIcon: NSImage?
        if let modeId = service.targetHeaterCoolerStateId.flatMap({ UUID(uuidString: $0) }),
           let modeValue = cachedValues[modeId] as? Int ?? (cachedValues[modeId] as? Double).map({ Int($0) }) {
            // 0 = auto, 1 = heat, 2 = cool
            let mode: String = switch modeValue {
            case 1: "heat"
            case 2: "cool"
            default: "auto"
            }
            modeIcon = PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: true)
        }

        return (modeIcon ?? IconResolver.icon(for: service, filled: true), tempText)
    }

    private func thermostatStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        var tempText: String?
        if let tempId = service.currentTemperatureId.flatMap({ UUID(uuidString: $0) }),
           let temp = cachedValues[tempId] as? Double ?? (cachedValues[tempId] as? Int).map({ Double($0) }) {
            tempText = formatTemperature(temp)
        }

        // Get mode icon from centralized config
        var modeIcon: NSImage?
        if let modeId = service.targetHeatingCoolingStateId.flatMap({ UUID(uuidString: $0) }),
           let modeValue = cachedValues[modeId] as? Int ?? (cachedValues[modeId] as? Double).map({ Int($0) }) {
            // 0 = off, 1 = heat, 2 = cool, 3 = auto
            if modeValue == 0 {
                // Off - use default icon
                modeIcon = IconResolver.icon(for: service, filled: false)
            } else {
                let mode: String = switch modeValue {
                case 1: "heat"
                case 2: "cool"
                default: "auto"
                }
                modeIcon = PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: true)
            }
        }

        return (modeIcon ?? IconResolver.icon(for: service, filled: false), tempText)
    }

    private func humidifierStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        var humidityText: String?
        if let humidityId = service.humidityId.flatMap({ UUID(uuidString: $0) }),
           let humidity = cachedValues[humidityId] as? Double ?? (cachedValues[humidityId] as? Int).map({ Double($0) }) {
            humidityText = "\(Int(humidity))%"
        }

        // Check if active (on/off)
        let isActive = getOnOffState(for: service)

        // When OFF, use default icon from centralized config
        if !isActive {
            return (IconResolver.icon(for: service, filled: false), humidityText)
        }

        // Get mode icon from centralized config
        // 0 = auto, 1 = humidifier, 2 = dehumidifier
        if let modeId = service.targetHumidifierDehumidifierStateId.flatMap({ UUID(uuidString: $0) }),
           let modeValue = cachedValues[modeId] as? Int ?? (cachedValues[modeId] as? Double).map({ Int($0) }) {
            let mode = modeValue == 2 ? "dehumidify" : "humidify"
            if let icon = PhosphorIcon.modeIcon(for: service.serviceType, mode: mode, filled: true) {
                return (icon, humidityText)
            }
        }

        return (IconResolver.icon(for: service, filled: true), humidityText)
    }

    private func windowCoveringStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        var positionText: String?
        var isOpen = false
        if let posId = service.currentPositionId.flatMap({ UUID(uuidString: $0) }),
           let position = cachedValues[posId] as? Int ?? (cachedValues[posId] as? Double).map({ Int($0) }) {
            positionText = "\(position)%"
            isOpen = position > 0
        }
        // Filled when open, regular when closed
        return (PhosphorIcon.icon("caret-up-down", filled: isOpen), positionText)
    }

    private func lockStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        if let lockId = service.lockCurrentStateId.flatMap({ UUID(uuidString: $0) }),
           let state = cachedValues[lockId] as? Int ?? (cachedValues[lockId] as? Double).map({ Int($0) }) {
            // 0 = unsecured, 1 = secured, 2 = jammed, 3 = unknown
            let icon: NSImage?
            let text: String?
            switch state {
            case 1:
                icon = PhosphorIcon.fill("lock")
                text = nil  // Icon is clear enough when locked
            case 2:
                icon = PhosphorIcon.regular("warning")
                text = "Jammed"
            default:
                icon = PhosphorIcon.regular("lock-open")
                text = nil  // Icon is clear enough when unlocked
            }
            return (icon, text)
        }
        return (IconResolver.icon(for: service), nil)
    }

    private func garageDoorStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        if let doorId = service.currentDoorStateId.flatMap({ UUID(uuidString: $0) }),
           let state = cachedValues[doorId] as? Int ?? (cachedValues[doorId] as? Double).map({ Int($0) }) {
            // 0 = open, 1 = closed, 2 = opening, 3 = closing, 4 = stopped
            let icon: NSImage?
            let text: String?
            switch state {
            case 1:
                icon = PhosphorIcon.fill("garage")
                text = nil
            case 2:
                icon = PhosphorIcon.regular("garage")
                text = "Opening"
            case 3:
                icon = PhosphorIcon.fill("garage")
                text = "Closing"
            case 4:
                icon = PhosphorIcon.regular("garage")
                text = "Stopped"
            default:
                icon = PhosphorIcon.regular("garage")
                text = nil
            }
            return (icon, text)
        }
        return (IconResolver.icon(for: service), nil)
    }

    private func securitySystemStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        if let secId = service.securitySystemCurrentStateId.flatMap({ UUID(uuidString: $0) }),
           let state = cachedValues[secId] as? Int ?? (cachedValues[secId] as? Double).map({ Int($0) }) {
            // 0 = stay arm, 1 = away arm, 2 = night arm, 3 = disarmed, 4 = triggered
            let icon: NSImage?
            let text: String?
            switch state {
            case 0:
                icon = PhosphorIcon.fill("shield-check")
                text = "Stay"
            case 1:
                icon = PhosphorIcon.fill("shield-check")
                text = "Away"
            case 2:
                icon = PhosphorIcon.fill("moon")
                text = "Night"
            case 4:
                icon = PhosphorIcon.fill("shield-warning")
                text = "Alarm!"
            default:
                icon = PhosphorIcon.regular("shield")
                text = nil
            }
            return (icon, text)
        }
        return (IconResolver.icon(for: service), nil)
    }

    private func airPurifierStatus(for service: ServiceData) -> (icon: NSImage?, text: String?) {
        let isActive = getOnOffState(for: service)
        return (IconResolver.icon(for: service, filled: isActive), nil)
    }

    func formatTemperature(_ celsius: Double) -> String {
        // Check user's temperature unit preference (Fahrenheit for US locale, Celsius otherwise)
        let useFahrenheit = Locale.current.measurementSystem == .us
        if useFahrenheit {
            let fahrenheit = celsius * 9 / 5 + 32
            return "\(Int(round(fahrenheit)))°"
        } else {
            return "\(Int(round(celsius)))°"
        }
    }
}
