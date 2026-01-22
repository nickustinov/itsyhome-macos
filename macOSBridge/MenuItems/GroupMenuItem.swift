//
//  GroupMenuItem.swift
//  macOSBridge
//
//  Menu item for device groups - shows a single control that affects all devices
//

import AppKit

class GroupMenuItem: NSMenuItem, CharacteristicUpdatable, LocalChangeNotifiable {

    private let group: DeviceGroup
    private let menuData: MenuData
    weak var bridge: Mac2iOS?

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField  // Shows "2/3" when partial

    private var toggleSwitch: ToggleSwitch?
    private var positionSlider: ModernSlider?

    private let commonType: String?

    // Track state of each device: characteristicId -> isOn
    private var deviceStates: [UUID: Bool] = [:]
    private var characteristicToService: [UUID: String] = [:]  // characteristicId -> serviceId

    // For blinds: track positions separately
    private var positionStates: [UUID: Int] = [:]  // currentPositionId -> position
    private var targetPositionIds: [UUID] = []  // targetPositionIds for writing

    var characteristicIdentifiers: [UUID] {
        return Array(deviceStates.keys) + Array(positionStates.keys)
    }

    init(group: DeviceGroup, menuData: MenuData, bridge: Mac2iOS?) {
        self.group = group
        self.menuData = menuData
        self.bridge = bridge
        self.commonType = group.commonServiceType(in: menuData)

        let height = DS.ControlSize.menuItemHeight
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = NSImage(systemSymbolName: group.icon, accessibilityDescription: group.name)
        iconView.contentTintColor = DS.Colors.mutedForeground
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
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initializeDeviceStates() {
        let services = group.resolveServices(in: menuData)
        for service in services {
            // For blinds: track position (start at 0, will update from characteristic updates)
            if service.serviceType == ServiceTypes.windowCovering {
                if let currentIdString = service.currentPositionId,
                   let currentId = UUID(uuidString: currentIdString) {
                    positionStates[currentId] = 0
                }
                if let targetIdString = service.targetPositionId,
                   let targetId = UUID(uuidString: targetIdString) {
                    targetPositionIds.append(targetId)
                }
            }
            // For power-based devices (lights, switches, etc.) - start OFF, will update from characteristic updates
            else if let idString = service.powerStateId, let id = UUID(uuidString: idString) {
                deviceStates[id] = false
                characteristicToService[id] = service.uniqueIdentifier
            } else if let idString = service.activeId, let id = UUID(uuidString: idString) {
                deviceStates[id] = false
                characteristicToService[id] = service.uniqueIdentifier
            }
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
            slider.doubleValue = 0  // Start at 0, will update from characteristic updates
            slider.progressTintColor = DS.Colors.sliderBlind
            slider.isContinuous = false
            slider.target = self
            slider.action = #selector(sliderChanged(_:))
            containerView.addSubview(slider)
            positionSlider = slider

            // Status label position
            statusLabel.frame = NSRect(x: sliderX - 40, y: (height - 17) / 2, width: 35, height: 17)
            nameLabel.frame.size.width = sliderX - 45 - labelX - DS.Spacing.sm

        default:
            // Toggle switch
            let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
            let switchY = (height - DS.ControlSize.switchHeight) / 2

            let toggle = ToggleSwitch()
            toggle.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
            toggle.setOn(false, animated: false)  // Start OFF, will update from bridge values
            toggle.target = self
            toggle.action = #selector(toggleChanged(_:))
            containerView.addSubview(toggle)
            toggleSwitch = toggle

            // Status label position (before toggle)
            statusLabel.frame = NSRect(x: switchX - 40, y: (height - 17) / 2, width: 35, height: 17)
            nameLabel.frame.size.width = switchX - 45 - labelX - DS.Spacing.sm
        }
    }

    // Called when characteristic values change
    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool) {
        // Update position state for blinds
        if positionStates.keys.contains(characteristicId) {
            if let pos = ValueConversion.toInt(value) {
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
        }
    }

    private func updateUI() {
        let total = deviceStates.count
        let onCount = deviceStates.values.filter { $0 }.count
        let allOn = onCount == total
        let allOff = onCount == 0

        // Update toggle
        toggleSwitch?.setOn(onCount > 0, animated: false)

        // Update icon
        switch commonType {
        case ServiceTypes.lightbulb:
            iconView.image = NSImage(systemSymbolName: onCount > 0 ? "lightbulb.fill" : "lightbulb", accessibilityDescription: nil)
            iconView.contentTintColor = onCount > 0 ? DS.Colors.lightOn : DS.Colors.mutedForeground
        case ServiceTypes.fan:
            iconView.image = NSImage(systemSymbolName: "fan", accessibilityDescription: nil)
            iconView.contentTintColor = onCount > 0 ? DS.Colors.success : DS.Colors.mutedForeground
        case ServiceTypes.lock:
            iconView.image = NSImage(systemSymbolName: onCount > 0 ? "lock" : "lock.open", accessibilityDescription: nil)
            iconView.contentTintColor = onCount > 0 ? DS.Colors.success : DS.Colors.mutedForeground
        default:
            iconView.image = NSImage(systemSymbolName: group.icon, accessibilityDescription: nil)
            iconView.contentTintColor = onCount > 0 ? DS.Colors.success : DS.Colors.mutedForeground
        }

        // Show "2/3" if partial
        if !allOn && !allOff {
            statusLabel.stringValue = "\(onCount)/\(total)"
            statusLabel.isHidden = false
        } else {
            statusLabel.isHidden = true
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

    @objc private func sliderChanged(_ sender: ModernSlider) {
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

    private func updateBlindsIcon(position: Int) {
        let isOpen = position > 0
        iconView.image = NSImage(systemSymbolName: isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed", accessibilityDescription: nil)
        iconView.contentTintColor = isOpen ? DS.Colors.info : DS.Colors.mutedForeground
    }
}
