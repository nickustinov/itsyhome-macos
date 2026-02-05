//
//  CoverMenuItem.swift
//  macOSBridge
//
//  Menu item for Home Assistant covers without position support
//  Uses 3-button control for open/stop/close actions
//

import AppKit

class CoverMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable, LocalChangeNotifiable, ReachabilityUpdatableMenuItem {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var currentPositionId: UUID?
    private var targetDoorStateId: UUID?  // For garage doors (0=open, 1=closed)

    private var position: Int = 0  // 0=closed, 100=open
    private var isOpen: Bool { position > 50 }

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let coverControl: CoverControl

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = currentPositionId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.currentPositionId = serviceData.currentPositionId?.uuid
        self.targetDoorStateId = serviceData.targetDoorStateId?.uuid

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: DS.ControlSize.menuItemHeight))

        // Icon
        let iconY = (DS.ControlSize.menuItemHeight - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: serviceData, filled: false)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Cover control position (right-aligned, same as toggle switch)
        let controlWidth: CGFloat = 42  // CoverControl width
        let controlHeight: CGFloat = 16  // Same as toggle switch
        let controlX = DS.ControlSize.menuItemWidth - controlWidth - DS.Spacing.md

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (DS.ControlSize.menuItemHeight - 17) / 2
        let labelWidth = controlX - labelX - DS.Spacing.sm
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Cover control
        let controlY = (DS.ControlSize.menuItemHeight - controlHeight) / 2
        coverControl = CoverControl()
        coverControl.frame = NSRect(x: controlX, y: controlY, width: controlWidth, height: controlHeight)
        containerView.addSubview(coverControl)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false

        // Toggle open/closed when clicking outside controls
        containerView.onAction = { [weak self] in
            guard let self else { return }
            if self.isOpen {
                self.sendCoverCommand(.close)
            } else {
                self.sendCoverCommand(.open)
            }
        }

        // Handle cover control actions
        coverControl.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case 0: // Open
                self.sendCoverCommand(.open)
            case 1: // Stop
                self.sendCoverCommand(.stop)
            case 2: // Close
                self.sendCoverCommand(.close)
            default:
                break
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum CoverCommand {
        case open, stop, close
    }

    private func sendCoverCommand(_ command: CoverCommand) {
        // For HA covers, we write position: 100=open, 0=closed
        // Stop requires a separate command handled by the platform
        switch command {
        case .open:
            if let id = targetDoorStateId {
                // Garage door: 0=open, 1=closed
                bridge?.writeCharacteristic(identifier: id, value: 0)
            } else if let id = currentPositionId {
                bridge?.writeCharacteristic(identifier: id, value: 100)
                notifyLocalChange(characteristicId: id, value: 100)
            }
            coverControl.setState(.open)
            position = 100
            updateIcon()

        case .stop:
            // For stop, write a special value (-1) that the platform interprets as stop
            if let id = currentPositionId {
                bridge?.writeCharacteristic(identifier: id, value: -1)
            }
            coverControl.setState(.stopped)

        case .close:
            if let id = targetDoorStateId {
                // Garage door: 0=open, 1=closed
                bridge?.writeCharacteristic(identifier: id, value: 1)
            } else if let id = currentPositionId {
                bridge?.writeCharacteristic(identifier: id, value: 0)
                notifyLocalChange(characteristicId: id, value: 0)
            }
            coverControl.setState(.closed)
            position = 0
            updateIcon()
        }
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        if characteristicId == currentPositionId {
            if let pos = ValueConversion.toInt(value) {
                position = pos
                updateIcon()
                updateControlState()
            }
        }
    }

    private func updateIcon() {
        iconView.image = IconResolver.icon(for: serviceData, filled: isOpen)
    }

    private func updateControlState() {
        if position >= 95 {
            coverControl.setState(.open)
        } else if position <= 5 {
            coverControl.setState(.closed)
        } else {
            coverControl.setState(.stopped)
        }
    }
}
