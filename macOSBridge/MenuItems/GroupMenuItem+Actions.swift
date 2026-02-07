//
//  GroupMenuItem+Actions.swift
//  macOSBridge
//
//  User action handlers for group menu items (toggle, slider, color changes)
//

import AppKit

extension GroupMenuItem {

    @objc func toggleChanged(_ sender: ToggleSwitch) {
        let isOn = sender.isOn
        let services = group.resolveServices(in: menuData)
        guard let bridge = bridge else { return }

        for service in services {
            if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
                deviceStates[id] = isOn
                bridge.writeCharacteristic(identifier: id, value: isOn)
                notifyLocalChange(characteristicId: id, value: isOn)
            } else if let idString = service.activeId, let id = UUID(uuidString: idString) {
                deviceStates[id] = isOn
                bridge.writeCharacteristic(identifier: id, value: isOn ? 1 : 0)
                notifyLocalChange(characteristicId: id, value: isOn ? 1 : 0)
            }
        }

        updateUI()
    }

    @objc func positionSliderChanged(_ sender: ModernSlider) {
        let position = Int(sender.doubleValue)
        let services = group.resolveServices(in: menuData)
        guard let bridge = bridge else { return }

        // Update local position states and notify
        for (currentId, _) in positionStates {
            positionStates[currentId] = position
            notifyLocalChange(characteristicId: currentId, value: position)
        }

        // Write to all target positions
        for service in services {
            if let idString = service.targetPositionId, let id = UUID(uuidString: idString) {
                bridge.writeCharacteristic(identifier: id, value: position)
            }
        }

        updateBlindsIcon(position: position)
    }

    @objc func brightnessSliderChanged(_ sender: ModernSlider) {
        let value = sender.doubleValue
        currentBrightness = value
        guard let bridge = bridge else { return }

        // Only write brightness to lights that are currently on
        let services = group.resolveServices(in: menuData)
        for service in services {
            let isServiceOn: Bool
            if let powerIdStr = service.powerStateId, let powerId = UUID(uuidString: powerIdStr) {
                isServiceOn = deviceStates[powerId] ?? false
            } else {
                isServiceOn = false
            }

            if let brightIdStr = service.brightnessId, let brightId = UUID(uuidString: brightIdStr) {
                brightnessStates[brightId] = value
                if isServiceOn {
                    bridge.writeCharacteristic(identifier: brightId, value: Int(value))
                    notifyLocalChange(characteristicId: brightId, value: Int(value))
                }
            }
        }

        // Turn on all lights if slider moved and all lights are off
        if value > 0 && deviceStates.values.allSatisfy({ !$0 }) {
            for service in services {
                if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
                    deviceStates[id] = true
                    bridge.writeCharacteristic(identifier: id, value: true)
                    notifyLocalChange(characteristicId: id, value: true)
                }
            }
            updateUI()
        }
    }

    func handleRGBColorChange(hue newHue: Double, saturation newSat: Double, commit: Bool) {
        currentHue = newHue
        currentSaturation = newSat
        lastColorSource = "rgb"
        updateSliderColor()

        guard commit, let bridge = bridge else { return }

        // Update local states and notify
        for id in hueIds {
            hueStates[id] = newHue
            notifyLocalChange(characteristicId: id, value: Float(newHue))
        }
        for id in saturationIds {
            saturationStates[id] = newSat
            notifyLocalChange(characteristicId: id, value: Float(newSat))
        }

        // Write to all hue/saturation characteristics
        for id in hueIds {
            bridge.writeCharacteristic(identifier: id, value: Float(newHue))
        }
        for id in saturationIds {
            bridge.writeCharacteristic(identifier: id, value: Float(newSat))
        }
    }

    func setColorTemp(_ mired: Double) {
        currentColorTemp = mired
        lastColorSource = "temp"
        updateSliderColor()

        guard let bridge = bridge else { return }

        // Update local states and notify
        for id in colorTempIds {
            colorTempStates[id] = mired
            notifyLocalChange(characteristicId: id, value: Int(mired))
        }

        // Write to all color temperature characteristics
        for id in colorTempIds {
            bridge.writeCharacteristic(identifier: id, value: Int(mired))
        }
    }

    func updateBlindsIcon(position: Int) {
        let isOpen = position > 0
        if PreferencesManager.shared.customIcon(for: group.id) != nil {
            iconView.image = IconResolver.icon(for: group, filled: isOpen)
        } else {
            iconView.image = IconMapping.iconForServiceType(ServiceTypes.windowCovering, filled: isOpen)
        }
    }
}
