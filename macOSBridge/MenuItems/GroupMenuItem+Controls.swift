//
//  GroupMenuItem+Controls.swift
//  macOSBridge
//
//  Control setup and color picker management for group menu items
//

import AppKit

extension GroupMenuItem {

    func setupControl(height: CGFloat, labelX: CGFloat) {
        switch commonType {
        case ServiceTypes.windowCovering, ServiceTypes.door, ServiceTypes.window:
            setupBlindsControl(height: height, labelX: labelX)

        case ServiceTypes.lightbulb:
            setupLightControl(height: height, labelX: labelX)

        default:
            setupToggleControl(height: height, labelX: labelX)
        }
    }

    private func setupBlindsControl(height: CGFloat, labelX: CGFloat) {
        let sliderWidth = DS.ControlSize.sliderWidth
        let thumbOffset = DS.ControlSize.sliderThumbSize / 2  // Slider track is inset by thumb radius
        let sliderX = DS.ControlSize.menuItemWidth - sliderWidth - DS.Spacing.md + thumbOffset
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
    }

    private func setupLightControl(height: CGFloat, labelX: CGFloat) {
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
    }

    private func setupToggleControl(height: CGFloat, labelX: CGFloat) {
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

    func setupColorControlsRow() {
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

    func toggleColorPicker() {
        guard hasColor, deviceStates.values.contains(true) else { return }
        isColorPickerExpanded.toggle()
        updateUI()
        if let menu = menu {
            menu.itemChanged(self)
        }
    }

    func updateColorCircle() {
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
}
