//
//  GroupMenuItem.swift
//  macOSBridge
//
//  Menu item for device groups - shows a single control that affects all devices
//

import AppKit

class GroupMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable {

    private let group: DeviceGroup
    private let menuData: MenuData
    weak var bridge: Mac2iOS?

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField  // Shows "2/3" when partial

    private var toggleSwitch: ToggleSwitch?
    private var positionSlider: ModernSlider?

    // Light group controls
    private var brightnessSlider: ModernSlider?
    private var colorCircle: ClickableColorCircleView?
    private var colorControlsRow: NSView?
    private var colorPickerView: NSView?
    private var isColorPickerExpanded: Bool = false
    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private var expandedHeight: CGFloat = DS.ControlSize.menuItemHeight

    private let commonType: String?

    // Light group capabilities (all lights must have these for group to support)
    private let hasBrightness: Bool
    private let hasRGB: Bool
    private let hasColorTemp: Bool
    private var hasColor: Bool { hasRGB || hasColorTemp }

    // Track state of each device: characteristicId -> isOn
    private var deviceStates: [UUID: Bool] = [:]
    private var characteristicToService: [UUID: String] = [:]  // characteristicId -> serviceId

    // For blinds: track positions separately
    private var positionStates: [UUID: Int] = [:]  // currentPositionId -> position
    private var targetPositionIds: [UUID] = []  // targetPositionIds for writing
    private var ignorePositionUpdatesUntil: Date?  // Ignore HomeKit updates while blinds are moving

    // For lights: track brightness, hue, saturation, color temp
    private var brightnessStates: [UUID: Double] = [:]  // brightnessId -> brightness
    private var brightnessIds: [UUID] = []  // for writing
    private var hueStates: [UUID: Double] = [:]  // hueId -> hue
    private var hueIds: [UUID] = []
    private var saturationStates: [UUID: Double] = [:]  // satId -> saturation
    private var saturationIds: [UUID] = []
    private var colorTempStates: [UUID: Double] = [:]  // colorTempId -> mired
    private var colorTempIds: [UUID] = []
    private var colorTempMin: Double = 153
    private var colorTempMax: Double = 500

    // Current averaged values for UI
    private var currentBrightness: Double = 100
    private var currentHue: Double = 0
    private var currentSaturation: Double = 100
    private var currentColorTemp: Double = 300

    var characteristicIdentifiers: [UUID] {
        return Array(deviceStates.keys) + Array(positionStates.keys) +
               Array(brightnessStates.keys) + Array(hueStates.keys) +
               Array(saturationStates.keys) + Array(colorTempStates.keys)
    }

    init(group: DeviceGroup, menuData: MenuData, bridge: Mac2iOS?) {
        self.group = group
        self.menuData = menuData
        self.bridge = bridge
        self.commonType = group.commonServiceType(in: menuData)

        // Determine light group capabilities (all lights must support for group to show control)
        let services = group.resolveServices(in: menuData)
        let isLightGroup = self.commonType == ServiceTypes.lightbulb
        if isLightGroup && !services.isEmpty {
            self.hasBrightness = services.allSatisfy { $0.brightnessId != nil }
            self.hasRGB = services.allSatisfy { $0.hueId != nil && $0.saturationId != nil }
            self.hasColorTemp = !self.hasRGB && services.allSatisfy { $0.colorTemperatureId != nil }
        } else {
            self.hasBrightness = false
            self.hasRGB = false
            self.hasColorTemp = false
        }

        let height = DS.ControlSize.menuItemHeight
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = PhosphorIcon.regular(group.icon)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        nameLabel = NSTextField(labelWithString: group.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: 100, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Status label (for "2/3" indicator)
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = DS.Colors.mutedForeground
        statusLabel.alignment = .right
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)

        super.init(title: group.name, action: nil, keyEquivalent: "")
        self.view = containerView


        // Initialize device states from bridge
        initializeDeviceStates()

        // Add appropriate control based on group type
        setupControl(height: height, labelX: labelX)
        updateUI()

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            if self.commonType == ServiceTypes.windowCovering {
                // Blinds group: toggle between 0/100
                let avgPosition = self.positionStates.values.reduce(0, +) / max(self.positionStates.count, 1)
                let newPosition = avgPosition > 50 ? 0 : 100
                self.positionSlider?.doubleValue = Double(newPosition)
                let services = self.group.resolveServices(in: self.menuData)
                for (currentId, _) in self.positionStates {
                    self.positionStates[currentId] = newPosition
                    self.notifyLocalChange(characteristicId: currentId, value: newPosition)
                }
                for service in services {
                    if let idString = service.targetPositionId, let id = UUID(uuidString: idString) {
                        self.bridge?.writeCharacteristic(identifier: id, value: newPosition)
                    }
                }
                self.updateBlindsIcon(position: newPosition)
            } else {
                // Toggle all devices on/off
                let anyOn = self.deviceStates.values.contains(true)
                let newState = !anyOn
                self.toggleSwitch?.setOn(newState, animated: true)
                let services = self.group.resolveServices(in: self.menuData)
                for service in services {
                    if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
                        self.deviceStates[id] = newState
                        self.bridge?.writeCharacteristic(identifier: id, value: newState)
                        self.notifyLocalChange(characteristicId: id, value: newState)
                    } else if let idString = service.activeId, let id = UUID(uuidString: idString) {
                        self.deviceStates[id] = newState
                        self.bridge?.writeCharacteristic(identifier: id, value: newState ? 1 : 0)
                        self.notifyLocalChange(characteristicId: id, value: newState ? 1 : 0)
                    }
                }
                self.updateUI()
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initializeDeviceStates() {
        let services = group.resolveServices(in: menuData)
        for service in services {
            // For blinds: track position
            if service.serviceType == ServiceTypes.windowCovering {
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
            }

            // For lights: track brightness and color characteristics
            if service.serviceType == ServiceTypes.lightbulb {
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
        }
        // Calculate average values from cached states
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

    private func setupControl(height: CGFloat, labelX: CGFloat) {
        switch commonType {
        case ServiceTypes.windowCovering:
            // Slider for blinds
            let sliderWidth = DS.ControlSize.sliderWidth
            let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md
            let sliderY = (height - 12) / 2

            let slider = ModernSlider(minValue: 0, maxValue: 100)
            slider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
            // Use cached average position
            let avgPosition = positionStates.isEmpty ? 0 : positionStates.values.reduce(0, +) / positionStates.count
            slider.doubleValue = Double(avgPosition)
            slider.progressTintColor = DS.Colors.sliderBlind
            slider.isContinuous = false
            slider.target = self
            slider.action = #selector(positionSliderChanged(_:))
            containerView.addSubview(slider)
            positionSlider = slider

            // Status label position
            statusLabel.frame = NSRect(x: sliderX - 40, y: (height - 17) / 2, width: 35, height: 17)
            nameLabel.frame.size.width = sliderX - 45 - labelX - DS.Spacing.sm

        case ServiceTypes.lightbulb:
            // Toggle switch (rightmost)
            let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
            let switchY = (height - DS.ControlSize.switchHeight) / 2

            let toggle = ToggleSwitch()
            toggle.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
            // Use cached state
            let isOn = deviceStates.values.contains(true)
            toggle.setOn(isOn, animated: false)
            toggle.target = self
            toggle.action = #selector(toggleChanged(_:))
            containerView.addSubview(toggle)
            toggleSwitch = toggle

            // Brightness slider (if all lights support it)
            let sliderWidth = DS.ControlSize.sliderWidth
            let sliderX = switchX - sliderWidth - DS.Spacing.sm
            let sliderY = (height - 12) / 2

            let slider = ModernSlider(minValue: 0, maxValue: 100)
            slider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
            slider.doubleValue = currentBrightness
            slider.progressTintColor = DS.Colors.sliderLight
            slider.isContinuous = false
            slider.isHidden = true  // Show only when lights are on
            slider.target = self
            slider.action = #selector(brightnessSliderChanged(_:))
            if hasBrightness {
                containerView.addSubview(slider)
            }
            brightnessSlider = slider

            // Color circle (if all lights support color)
            if hasColor {
                let colorCircleSize: CGFloat = 14
                let colorCircleX = sliderX - colorCircleSize - DS.Spacing.xs
                let colorCircleY = (height - colorCircleSize) / 2

                let circle = ClickableColorCircleView(frame: NSRect(x: colorCircleX, y: colorCircleY, width: colorCircleSize, height: colorCircleSize))
                circle.wantsLayer = true
                circle.layer?.cornerRadius = colorCircleSize / 2
                circle.layer?.backgroundColor = NSColor.white.cgColor
                circle.isHidden = true  // Show only when lights are on
                circle.onClick = { [weak self] in
                    self?.toggleColorPicker()
                }
                containerView.addSubview(circle)
                colorCircle = circle

                setupColorControlsRow()
            }

            // Status label position (before controls)
            let controlsStartX = hasColor ? (sliderX - 14 - DS.Spacing.xs) : sliderX
            statusLabel.frame = NSRect(x: controlsStartX - 40, y: (height - 17) / 2, width: 35, height: 17)
            nameLabel.frame.size.width = controlsStartX - 45 - labelX - DS.Spacing.sm

        default:
            // Toggle switch
            let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
            let switchY = (height - DS.ControlSize.switchHeight) / 2

            let toggle = ToggleSwitch()
            toggle.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
            // Use cached state
            let isOn = deviceStates.values.contains(true)
            toggle.setOn(isOn, animated: false)
            toggle.target = self
            toggle.action = #selector(toggleChanged(_:))
            containerView.addSubview(toggle)
            toggleSwitch = toggle

            // Status label position (before toggle)
            statusLabel.frame = NSRect(x: switchX - 40, y: (height - 17) / 2, width: 35, height: 17)
            nameLabel.frame.size.width = switchX - 45 - labelX - DS.Spacing.sm
        }
    }

    private func setupColorControlsRow() {
        let row = NSView(frame: .zero)
        row.isHidden = true
        colorControlsRow = row

        if hasRGB {
            let picker = ColorWheelPickerView(
                hue: currentHue,
                saturation: currentSaturation,
                onColorChanged: { [weak self] newHue, newSat, isFinal in
                    self?.handleRGBColorChange(hue: newHue, saturation: newSat, commit: isFinal)
                }
            )
            colorPickerView = picker
        } else if hasColorTemp {
            let picker = ColorTempPickerView(
                currentMired: currentColorTemp,
                minMired: colorTempMin,
                maxMired: colorTempMax,
                onTempChanged: { [weak self] newMired in
                    self?.setColorTemp(newMired)
                }
            )
            colorPickerView = picker
        }

        if let picker = colorPickerView {
            let size = picker.intrinsicContentSize
            let padding: CGFloat = 4
            row.frame = NSRect(x: 0, y: padding, width: DS.ControlSize.menuItemWidth, height: size.height)
            picker.frame = NSRect(
                x: (DS.ControlSize.menuItemWidth - size.width) / 2,
                y: 0,
                width: size.width,
                height: size.height
            )
            row.addSubview(picker)
            containerView.addSubview(row)
            expandedHeight = collapsedHeight + size.height + padding * 2
        }
    }

    // Called when characteristic values change
    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool) {
        // Update position state for blinds
        if positionStates.keys.contains(characteristicId) {
            if let pos = ValueConversion.toInt(value) {
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
            return
        }

        // Update power state for other devices
        if deviceStates.keys.contains(characteristicId) {
            if let boolValue = ValueConversion.toBool(value) {
                deviceStates[characteristicId] = boolValue
            } else if let intValue = value as? Int {
                deviceStates[characteristicId] = intValue != 0
            }
            updateUI()
            return
        }

        // Update brightness
        if brightnessStates.keys.contains(characteristicId) {
            if let newBrightness = ValueConversion.toDouble(value) {
                brightnessStates[characteristicId] = newBrightness
                currentBrightness = brightnessStates.values.reduce(0, +) / Double(brightnessStates.count)
                brightnessSlider?.doubleValue = currentBrightness
            }
            return
        }

        // Update hue
        if hueStates.keys.contains(characteristicId) {
            if let newHue = ValueConversion.toDouble(value) {
                hueStates[characteristicId] = newHue
                currentHue = hueStates.values.reduce(0, +) / Double(hueStates.count)
                updateColorCircle()
                (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: currentHue, saturation: currentSaturation)
            }
            return
        }

        // Update saturation
        if saturationStates.keys.contains(characteristicId) {
            if let newSat = ValueConversion.toDouble(value) {
                saturationStates[characteristicId] = newSat
                currentSaturation = saturationStates.values.reduce(0, +) / Double(saturationStates.count)
                updateColorCircle()
                (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: currentHue, saturation: currentSaturation)
            }
            return
        }

        // Update color temperature
        if colorTempStates.keys.contains(characteristicId) {
            if let newTemp = ValueConversion.toDouble(value) {
                colorTempStates[characteristicId] = newTemp
                currentColorTemp = colorTempStates.values.reduce(0, +) / Double(colorTempStates.count)
                updateColorCircle()
                (colorPickerView as? ColorTempPickerView)?.updateMired(currentColorTemp)
            }
            return
        }
    }

    private func updateUI() {
        let total = deviceStates.count
        let onCount = deviceStates.values.filter { $0 }.count
        let allOn = onCount == total
        let allOff = onCount == 0
        let isOn = onCount > 0

        // Update toggle
        toggleSwitch?.setOn(isOn, animated: false)

        // Update icon
        switch commonType {
        case ServiceTypes.windowCovering:
            // For blinds, use position states
            let avgPosition = positionStates.isEmpty ? 0 : positionStates.values.reduce(0, +) / positionStates.count
            updateBlindsIcon(position: avgPosition)
        case ServiceTypes.lightbulb:
            iconView.image = IconMapping.iconForServiceType(ServiceTypes.lightbulb, filled: isOn)
        case ServiceTypes.fan:
            iconView.image = IconMapping.iconForServiceType(ServiceTypes.fan, filled: isOn)
        case ServiceTypes.lock:
            let mode = isOn ? "locked" : "unlocked"
            iconView.image = PhosphorIcon.modeIcon(for: ServiceTypes.lock, mode: mode, filled: isOn)
                ?? IconMapping.iconForServiceType(ServiceTypes.lock, filled: isOn)
        default:
            // Use group's custom icon
            iconView.image = PhosphorIcon.icon(group.icon, filled: isOn)
        }

        // Show "2/3" if partial
        if !allOn && !allOff {
            statusLabel.stringValue = "\(onCount)/\(total)"
            statusLabel.isHidden = false
        } else {
            statusLabel.isHidden = true
        }

        // Light group specific: show/hide brightness slider and color circle
        if commonType == ServiceTypes.lightbulb {
            let showSlider = isOn && hasBrightness
            let showColorCircle = isOn && hasColor

            brightnessSlider?.isHidden = !showSlider
            colorCircle?.isHidden = !showColorCircle

            // Collapse color picker if lights turned off
            if !showColorCircle {
                isColorPickerExpanded = false
            }

            // Update layout for expanded/collapsed state
            let newHeight = (isColorPickerExpanded && showColorCircle) ? expandedHeight : collapsedHeight
            containerView.frame.size.height = newHeight
            colorControlsRow?.isHidden = !(isColorPickerExpanded && showColorCircle)

            // Update vertical positions for controls
            let topAreaY = newHeight - collapsedHeight
            let iconY = topAreaY + (collapsedHeight - DS.ControlSize.iconMedium) / 2
            let labelY = topAreaY + (collapsedHeight - 17) / 2
            let sliderY = topAreaY + (collapsedHeight - 12) / 2
            let switchY = topAreaY + (collapsedHeight - DS.ControlSize.switchHeight) / 2
            let colorCircleSize: CGFloat = 14
            let colorCircleY = topAreaY + (collapsedHeight - colorCircleSize) / 2

            iconView.frame.origin.y = iconY
            nameLabel.frame.origin.y = labelY
            brightnessSlider?.frame.origin.y = sliderY
            toggleSwitch?.frame.origin.y = switchY
            colorCircle?.frame.origin.y = colorCircleY
            statusLabel.frame.origin.y = labelY

            // Update name label width based on visible controls
            let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
            let sliderWidth = DS.ControlSize.sliderWidth
            let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm

            var rightEdge = switchX - DS.Spacing.sm
            if showSlider {
                rightEdge = switchX - sliderWidth - DS.Spacing.sm - DS.Spacing.xs
            }
            if showColorCircle {
                rightEdge = rightEdge - colorCircleSize - DS.Spacing.xs
            }
            nameLabel.frame.size.width = rightEdge - labelX

            if showColorCircle {
                updateColorCircle()
            }
        }
    }

    @objc private func toggleChanged(_ sender: ToggleSwitch) {
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

    @objc private func positionSliderChanged(_ sender: ModernSlider) {
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

    @objc private func brightnessSliderChanged(_ sender: ModernSlider) {
        let value = sender.doubleValue
        currentBrightness = value
        guard let bridge = bridge else { return }

        // Update local brightness states and notify
        for id in brightnessIds {
            brightnessStates[id] = value
            notifyLocalChange(characteristicId: id, value: Int(value))
        }

        // Write to all brightness characteristics
        for id in brightnessIds {
            bridge.writeCharacteristic(identifier: id, value: Int(value))
        }

        // Turn on lights if slider moved and lights are off
        if value > 0 && deviceStates.values.allSatisfy({ !$0 }) {
            let services = group.resolveServices(in: menuData)
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

    private func toggleColorPicker() {
        guard hasColor, deviceStates.values.contains(true) else { return }
        isColorPickerExpanded.toggle()
        updateUI()
        if let menu = menu {
            menu.itemChanged(self)
        }
    }

    private func updateColorCircle() {
        let color: NSColor
        if hasRGB {
            color = NSColor(hue: currentHue / 360.0, saturation: currentSaturation / 100.0, brightness: 1.0, alpha: 1.0)
        } else if hasColorTemp {
            color = ColorConversion.miredToColor(currentColorTemp)
        } else {
            color = .white
        }
        colorCircle?.layer?.backgroundColor = color.cgColor
    }

    private func handleRGBColorChange(hue newHue: Double, saturation newSat: Double, commit: Bool) {
        currentHue = newHue
        currentSaturation = newSat
        updateColorCircle()

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

    private func setColorTemp(_ mired: Double) {
        currentColorTemp = mired
        updateColorCircle()

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

    private func updateBlindsIcon(position: Int) {
        let isOpen = position > 0
        iconView.image = IconMapping.iconForServiceType(ServiceTypes.windowCovering, filled: isOpen)
    }
}
