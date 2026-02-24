//
//  GroupMenuItem.swift
//  macOSBridge
//
//  Menu item for device groups - shows a single control that affects all devices
//

import AppKit

class GroupMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable {

    let group: DeviceGroup
    let menuData: MenuData
    weak var bridge: Mac2iOS?

    let containerView: HighlightingMenuItemView
    let iconView: NSImageView
    let nameLabel: NSTextField
    let statusLabel: NSTextField  // Shows "2/3" when partial

    var toggleSwitch: ToggleSwitch?
    var positionSlider: ModernSlider?

    // Light group controls
    var brightnessSlider: ModernSlider?
    var colorCircle: ClickableColorCircleView?
    var ctButton: ClickableColorCircleView?
    var colorControlsRow: NSView?
    var colorPickerView: NSView?
    var tempPickerView: NSView?
    var expandedMode: String?  // nil=collapsed, "color", "temp"
    let collapsedHeight: CGFloat = DS.ControlSize.menuItemHeight
    var colorPickerExpandedHeight: CGFloat = DS.ControlSize.menuItemHeight
    var tempPickerExpandedHeight: CGFloat = DS.ControlSize.menuItemHeight
    lazy var lastColorSource: String = hasRGB ? "rgb" : "temp"

    let commonType: String?

    // Light group capabilities (all lights must have these for group to support)
    let hasBrightness: Bool
    let hasRGB: Bool
    let hasColorTemp: Bool

    // Track state of each device: characteristicId -> isOn
    var deviceStates: [UUID: Bool] = [:]
    var characteristicToService: [UUID: String] = [:]  // characteristicId -> serviceId

    // For blinds: track positions separately
    var positionStates: [UUID: Int] = [:]  // currentPositionId -> position
    var targetPositionIds: [UUID] = []  // targetPositionIds for writing
    var ignorePositionUpdatesUntil: Date?  // Ignore HomeKit updates while blinds are moving

    // For lights: track brightness, hue, saturation, color temp
    var brightnessStates: [UUID: Double] = [:]  // brightnessId -> brightness
    var brightnessIds: [UUID] = []  // for writing
    var hueStates: [UUID: Double] = [:]  // hueId -> hue
    var hueIds: [UUID] = []
    var saturationStates: [UUID: Double] = [:]  // satId -> saturation
    var saturationIds: [UUID] = []
    var colorTempStates: [UUID: Double] = [:]  // colorTempId -> mired
    var colorTempIds: [UUID] = []
    var colorTempMin: Double = 153
    var colorTempMax: Double = 500

    // Current averaged values for UI
    var currentBrightness: Double = 100
    var currentHue: Double = 0
    var currentSaturation: Double = 100
    var currentColorTemp: Double = 300

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
            self.hasColorTemp = services.allSatisfy { $0.colorTemperatureId != nil }
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
        iconView.image = IconResolver.icon(for: group)
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
            if self.commonType == ServiceTypes.windowCovering ||
               self.commonType == ServiceTypes.door ||
               self.commonType == ServiceTypes.window {
                // Blinds/door/window group: toggle between 0/100
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
                    } else if let idString = service.lockTargetStateId, let id = UUID(uuidString: idString) {
                        self.bridge?.writeCharacteristic(identifier: id, value: newState ? 1 : 0)
                        if let currentIdString = service.lockCurrentStateId, let currentId = UUID(uuidString: currentIdString) {
                            self.deviceStates[currentId] = newState
                            self.notifyLocalChange(characteristicId: currentId, value: newState ? 1 : 0)
                        }
                    }
                }
                self.updateUI()
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateUI() {
        let total = deviceStates.count
        let onCount = deviceStates.values.filter { $0 }.count
        let allOn = onCount == total
        let allOff = onCount == 0
        let isOn = onCount > 0

        // Update toggle
        toggleSwitch?.setOn(isOn, animated: false)

        // Update icon - check for custom icon first
        if PreferencesManager.shared.customIcon(for: group.id) != nil {
            // Use custom icon with filled based on state
            let filled: Bool
            if commonType == ServiceTypes.windowCovering ||
               commonType == ServiceTypes.door ||
               commonType == ServiceTypes.window {
                let avgPosition = positionStates.isEmpty ? 0 : positionStates.values.reduce(0, +) / positionStates.count
                filled = avgPosition > 0
            } else {
                filled = isOn
            }
            iconView.image = IconResolver.icon(for: group, filled: filled)
        } else {
            switch commonType {
            case ServiceTypes.windowCovering, ServiceTypes.door, ServiceTypes.window:
                // For blinds/door/window, use position states
                let avgPosition = positionStates.isEmpty ? 0 : positionStates.values.reduce(0, +) / positionStates.count
                updateBlindsIcon(position: avgPosition)
            case ServiceTypes.lightbulb:
                iconView.image = IconMapping.iconForServiceType(ServiceTypes.lightbulb, filled: isOn)
            case ServiceTypes.fan, ServiceTypes.fanV2:
                iconView.image = IconMapping.iconForServiceType(ServiceTypes.fan, filled: isOn)
            case ServiceTypes.lock:
                let mode = isOn ? "locked" : "unlocked"
                iconView.image = PhosphorIcon.modeIcon(for: ServiceTypes.lock, mode: mode, filled: isOn)
                    ?? IconMapping.iconForServiceType(ServiceTypes.lock, filled: isOn)
            default:
                // Use group's assigned icon
                iconView.image = IconResolver.icon(for: group, filled: isOn)
            }
        }

        // Show "2/3" if partial
        if !allOn && !allOff {
            statusLabel.stringValue = "\(onCount)/\(total)"
            statusLabel.isHidden = false
        } else {
            statusLabel.isHidden = true
        }

        // Light group specific: show/hide brightness slider and color buttons
        if commonType == ServiceTypes.lightbulb {
            let showSlider = isOn && hasBrightness
            let showColorCircle = isOn && hasRGB
            let showCtButton = isOn && hasColorTemp

            brightnessSlider?.isHidden = !showSlider
            colorCircle?.isHidden = !showColorCircle
            ctButton?.isHidden = !showCtButton

            // Calculate height based on expansion
            var newHeight = collapsedHeight
            if let mode = expandedMode, isOn {
                switch mode {
                case "color":
                    newHeight = colorPickerExpandedHeight
                case "temp":
                    newHeight = tempPickerExpandedHeight
                default:
                    break
                }
            }

            containerView.frame.size.height = newHeight
            updateExpandedContent()

            // Update vertical positions for controls
            let topAreaY = newHeight - collapsedHeight
            let iconY = topAreaY + (collapsedHeight - DS.ControlSize.iconMedium) / 2
            let labelY = topAreaY + (collapsedHeight - 17) / 2
            let sliderY = topAreaY + (collapsedHeight - 12) / 2
            let switchY = topAreaY + (collapsedHeight - DS.ControlSize.switchHeight) / 2
            let buttonSize: CGFloat = 14
            let buttonY = topAreaY + (collapsedHeight - buttonSize) / 2

            iconView.frame.origin.y = iconY
            nameLabel.frame.origin.y = labelY
            brightnessSlider?.frame.origin.y = sliderY
            toggleSwitch?.frame.origin.y = switchY
            statusLabel.frame.origin.y = labelY + 2

            // Position buttons right-to-left
            let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
            let sliderWidth = DS.ControlSize.sliderWidth
            let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm

            var buttonRightEdge = switchX - DS.Spacing.sm
            if showSlider {
                buttonRightEdge = switchX - sliderWidth - DS.Spacing.sm - DS.Spacing.xs
            }

            var nextButtonX = buttonRightEdge
            if showColorCircle {
                nextButtonX -= buttonSize
                colorCircle?.frame.origin = CGPoint(x: nextButtonX, y: buttonY)
                nextButtonX -= DS.Spacing.xs
            }
            if showCtButton {
                nextButtonX -= buttonSize
                ctButton?.frame.origin = CGPoint(x: nextButtonX, y: buttonY)
                nextButtonX -= DS.Spacing.xs
            }

            if !statusLabel.isHidden {
                statusLabel.sizeToFit()
                let statusWidth = ceil(statusLabel.frame.size.width)
                statusLabel.frame.origin.x = nextButtonX - statusWidth
                nameLabel.frame.size.width = nextButtonX - statusWidth - DS.Spacing.xs - labelX
            } else {
                nameLabel.frame.size.width = nextButtonX - labelX
            }

            if isOn && (hasRGB || hasColorTemp) {
                updateSliderColor()
            }
        }
    }
}
