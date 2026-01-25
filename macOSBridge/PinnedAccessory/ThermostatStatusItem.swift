//
//  ThermostatStatusItem.swift
//  macOSBridge
//
//  Menu bar status item for pinned thermostat/AC accessories
//

import AppKit

class ThermostatStatusItem: NSObject {

    private let statusItem: NSStatusItem
    let serviceId: String
    private let serviceName: String
    private var panelWindow: NSPanel?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var menuOpenObserver: NSObjectProtocol?
    private let panelSize = NSSize(width: 220, height: 140)

    static let closePopoverNotification = Notification.Name("ThermostatStatusItemClosePopover")

    // Characteristic UUIDs
    private var activeId: UUID?
    private var currentTempId: UUID?
    private var targetTempId: UUID?
    private var heatingThresholdId: UUID?
    private var coolingThresholdId: UUID?
    private var targetStateId: UUID?

    // Current values
    private var isActive: Bool = false
    private var currentTemp: Double?
    private var targetTemp: Double = 20
    private var heatingThreshold: Double = 20
    private var coolingThreshold: Double = 24
    private var targetState: Int = 0

    private var isHeaterCooler: Bool { activeId != nil }

    weak var delegate: ThermostatStatusItemDelegate?

    var characteristicIdentifiers: [UUID] {
        [activeId, currentTempId, targetTempId, heatingThresholdId, coolingThresholdId, targetStateId].compactMap { $0 }
    }

    // MARK: - Initialization

    init(serviceId: String, serviceName: String) {
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupButton()

        menuOpenObserver = NotificationCenter.default.addObserver(
            forName: Self.closePopoverNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closePanel()
        }
    }

    deinit {
        if let observer = menuOpenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        removeClickMonitor()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.title = "--°"
        button.target = self
        button.action = #selector(statusItemClicked)
    }

    func configure(with service: ServiceData) {
        activeId = service.activeId.flatMap { UUID(uuidString: $0) }
        currentTempId = service.currentTemperatureId.flatMap { UUID(uuidString: $0) }
        targetTempId = service.targetTemperatureId.flatMap { UUID(uuidString: $0) }
        heatingThresholdId = service.heatingThresholdTemperatureId.flatMap { UUID(uuidString: $0) }
        coolingThresholdId = service.coolingThresholdTemperatureId.flatMap { UUID(uuidString: $0) }
        targetStateId = service.activeId != nil
            ? service.targetHeaterCoolerStateId.flatMap { UUID(uuidString: $0) }
            : service.targetHeatingCoolingStateId.flatMap { UUID(uuidString: $0) }
    }

    // MARK: - Value Updates

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == activeId {
            if let active = ValueConversion.toBool(value) {
                isActive = active
                contentView?.updatePowerState(isActive)
            }
        } else if characteristicId == currentTempId {
            if let temp = ValueConversion.toDouble(value) {
                currentTemp = temp
                updateStatusButton()
                contentView?.updateCurrentTemp(temp)
            }
        } else if characteristicId == targetTempId {
            if let temp = ValueConversion.toDouble(value) {
                targetTemp = temp
                contentView?.updateTargetTemp(formatTargetTemp())
            }
        } else if characteristicId == heatingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                heatingThreshold = temp
                contentView?.updateTargetTemp(formatTargetTemp())
            }
        } else if characteristicId == coolingThresholdId {
            if let temp = ValueConversion.toDouble(value) {
                coolingThreshold = temp
                contentView?.updateTargetTemp(formatTargetTemp())
            }
        } else if characteristicId == targetStateId {
            if let state = ValueConversion.toInt(value) {
                targetState = state
                if !isHeaterCooler {
                    isActive = (state != 0)
                    contentView?.updatePowerState(isActive)
                }
                contentView?.updateModeState(state)
                contentView?.updateTargetTemp(formatTargetTemp())
            }
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        button.title = TemperatureFormatter.format(currentTemp)
    }

    private func formatTargetTemp() -> String {
        guard isActive else { return "--" }
        if isHeaterCooler {
            switch targetState {
            case 1: return TemperatureFormatter.format(heatingThreshold)
            case 2: return TemperatureFormatter.format(coolingThreshold)
            default: return TemperatureFormatter.format(coolingThreshold)
            }
        } else {
            return TemperatureFormatter.format(targetTemp)
        }
    }

    // MARK: - Popover

    private weak var contentView: ThermostatPopoverView?

    @objc private func statusItemClicked() {
        if panelWindow?.isVisible == true {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }

        // Activate app - critical for proper panel behavior
        NSApp.activate(ignoringOtherApps: true)

        let content = ThermostatPopoverView(
            name: serviceName,
            isHeaterCooler: isHeaterCooler,
            isActive: isActive,
            currentTemp: currentTemp,
            targetTemp: formatTargetTemp(),
            modeState: targetState
        )
        content.delegate = self
        self.contentView = content

        let panel = panelWindow ?? makePanel()
        panel.contentView = wrapInVisualEffect(content)
        content.wantsLayer = true
        content.layer?.cornerRadius = 10
        content.layer?.masksToBounds = true
        panel.setFrame(NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height), display: true)
        positionPanel(panel, relativeTo: button)
        panel.makeKeyAndOrderFront(nil)
        panelWindow = panel

        setupClickMonitor()
        // Keep menu bar item highlighted while panel is visible.
        DispatchQueue.main.async {
            button.highlight(true)
        }
    }

    private func closePanel() {
        panelWindow?.orderOut(nil)
        contentView = nil
        removeClickMonitor()
        statusItem.button?.highlight(false)
    }

    private func setupClickMonitor() {
        removeClickMonitor()

        let dismissCheck: () -> Void = { [weak self] in
            guard let self = self else { return }
            let screenPoint = NSEvent.mouseLocation
            if let panel = self.panelWindow, panel.frame.contains(screenPoint) {
                return
            }
            if let button = self.statusItem.button, let btnWindow = button.window {
                let btnRect = button.convert(button.bounds, to: nil)
                let btnScreenRect = btnWindow.convertToScreen(btnRect)
                if btnScreenRect.contains(screenPoint) {
                    return
                }
            }
            self.closePanel()
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            dismissCheck()
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panelWindow?.isVisible == true else { return event }
            if event.window == self.panelWindow { return event }
            if event.window == self.statusItem.button?.window { return event }
            dismissCheck()
            return event
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.toolbar = nil
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovable = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.hidesOnDeactivate = false

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true

        return panel
    }

    private func wrapInVisualEffect(_ content: NSView) -> NSView {
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.autoresizingMask = [.width, .height]

        let effectView = NSVisualEffectView(frame: container.bounds)
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        container.addSubview(effectView)

        content.frame = container.bounds
        content.autoresizingMask = [.width, .height]
        container.addSubview(content)

        return container
    }

    private func positionPanel(_ window: NSWindow, relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let visibleFrame = screen.visibleFrame

        var x = screenRect.midX - panelSize.width / 2
        let y = screenRect.minY - panelSize.height - 4

        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - panelSize.width
        x = max(minX, min(x, maxX))

        window.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    // MARK: - Actions from Content View

    fileprivate func handlePowerToggle(_ isOn: Bool) {
        isActive = isOn
        contentView?.updatePowerState(isOn)
        if isHeaterCooler {
            if let id = activeId {
                delegate?.thermostatStatusItem(self, writeValue: isOn ? 1 : 0, forCharacteristic: id)
            }
        } else {
            targetState = isOn ? 3 : 0
            if let id = targetStateId {
                delegate?.thermostatStatusItem(self, writeValue: targetState, forCharacteristic: id)
            }
            contentView?.updateModeState(targetState)
        }
        contentView?.updateTargetTemp(formatTargetTemp())
    }

    fileprivate func handleModeChange(_ mode: Int) {
        targetState = mode
        contentView?.updateModeState(mode)
        if !isHeaterCooler {
            isActive = (mode != 0)
            contentView?.updatePowerState(isActive)
        }
        if let id = targetStateId {
            delegate?.thermostatStatusItem(self, writeValue: mode, forCharacteristic: id)
        }
        contentView?.updateTargetTemp(formatTargetTemp())
    }

    fileprivate func handleTempAdjust(_ delta: Double) {
        if isHeaterCooler {
            switch targetState {
            case 1:
                heatingThreshold = min(max(heatingThreshold + delta, 16), 30)
                if let id = heatingThresholdId {
                    delegate?.thermostatStatusItem(self, writeValue: Float(heatingThreshold), forCharacteristic: id)
                }
            default:
                coolingThreshold = min(max(coolingThreshold + delta, 16), 30)
                if let id = coolingThresholdId {
                    delegate?.thermostatStatusItem(self, writeValue: Float(coolingThreshold), forCharacteristic: id)
                }
            }
        } else {
            targetTemp = min(max(targetTemp + delta, 10), 30)
            if let id = targetTempId {
                delegate?.thermostatStatusItem(self, writeValue: Float(targetTemp), forCharacteristic: id)
            }
        }
        contentView?.updateTargetTemp(formatTargetTemp())
    }
}

// MARK: - Delegate Protocol

protocol ThermostatStatusItemDelegate: AnyObject {
    func thermostatStatusItem(_ item: ThermostatStatusItem, writeValue value: Any, forCharacteristic characteristicId: UUID)
}

// MARK: - Popover Content View

private protocol ThermostatPopoverViewDelegate: AnyObject {
    func handlePowerToggle(_ isOn: Bool)
    func handleModeChange(_ mode: Int)
    func handleTempAdjust(_ delta: Double)
}

extension ThermostatStatusItem: ThermostatPopoverViewDelegate {}

private class ThermostatPopoverView: NSView {

    override var allowsVibrancy: Bool { false }

    weak var delegate: ThermostatPopoverViewDelegate?

    private let isHeaterCooler: Bool
    private var isActive: Bool

    // UI Components
    private let powerToggle = ToggleSwitch()
    private let currentTitleLabel = NSTextField(labelWithString: "Current")
    private let currentTempLabel = NSTextField(labelWithString: "--")
    private let targetTitleLabel = NSTextField(labelWithString: "Target")
    private let targetTempLabel = NSTextField(labelWithString: "--")
    private let minusButton = NSButton()
    private let plusButton = NSButton()
    private var modeButtons: [Int: ModeButton] = [:]
    private var modeContainer: NSView?

    init(name: String, isHeaterCooler: Bool, isActive: Bool, currentTemp: Double?, targetTemp: String, modeState: Int) {
        self.isHeaterCooler = isHeaterCooler
        self.isActive = isActive
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 140))

        setupUI(name: name, currentTemp: currentTemp, targetTemp: targetTemp, modeState: modeState)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI(name: String, currentTemp: Double?, targetTemp: String, modeState: Int) {
        let width: CGFloat = 220
        let padding: CGFloat = 12

        // Calculate even vertical distribution
        // Content: title row (22) + temp section (14 + 32 = 46) + mode buttons (24) = 92
        // Available: 140 - 12 - 12 = 116
        // 2 gaps: (116 - 92) / 2 = 12 each
        let gap: CGFloat = 12

        // Title row at top
        let titleRowY: CGFloat = 140 - padding - DS.ControlSize.switchHeight
        let titleLabelHeight: CGFloat = 17
        let titleLabelY = titleRowY + (DS.ControlSize.switchHeight - titleLabelHeight) / 2

        let titleLabel = NSTextField(labelWithString: name)
        titleLabel.font = DS.Typography.labelMedium
        titleLabel.textColor = DS.Colors.foreground
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: padding, y: titleLabelY, width: width - padding * 2 - DS.ControlSize.switchWidth - 8, height: titleLabelHeight)
        addSubview(titleLabel)

        powerToggle.frame = NSRect(x: width - padding - DS.ControlSize.switchWidth, y: titleRowY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        powerToggle.setOn(isActive, animated: false)
        powerToggle.target = self
        powerToggle.action = #selector(powerToggled(_:))
        addSubview(powerToggle)

        // Mode buttons at bottom (y = padding)
        let modeButtonsHeight: CGFloat = 24
        let modeButtonsY: CGFloat = padding

        // Temp section in middle (between title and mode buttons with equal gaps)
        let tempSectionHeight: CGFloat = 14 + 32  // labels + values
        let tempSectionTop = titleRowY - gap
        let labelsY = tempSectionTop - 14

        currentTitleLabel.font = DS.Typography.labelSmall
        currentTitleLabel.textColor = DS.Colors.mutedForeground
        currentTitleLabel.frame = NSRect(x: padding, y: labelsY, width: 60, height: 14)
        addSubview(currentTitleLabel)

        // Target temp section
        let buttonSize: CGFloat = 24
        let tempLabelWidth: CGFloat = 40
        let spacing: CGFloat = 4
        let targetControlsWidth = buttonSize + spacing + tempLabelWidth + spacing + buttonSize
        let targetControlsX = width - padding - targetControlsWidth

        targetTitleLabel.font = DS.Typography.labelSmall
        targetTitleLabel.textColor = DS.Colors.mutedForeground
        targetTitleLabel.frame = NSRect(x: targetControlsX, y: labelsY, width: 60, height: 14)
        addSubview(targetTitleLabel)

        // Current temp value
        let valuesY = labelsY - 32

        currentTempLabel.stringValue = TemperatureFormatter.format(currentTemp)
        currentTempLabel.font = NSFont.systemFont(ofSize: 28, weight: .medium)
        currentTempLabel.textColor = DS.Colors.foreground
        currentTempLabel.frame = NSRect(x: padding, y: valuesY, width: 70, height: 32)
        addSubview(currentTempLabel)

        // Target temp controls (vertically centered with current temp)
        let targetControlsY = valuesY + (32 - buttonSize) / 2

        setupButton(minusButton, title: "−", frame: NSRect(x: targetControlsX, y: targetControlsY, width: buttonSize, height: buttonSize))
        minusButton.action = #selector(decreaseTemp)
        addSubview(minusButton)

        targetTempLabel.stringValue = targetTemp
        targetTempLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        targetTempLabel.textColor = DS.Colors.foreground
        targetTempLabel.alignment = .center
        targetTempLabel.frame = NSRect(x: targetControlsX + buttonSize + spacing, y: targetControlsY + 1, width: tempLabelWidth, height: 22)
        addSubview(targetTempLabel)

        setupButton(plusButton, title: "+", frame: NSRect(x: targetControlsX + buttonSize + spacing + tempLabelWidth + spacing, y: targetControlsY, width: buttonSize, height: buttonSize))
        plusButton.action = #selector(increaseTemp)
        addSubview(plusButton)

        // Mode buttons
        setupModeButtons(padding: padding, modeState: modeState)

        // Apply initial disabled state
        updateControlsEnabled()
    }

    private func setupButton(_ button: NSButton, title: String, frame: NSRect) {
        button.frame = frame
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.1).cgColor
        button.layer?.cornerRadius = 4
        button.title = title
        button.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        button.target = self
    }

    private func setupModeButtons(padding: CGFloat, modeState: Int) {
        let modeY: CGFloat = padding + 4
        let modeButtonWidth: CGFloat = 42
        let modeButtonHeight: CGFloat = 20
        let containerPadding: CGFloat = 2

        let modes: [(tag: Int, title: String, color: NSColor)]
        if isHeaterCooler {
            modes = [
                (0, "Auto", DS.Colors.success),
                (1, "Heat", DS.Colors.thermostatHeat),
                (2, "Cool", DS.Colors.thermostatCool)
            ]
        } else {
            modes = [
                (0, "Off", DS.Colors.mutedForeground),
                (1, "Heat", DS.Colors.thermostatHeat),
                (2, "Cool", DS.Colors.thermostatCool),
                (3, "Auto", DS.Colors.success)
            ]
        }

        let containerWidth = modeButtonWidth * CGFloat(modes.count) + containerPadding * 2
        let containerHeight = modeButtonHeight + containerPadding * 2

        let container = NSView(frame: NSRect(x: padding, y: modeY, width: containerWidth, height: containerHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.08).cgColor
        container.layer?.cornerRadius = containerHeight / 2
        addSubview(container)
        self.modeContainer = container

        for (index, mode) in modes.enumerated() {
            let button = ModeButton(title: mode.title, color: mode.color)
            button.frame = NSRect(x: containerPadding + CGFloat(index) * modeButtonWidth, y: containerPadding, width: modeButtonWidth, height: modeButtonHeight)
            button.tag = mode.tag
            button.target = self
            button.action = #selector(modeChanged(_:))
            button.isSelected = (mode.tag == modeState)
            container.addSubview(button)
            modeButtons[mode.tag] = button
        }
    }

    // MARK: - Updates

    func updatePowerState(_ active: Bool) {
        isActive = active
        powerToggle.setOn(active, animated: true)
        updateControlsEnabled()
    }

    func updateCurrentTemp(_ temp: Double) {
        currentTempLabel.stringValue = TemperatureFormatter.format(temp)
    }

    func updateTargetTemp(_ temp: String) {
        targetTempLabel.stringValue = temp
    }

    func updateModeState(_ state: Int) {
        for (tag, button) in modeButtons {
            button.isSelected = (tag == state)
        }
    }

    private func updateControlsEnabled() {
        let alpha: CGFloat = isActive ? 1.0 : 0.5

        // Current temp section
        currentTitleLabel.alphaValue = alpha
        currentTempLabel.alphaValue = alpha

        // Target temp section
        targetTitleLabel.alphaValue = alpha
        targetTempLabel.alphaValue = alpha
        minusButton.alphaValue = alpha
        minusButton.isEnabled = isActive
        plusButton.alphaValue = alpha
        plusButton.isEnabled = isActive

        // Mode buttons
        modeContainer?.alphaValue = alpha
        for button in modeButtons.values {
            button.isDisabled = !isActive
        }
    }

    // MARK: - Actions

    @objc private func powerToggled(_ sender: ToggleSwitch) {
        delegate?.handlePowerToggle(sender.isOn)
    }

    @objc private func modeChanged(_ sender: ModeButton) {
        delegate?.handleModeChange(sender.tag)
    }

    @objc private func decreaseTemp() {
        delegate?.handleTempAdjust(-1)
    }

    @objc private func increaseTemp() {
        delegate?.handleTempAdjust(1)
    }

    // MARK: - Appearance

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Button backgrounds need updating for theme change
        let bgColor = NSColor.secondaryLabelColor.withAlphaComponent(0.1).cgColor
        minusButton.layer?.backgroundColor = bgColor
        plusButton.layer?.backgroundColor = bgColor
    }
}
