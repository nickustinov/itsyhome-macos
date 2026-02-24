//
//  GroupMenuItem+StateManagement.swift
//  macOSBridge
//
//  Device state initialization and characteristic updates for group menu items
//

import AppKit

extension GroupMenuItem {

    func initializeDeviceStates() {
        let services = group.resolveServices(in: menuData)
        for service in services {
            // For blinds/door/window: track position
            if service.serviceType == ServiceTypes.windowCovering ||
               service.serviceType == ServiceTypes.door ||
               service.serviceType == ServiceTypes.window {
                if let currentIdString = service.currentPositionId,
                   let currentId = UUID(uuidString: currentIdString) {
                    // Use cached value if available
                    if let cachedValue = bridge?.getCharacteristicValue(identifier: currentId) {
                        positionStates[currentId] = ValueConversion.toInt(cachedValue) ?? 0
                    } else {
                        positionStates[currentId] = 0
                    }
                }
                if let targetIdString = service.targetPositionId,
                   let targetId = UUID(uuidString: targetIdString) {
                    targetPositionIds.append(targetId)
                }
            }
            // For power-based devices (lights, switches, etc.)
            else if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
                // Use cached value if available
                if let cachedValue = bridge?.getCharacteristicValue(identifier: id) {
                    deviceStates[id] = ValueConversion.toBool(cachedValue) ?? false
                } else {
                    deviceStates[id] = false
                }
                characteristicToService[id] = service.uniqueIdentifier
            } else if let idString = service.activeId, let id = UUID(uuidString: idString) {
                // Use cached value if available
                if let cachedValue = bridge?.getCharacteristicValue(identifier: id),
                   let intValue = cachedValue as? Int {
                    deviceStates[id] = intValue != 0
                } else if let cachedValue = bridge?.getCharacteristicValue(identifier: id) {
                    deviceStates[id] = ValueConversion.toBool(cachedValue) ?? false
                } else {
                    deviceStates[id] = false
                }
                characteristicToService[id] = service.uniqueIdentifier
            } else if let idString = service.lockCurrentStateId, let id = UUID(uuidString: idString) {
                // Locks: 1 = locked (on), 0 = unlocked (off)
                if let cachedValue = bridge?.getCharacteristicValue(identifier: id),
                   let intValue = ValueConversion.toInt(cachedValue) {
                    deviceStates[id] = intValue == 1
                } else {
                    deviceStates[id] = true
                }
                characteristicToService[id] = service.uniqueIdentifier
            }

            // For lights: track brightness and color characteristics
            if service.serviceType == ServiceTypes.lightbulb {
                initializeLightCharacteristics(for: service)
            }
        }
        calculateAverageValues()
    }

    private func initializeLightCharacteristics(for service: ServiceData) {
        if let idString = service.brightnessId, let id = UUID(uuidString: idString) {
            if let cachedValue = bridge?.getCharacteristicValue(identifier: id) {
                brightnessStates[id] = ValueConversion.toDouble(cachedValue) ?? 100
            } else {
                brightnessStates[id] = 100
            }
            brightnessIds.append(id)
        }
        if let idString = service.hueId, let id = UUID(uuidString: idString) {
            if let cachedValue = bridge?.getCharacteristicValue(identifier: id) {
                hueStates[id] = ValueConversion.toDouble(cachedValue) ?? 0
            } else {
                hueStates[id] = 0
            }
            hueIds.append(id)
        }
        if let idString = service.saturationId, let id = UUID(uuidString: idString) {
            if let cachedValue = bridge?.getCharacteristicValue(identifier: id) {
                saturationStates[id] = ValueConversion.toDouble(cachedValue) ?? 100
            } else {
                saturationStates[id] = 100
            }
            saturationIds.append(id)
        }
        if let idString = service.colorTemperatureId, let id = UUID(uuidString: idString) {
            // Track color temp range from first light that has it
            if let min = service.colorTemperatureMin {
                colorTempMin = min
            }
            if let max = service.colorTemperatureMax {
                colorTempMax = max
            }
            if let cachedValue = bridge?.getCharacteristicValue(identifier: id) {
                colorTempStates[id] = ValueConversion.toDouble(cachedValue) ?? ((colorTempMin + colorTempMax) / 2)
            } else {
                colorTempStates[id] = (colorTempMin + colorTempMax) / 2
            }
            colorTempIds.append(id)
        }
    }

    private func calculateAverageValues() {
        if !brightnessStates.isEmpty {
            currentBrightness = brightnessStates.values.reduce(0, +) / Double(brightnessStates.count)
        }
        if !hueStates.isEmpty {
            currentHue = hueStates.values.reduce(0, +) / Double(hueStates.count)
        }
        if !saturationStates.isEmpty {
            currentSaturation = saturationStates.values.reduce(0, +) / Double(saturationStates.count)
        }
        if !colorTempStates.isEmpty {
            currentColorTemp = colorTempStates.values.reduce(0, +) / Double(colorTempStates.count)
        } else {
            currentColorTemp = (colorTempMin + colorTempMax) / 2
        }
    }

    // Called when characteristic values change
    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool) {
        // Update position state for blinds
        if positionStates.keys.contains(characteristicId) {
            handlePositionUpdate(characteristicId: characteristicId, value: value, isLocalChange: isLocalChange)
            return
        }

        // Update power state for other devices
        if deviceStates.keys.contains(characteristicId) {
            handlePowerStateUpdate(characteristicId: characteristicId, value: value)
            return
        }

        // Update brightness
        if brightnessStates.keys.contains(characteristicId) {
            handleBrightnessUpdate(characteristicId: characteristicId, value: value)
            return
        }

        // Update hue
        if hueStates.keys.contains(characteristicId) {
            handleHueUpdate(characteristicId: characteristicId, value: value)
            return
        }

        // Update saturation
        if saturationStates.keys.contains(characteristicId) {
            handleSaturationUpdate(characteristicId: characteristicId, value: value)
            return
        }

        // Update color temperature
        if colorTempStates.keys.contains(characteristicId) {
            handleColorTempUpdate(characteristicId: characteristicId, value: value)
            return
        }
    }

    private func handlePositionUpdate(characteristicId: UUID, value: Any, isLocalChange: Bool) {
        guard let pos = ValueConversion.toInt(value) else { return }

        // For local changes, set the ignore window
        if isLocalChange {
            ignorePositionUpdatesUntil = Date().addingTimeInterval(60)
        }

        // Ignore HomeKit updates while waiting for blinds to reach target
        if !isLocalChange, let ignoreUntil = ignorePositionUpdatesUntil, Date() < ignoreUntil {
            return
        }

        positionStates[characteristicId] = pos
        // Update slider with average position
        let avgPosition = positionStates.values.reduce(0, +) / positionStates.count
        positionSlider?.doubleValue = Double(avgPosition)
        updateBlindsIcon(position: avgPosition)
    }

    private func handlePowerStateUpdate(characteristicId: UUID, value: Any) {
        if let boolValue = ValueConversion.toBool(value) {
            deviceStates[characteristicId] = boolValue
        } else if let intValue = value as? Int {
            deviceStates[characteristicId] = intValue != 0
        }
        updateUI()
    }

    private func handleBrightnessUpdate(characteristicId: UUID, value: Any) {
        if let newBrightness = ValueConversion.toDouble(value) {
            brightnessStates[characteristicId] = newBrightness
            currentBrightness = brightnessStates.values.reduce(0, +) / Double(brightnessStates.count)
            brightnessSlider?.doubleValue = currentBrightness
        }
    }

    private func handleHueUpdate(characteristicId: UUID, value: Any) {
        if let newHue = ValueConversion.toDouble(value) {
            hueStates[characteristicId] = newHue
            currentHue = hueStates.values.reduce(0, +) / Double(hueStates.count)
            lastColorSource = "rgb"
            updateSliderColor()
            (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: currentHue, saturation: currentSaturation)
        }
    }

    private func handleSaturationUpdate(characteristicId: UUID, value: Any) {
        if let newSat = ValueConversion.toDouble(value) {
            saturationStates[characteristicId] = newSat
            currentSaturation = saturationStates.values.reduce(0, +) / Double(saturationStates.count)
            lastColorSource = "rgb"
            updateSliderColor()
            (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: currentHue, saturation: currentSaturation)
        }
    }

    private func handleColorTempUpdate(characteristicId: UUID, value: Any) {
        if let newTemp = ValueConversion.toDouble(value) {
            colorTempStates[characteristicId] = newTemp
            currentColorTemp = colorTempStates.values.reduce(0, +) / Double(colorTempStates.count)
            lastColorSource = "temp"
            updateSliderColor()
            (tempPickerView as? ColorTempPickerView)?.updateMired(currentColorTemp)
        }
    }
}
