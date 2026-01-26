//
//  LightMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling lights with brightness slider and color picker
//

import AppKit

class LightMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, ReachabilityUpdatableMenuItem, LocalChangeNotifiable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var powerCharacteristicId: UUID?
    private var brightnessCharacteristicId: UUID?
    private var hueCharacteristicId: UUID?
    private var saturationCharacteristicId: UUID?
    private var colorTempCharacteristicId: UUID?
    private var colorTempMin: Double = 153
    private var colorTempMax: Double = 500

    private var isOn: Bool = false
    private var brightness: Double = 100
    private var hue: Double = 0
    private var saturation: Double = 100
    private var colorTemp: Double = 300

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let colorCircle: ClickableColorCircleView
    private let brightnessSlider: ModernSlider
    private let toggleSwitch: ToggleSwitch
    private let colorControlsRow: NSView
    private var colorPickerView: NSView?
    private let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private var expandedHeight: CGFloat = DS.ControlSize.menuItemHeight
    private var isColorPickerExpanded: Bool = false

    private let hasBrightness: Bool
    private let hasRGB: Bool
    private let hasColorTemp: Bool
    private var hasColor: Bool { hasRGB || hasColorTemp }

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = powerCharacteristicId { ids.append(id) }
        if let id = brightnessCharacteristicId { ids.append(id) }
        if let id = hueCharacteristicId { ids.append(id) }
        if let id = saturationCharacteristicId { ids.append(id) }
        if let id = colorTempCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        self.powerCharacteristicId = serviceData.powerStateId.flatMap { UUID(uuidString: $0) }
        self.brightnessCharacteristicId = serviceData.brightnessId.flatMap { UUID(uuidString: $0) }
        self.hueCharacteristicId = serviceData.hueId.flatMap { UUID(uuidString: $0) }
        self.saturationCharacteristicId = serviceData.saturationId.flatMap { UUID(uuidString: $0) }
        self.colorTempCharacteristicId = serviceData.colorTemperatureId.flatMap { UUID(uuidString: $0) }
        if let min = serviceData.colorTemperatureMin { self.colorTempMin = min }
        if let max = serviceData.colorTemperatureMax { self.colorTempMax = max }
        self.colorTemp = (self.colorTempMin + self.colorTempMax) / 2

        self.hasBrightness = brightnessCharacteristicId != nil
        self.hasRGB = hueCharacteristicId != nil && saturationCharacteristicId != nil
        self.hasColorTemp = colorTempCharacteristicId != nil

        let height: CGFloat = collapsedHeight
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Toggle switch (rightmost)
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let fullLabelWidth = switchX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: fullLabelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Brightness slider
        let sliderWidth = DS.ControlSize.sliderWidth
        let sliderX = switchX - sliderWidth - DS.Spacing.sm
        let sliderY = (height - 12) / 2
        brightnessSlider = ModernSlider(minValue: 0, maxValue: 100)
        brightnessSlider.frame = NSRect(x: sliderX, y: sliderY, width: sliderWidth, height: 12)
        brightnessSlider.doubleValue = 100
        brightnessSlider.isContinuous = false
        brightnessSlider.isHidden = true
        brightnessSlider.progressTintColor = DS.Colors.sliderLight
        if hasBrightness {
            containerView.addSubview(brightnessSlider)
        }

        // Color circle (before slider)
        let colorCircleSize: CGFloat = 14
        let colorCircleX = sliderX - colorCircleSize - DS.Spacing.xs
        let colorCircleY = (height - colorCircleSize) / 2
        colorCircle = ClickableColorCircleView(frame: NSRect(x: colorCircleX, y: colorCircleY, width: colorCircleSize, height: colorCircleSize))
        colorCircle.wantsLayer = true
        colorCircle.layer?.cornerRadius = colorCircleSize / 2
        colorCircle.layer?.backgroundColor = NSColor.white.cgColor
        colorCircle.isHidden = true
        containerView.addSubview(colorCircle)

        // Color controls row (expanded section)
        colorControlsRow = NSView(frame: .zero)
        colorControlsRow.isHidden = true

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")
        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isOn.toggle()
            self.toggleSwitch.setOn(self.isOn, animated: true)
            if let id = self.powerCharacteristicId {
                self.bridge?.writeCharacteristic(identifier: id, value: self.isOn)
                self.notifyLocalChange(characteristicId: id, value: self.isOn)
            }
            self.updateUI()
        }

        brightnessSlider.target = self
        brightnessSlider.action = #selector(sliderChanged(_:))
        toggleSwitch.target = self
        toggleSwitch.action = #selector(togglePower(_:))

        colorCircle.onClick = { [weak self] in
            self?.toggleColorPicker()
        }

        if hasColor {
            setupColorControlsRow()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupColorControlsRow() {
        if hasRGB {
            let picker = ColorWheelPickerView(
                hue: hue,
                saturation: saturation,
                onColorChanged: { [weak self] newHue, newSat, isFinal in
                    self?.handleRGBColorChange(hue: newHue, saturation: newSat, commit: isFinal)
                }
            )
            colorPickerView = picker
        } else if hasColorTemp {
            let picker = ColorTempPickerView(
                currentMired: colorTemp,
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
            colorControlsRow.frame = NSRect(x: 0, y: padding, width: DS.ControlSize.menuItemWidth, height: size.height)
            picker.frame = NSRect(
                x: (DS.ControlSize.menuItemWidth - size.width) / 2,
                y: 0,
                width: size.width,
                height: size.height
            )
            colorControlsRow.addSubview(picker)
            containerView.addSubview(colorControlsRow)
            expandedHeight = collapsedHeight + size.height + padding * 2
        }
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == powerCharacteristicId {
            if let power = ValueConversion.toBool(value) {
                isOn = power
                updateUI()
            }
        } else if characteristicId == brightnessCharacteristicId {
            if let newBrightness = ValueConversion.toDouble(value) {
                brightness = newBrightness
                brightnessSlider.doubleValue = newBrightness
            }
        } else if characteristicId == hueCharacteristicId {
            if let newHue = ValueConversion.toDouble(value) {
                hue = newHue
                updateColorCircle()
                (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: hue, saturation: saturation)
            }
        } else if characteristicId == saturationCharacteristicId {
            if let newSaturation = ValueConversion.toDouble(value) {
                saturation = newSaturation
                updateColorCircle()
                (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: hue, saturation: saturation)
            }
        } else if characteristicId == colorTempCharacteristicId {
            if let newColorTemp = ValueConversion.toDouble(value) {
                colorTemp = newColorTemp
                updateColorCircle()
                (colorPickerView as? ColorTempPickerView)?.updateMired(colorTemp)
            }
        }
    }

    private func updateUI() {
        iconView.image = IconMapping.iconForServiceType(serviceData.serviceType, filled: isOn)
        toggleSwitch.setOn(isOn, animated: false)

        let showSlider = isOn && hasBrightness
        let showColorCircle = isOn && hasColor
        brightnessSlider.isHidden = !showSlider
        colorCircle.isHidden = !showColorCircle
        if !showColorCircle {
            isColorPickerExpanded = false
        }

        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let sliderWidth = DS.ControlSize.sliderWidth
        let colorCircleSize: CGFloat = 14
        let newHeight = (isColorPickerExpanded && showColorCircle) ? expandedHeight : collapsedHeight
        containerView.frame.size.height = newHeight
        colorControlsRow.isHidden = !(isColorPickerExpanded && showColorCircle)

        let topAreaY = newHeight - collapsedHeight
        let iconY = topAreaY + (collapsedHeight - DS.ControlSize.iconMedium) / 2
        let labelY = topAreaY + (collapsedHeight - 17) / 2
        let sliderY = topAreaY + (collapsedHeight - 12) / 2
        let switchY = topAreaY + (collapsedHeight - DS.ControlSize.switchHeight) / 2
        let colorCircleY = topAreaY + (collapsedHeight - colorCircleSize) / 2

        iconView.frame.origin.y = iconY
        nameLabel.frame.origin.y = labelY
        brightnessSlider.frame.origin.y = sliderY
        toggleSwitch.frame.origin.y = switchY
        colorCircle.frame.origin.y = colorCircleY

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

    private func toggleColorPicker() {
        guard hasColor, isOn else { return }
        isColorPickerExpanded.toggle()
        updateUI()
        if let menu = menu {
            menu.itemChanged(self)
        }
    }

    private func updateColorCircle() {
        let color: NSColor
        if hasRGB {
            color = NSColor(hue: hue / 360.0, saturation: saturation / 100.0, brightness: 1.0, alpha: 1.0)
        } else if hasColorTemp {
            color = ColorConversion.miredToColor(colorTemp)
        } else {
            color = .white
        }
        colorCircle.layer?.backgroundColor = color.cgColor
    }

    @objc private func sliderChanged(_ sender: ModernSlider) {
        let value = sender.doubleValue
        brightness = value
        if let id = brightnessCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: Int(value))
            notifyLocalChange(characteristicId: id, value: Int(value))
        }
        if value > 0 && !isOn, let powerId = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: powerId, value: true)
            isOn = true
            notifyLocalChange(characteristicId: powerId, value: true)
            updateUI()
        }
    }

    @objc private func togglePower(_ sender: ToggleSwitch) {
        isOn = sender.isOn
        if let id = powerCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: isOn)
            notifyLocalChange(characteristicId: id, value: isOn)
        }
        updateUI()
    }

    private func handleRGBColorChange(hue newHue: Double, saturation newSat: Double, commit: Bool) {
        hue = newHue
        saturation = newSat
        updateColorCircle()
        if commit {
            if let hueId = hueCharacteristicId {
                bridge?.writeCharacteristic(identifier: hueId, value: Float(newHue))
                notifyLocalChange(characteristicId: hueId, value: Float(newHue))
            }
            if let satId = saturationCharacteristicId {
                bridge?.writeCharacteristic(identifier: satId, value: Float(newSat))
                notifyLocalChange(characteristicId: satId, value: Float(newSat))
            }
        }
    }

    private func setColorTemp(_ mired: Double) {
        colorTemp = mired
        if let tempId = colorTempCharacteristicId {
            bridge?.writeCharacteristic(identifier: tempId, value: Int(mired))
            notifyLocalChange(characteristicId: tempId, value: Int(mired))
        }
        updateColorCircle()
    }
}
