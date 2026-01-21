//
//  LightMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling lights with brightness slider and color picker
//

import AppKit

final class ClickableColorCircleView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

class LightMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, ReachabilityUpdatable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    // ReachabilityUpdatable
    var serviceIdentifier: UUID { UUID(uuidString: serviceData.uniqueIdentifier)! }
    private(set) var isReachable: Bool = true

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

    private let containerView: NSView
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
        self.isReachable = serviceData.isReachable

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
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        iconView.contentTintColor = DS.Colors.mutedForeground
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

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == powerCharacteristicId, let boolValue = value as? Bool {
            isOn = boolValue
            updateUI()
        } else if characteristicId == powerCharacteristicId, let intValue = value as? Int {
            isOn = intValue != 0
            updateUI()
        } else if characteristicId == brightnessCharacteristicId, let doubleValue = value as? Double {
            brightness = doubleValue
            brightnessSlider.doubleValue = doubleValue
        } else if characteristicId == brightnessCharacteristicId, let intValue = value as? Int {
            brightness = Double(intValue)
            brightnessSlider.doubleValue = brightness
        } else if characteristicId == hueCharacteristicId {
            if let v = value as? Double { hue = v }
            else if let v = value as? Int { hue = Double(v) }
            else if let v = value as? Float { hue = Double(v) }
            updateColorCircle()
            (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: hue, saturation: saturation)
        } else if characteristicId == saturationCharacteristicId {
            if let v = value as? Double { saturation = v }
            else if let v = value as? Int { saturation = Double(v) }
            else if let v = value as? Float { saturation = Double(v) }
            updateColorCircle()
            (colorPickerView as? ColorWheelPickerView)?.updateColor(hue: hue, saturation: saturation)
        } else if characteristicId == colorTempCharacteristicId {
            if let v = value as? Double { colorTemp = v }
            else if let v = value as? Int { colorTemp = Double(v) }
            else if let v = value as? Float { colorTemp = Double(v) }
            updateColorCircle()
            (colorPickerView as? ColorTempPickerView)?.updateMired(colorTemp)
        }
    }

    func setReachable(_ reachable: Bool) {
        isReachable = reachable
        updateUI()
    }

    private func updateUI() {
        let dimmed = !isReachable
        let alpha: CGFloat = dimmed ? 0.4 : 1.0

        iconView.image = NSImage(systemSymbolName: isOn ? "lightbulb.fill" : "lightbulb", accessibilityDescription: nil)
        iconView.contentTintColor = isOn ? DS.Colors.lightOn : DS.Colors.mutedForeground
        iconView.alphaValue = alpha
        nameLabel.alphaValue = alpha
        toggleSwitch.setOn(isOn, animated: false)
        toggleSwitch.isEnabled = isReachable
        toggleSwitch.alphaValue = alpha

        let showSlider = isOn && hasBrightness && isReachable
        let showColorCircle = isOn && hasColor && isReachable
        brightnessSlider.isHidden = !showSlider
        brightnessSlider.isEnabled = isReachable
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
        guard hasColor, isOn, isReachable else { return }
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
            color = miredToColor(colorTemp)
        } else {
            color = .white
        }
        colorCircle.layer?.backgroundColor = color.cgColor
    }

    private func miredToColor(_ mired: Double) -> NSColor {
        let normalized = (mired - 50) / 350
        let clamped = max(0, min(1, normalized))
        if clamped < 0.5 {
            let t = clamped * 2
            return NSColor(red: 0.9 + 0.1 * t, green: 0.95 + 0.05 * t, blue: 1.0, alpha: 1.0)
        } else {
            let t = (clamped - 0.5) * 2
            return NSColor(red: 1.0, green: 1.0 - 0.2 * t, blue: 1.0 - 0.5 * t, alpha: 1.0)
        }
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

    private func notifyLocalChange(characteristicId: UUID, value: Any) {
        NotificationCenter.default.post(
            name: .characteristicDidChangeLocally,
            object: self,
            userInfo: ["characteristicId": characteristicId, "value": value]
        )
    }
}

// MARK: - Color Wheel Picker View

class ColorWheelPickerView: NSView {
    private var hue: Double
    private var saturation: Double
    private let onColorChanged: (Double, Double, Bool) -> Void
    private let wheelSize: CGFloat = 120
    private let padding: CGFloat = 8

    init(hue: Double, saturation: Double, onColorChanged: @escaping (Double, Double, Bool) -> Void) {
        self.hue = hue
        self.saturation = saturation
        self.onColorChanged = onColorChanged
        let size = wheelSize + padding * 2
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateColor(hue: Double, saturation: Double) {
        self.hue = hue
        self.saturation = saturation
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: wheelSize + padding * 2, height: wheelSize + padding * 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = wheelSize / 2

        for angle in stride(from: 0, to: 360, by: 1) {
            let hueValue = CGFloat(angle) / 360.0
            NSColor(hue: hueValue, saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
            let path = NSBezierPath()
            path.move(to: center)
            path.appendArc(withCenter: center, radius: radius, startAngle: CGFloat(angle) - 0.5, endAngle: CGFloat(angle) + 0.5, clockwise: false)
            path.close()
            path.fill()
        }

        let innerRadius = radius * 0.3
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)).fill()

        let indicatorAngle = CGFloat(hue) * .pi / 180.0
        let indicatorRadius = radius * (0.3 + 0.7 * CGFloat(saturation / 100.0))
        let indicatorX = center.x + cos(indicatorAngle) * indicatorRadius
        let indicatorY = center.y + sin(indicatorAngle) * indicatorRadius
        let indicatorRect = NSRect(x: indicatorX - 6, y: indicatorY - 6, width: 12, height: 12)
        NSColor.white.setStroke()
        NSColor.black.withAlphaComponent(0.3).setFill()
        let indicator = NSBezierPath(ovalIn: indicatorRect)
        indicator.fill()
        indicator.lineWidth = 2
        indicator.stroke()
    }

    override func mouseDown(with event: NSEvent) { handleMouse(event, isFinal: false) }
    override func mouseDragged(with event: NSEvent) { handleMouse(event, isFinal: false) }
    override func mouseUp(with event: NSEvent) { handleMouse(event, isFinal: true) }

    private func handleMouse(_ event: NSEvent, isFinal: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = wheelSize / 2
        let dx = point.x - center.x
        let dy = point.y - center.y
        var angle = atan2(dy, dx) * 180.0 / .pi
        if angle < 0 { angle += 360 }
        hue = Double(angle)
        saturation = Double(min(sqrt(dx * dx + dy * dy) / radius, 1.0)) * 100.0
        onColorChanged(hue, saturation, isFinal)
        needsDisplay = true
    }
}

// MARK: - Color Temperature Picker View

class ColorTempPickerView: NSView {
    private let onTempChanged: (Double) -> Void
    private var currentMired: Double
    private var selectedIndex: Int = -1
    private let presets: [(name: String, mired: Double)]
    private let circleSize: CGFloat = 32
    private let spacing: CGFloat = 8
    private let padding: CGFloat = 8

    init(currentMired: Double, minMired: Double, maxMired: Double, onTempChanged: @escaping (Double) -> Void) {
        self.currentMired = currentMired
        self.onTempChanged = onTempChanged

        // Generate 5 presets within the device's supported range (warm to cool)
        let range = maxMired - minMired
        self.presets = [
            ("Warm", maxMired),
            ("Soft", maxMired - range * 0.25),
            ("Neutral", minMired + range * 0.5),
            ("Bright", minMired + range * 0.25),
            ("Cool", minMired)
        ]

        self.selectedIndex = -1
        let width = padding * 2 + CGFloat(presets.count) * circleSize + CGFloat(presets.count - 1) * spacing
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: padding * 2 + circleSize))

        // Find closest preset to current value
        self.selectedIndex = presets.enumerated().min(by: { abs($0.1.mired - currentMired) < abs($1.1.mired - currentMired) })?.0 ?? -1
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateMired(_ mired: Double) {
        currentMired = mired
        selectedIndex = presets.firstIndex { abs(mired - $0.mired) < 25 } ?? -1
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: padding * 2 + CGFloat(presets.count) * circleSize + CGFloat(presets.count - 1) * spacing, height: padding * 2 + circleSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for (index, preset) in presets.enumerated() {
            let x = padding + CGFloat(index) * (circleSize + spacing)
            let rect = NSRect(x: x, y: padding, width: circleSize, height: circleSize)
            miredToColor(preset.mired).setFill()
            NSBezierPath(ovalIn: rect).fill()
            if index == selectedIndex {
                NSColor.white.setStroke()
                let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
                ring.lineWidth = 3
                ring.stroke()
            }
        }
    }

    override func mouseDown(with event: NSEvent) { handleMouse(event) }
    override func mouseUp(with event: NSEvent) { handleMouse(event) }

    private func handleMouse(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, preset) in presets.enumerated() {
            let x = padding + CGFloat(index) * (circleSize + spacing)
            if NSRect(x: x, y: padding, width: circleSize, height: circleSize).contains(point) {
                selectedIndex = index
                currentMired = preset.mired
                onTempChanged(currentMired)
                needsDisplay = true
                return
            }
        }
    }

    private func miredToColor(_ mired: Double) -> NSColor {
        let clamped = max(0, min(1, (mired - 50) / 350))
        if clamped < 0.5 {
            let t = clamped * 2
            return NSColor(red: 0.9 + 0.1 * t, green: 0.95 + 0.05 * t, blue: 1.0, alpha: 1.0)
        } else {
            let t = (clamped - 0.5) * 2
            return NSColor(red: 1.0, green: 1.0 - 0.2 * t, blue: 1.0 - 0.5 * t, alpha: 1.0)
        }
    }
}
