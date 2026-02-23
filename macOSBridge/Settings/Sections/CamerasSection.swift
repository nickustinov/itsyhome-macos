//
//  CamerasSection.swift
//  macOSBridge
//
//  Cameras settings section with ordering, visibility, and overlay accessories
//

import AppKit
import Combine

extension NSPasteboard.PasteboardType {
    static let cameraItem = NSPasteboard.PasteboardType("com.itsyhome.cameraItem")
}

class CamerasSection: NSView {

    private let stackView = NSStackView()
    private let cameraSwitch = NSSwitch()
    private let doorbellSwitch = NSSwitch()
    private let doorbellSoundSwitch = NSSwitch()
    private let autoCloseSwitch = NSSwitch()
    private let autoCloseDelayPopup = NSPopUpButton()
    private(set) var camerasTableView: NSTableView?
    private var menuData: MenuData?
    private(set) var cameras: [CameraData] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastLayoutWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setupBindings()
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with data: MenuData) {
        self.menuData = data
        rebuildContent()
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.width != lastLayoutWidth else { return }
        lastLayoutWidth = bounds.width
        guard let table = camerasTableView, !cameras.isEmpty else { return }
        table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<cameras.count))
        let newHeight = computeTableHeight(spacing: 4)
        if let container = table.superview {
            container.constraints.first(where: { $0.firstAttribute == .height })?.constant = newHeight
        }
    }

    // MARK: - Content

    private func setupContent() {
        let isPro = ProStatusCache.shared.isPro

        // Pro banner
        if !isPro {
            let banner = SettingsCard.createProBanner()
            stackView.addArrangedSubview(banner)
            banner.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            addSpacer(height: 12)
        }

        // Toggle box
        let box = CardBoxView()
        box.translatesAutoresizingMaskIntoConstraints = false

        cameraSwitch.controlSize = .mini
        cameraSwitch.target = self
        cameraSwitch.action = #selector(cameraSwitchChanged)
        cameraSwitch.isEnabled = isPro
        cameraSwitch.state = PreferencesManager.shared.camerasEnabled ? .on : .off

        let row = createSettingRow(
            label: String(localized: "settings.cameras.show_in_menu_bar", defaultValue: "Show cameras in menu bar", bundle: .macOSBridge),
            subtitle: String(localized: "settings.cameras.show_in_menu_bar_description", defaultValue: "Display a camera icon in the menu bar to quickly view live camera feeds.", bundle: .macOSBridge),
            control: cameraSwitch
        )
        row.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4)
        ])

        stackView.addArrangedSubview(box)
        box.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        addSpacer(height: 8)

        // Doorbell toggles
        let doorbellBox = CardBoxView()
        doorbellBox.translatesAutoresizingMaskIntoConstraints = false

        let doorbellStack = NSStackView()
        doorbellStack.orientation = .vertical
        doorbellStack.spacing = 0
        doorbellStack.alignment = .leading
        doorbellStack.translatesAutoresizingMaskIntoConstraints = false

        let camerasOn = PreferencesManager.shared.camerasEnabled

        doorbellSwitch.controlSize = .mini
        doorbellSwitch.target = self
        doorbellSwitch.action = #selector(doorbellSwitchChanged)
        doorbellSwitch.isEnabled = isPro && camerasOn
        doorbellSwitch.state = PreferencesManager.shared.doorbellNotifications ? .on : .off

        let doorbellRow = createSettingRow(
            label: String(localized: "settings.cameras.doorbell_on_ring", defaultValue: "Show doorbell camera on ring", bundle: .macOSBridge),
            subtitle: String(localized: "settings.cameras.doorbell_on_ring_description", defaultValue: "Automatically display the camera feed when a doorbell rings.", bundle: .macOSBridge),
            control: doorbellSwitch
        )
        doorbellStack.addArrangedSubview(doorbellRow)
        doorbellRow.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        doorbellStack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        doorbellSoundSwitch.controlSize = .mini
        doorbellSoundSwitch.target = self
        doorbellSoundSwitch.action = #selector(doorbellSoundSwitchChanged)
        doorbellSoundSwitch.isEnabled = isPro && camerasOn
        doorbellSoundSwitch.state = PreferencesManager.shared.doorbellSound ? .on : .off

        let soundRow = createSettingRow(
            label: String(localized: "settings.cameras.doorbell_sound", defaultValue: "Play doorbell sound", bundle: .macOSBridge),
            subtitle: String(localized: "settings.cameras.doorbell_sound_description", defaultValue: "Play a chime sound when a doorbell rings.", bundle: .macOSBridge),
            control: doorbellSoundSwitch
        )
        doorbellStack.addArrangedSubview(soundRow)
        soundRow.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false
        doorbellStack.addArrangedSubview(separator2)
        separator2.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        autoCloseSwitch.controlSize = .mini
        autoCloseSwitch.target = self
        autoCloseSwitch.action = #selector(autoCloseSwitchChanged)
        autoCloseSwitch.isEnabled = isPro && camerasOn
        autoCloseSwitch.state = PreferencesManager.shared.doorbellAutoClose ? .on : .off

        let autoCloseRow = createSettingRow(
            label: String(localized: "settings.cameras.auto_close_doorbell", defaultValue: "Auto-close doorbell camera", bundle: .macOSBridge),
            subtitle: String(localized: "settings.cameras.auto_close_doorbell_description", defaultValue: "Automatically close the camera popup after a doorbell ring.", bundle: .macOSBridge),
            control: autoCloseSwitch
        )
        doorbellStack.addArrangedSubview(autoCloseRow)
        autoCloseRow.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        let separator3 = NSBox()
        separator3.boxType = .separator
        separator3.translatesAutoresizingMaskIntoConstraints = false
        doorbellStack.addArrangedSubview(separator3)
        separator3.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        let delayOptions: [(String, Int)] = [
            (String(localized: "settings.cameras.delay_30s", defaultValue: "30 seconds", bundle: .macOSBridge), 30),
            (String(localized: "settings.cameras.delay_1m", defaultValue: "1 minute", bundle: .macOSBridge), 60),
            (String(localized: "settings.cameras.delay_2m", defaultValue: "2 minutes", bundle: .macOSBridge), 120),
            (String(localized: "settings.cameras.delay_5m", defaultValue: "5 minutes", bundle: .macOSBridge), 300)
        ]

        autoCloseDelayPopup.removeAllItems()
        for (title, _) in delayOptions {
            autoCloseDelayPopup.addItem(withTitle: title)
        }

        let currentDelay = PreferencesManager.shared.doorbellAutoCloseDelay
        if let index = delayOptions.firstIndex(where: { $0.1 == currentDelay }) {
            autoCloseDelayPopup.selectItem(at: index)
        }

        autoCloseDelayPopup.controlSize = .small
        autoCloseDelayPopup.target = self
        autoCloseDelayPopup.action = #selector(autoCloseDelayChanged)
        autoCloseDelayPopup.isEnabled = isPro && camerasOn && PreferencesManager.shared.doorbellAutoClose

        let delayRow = createSettingRow(
            label: String(localized: "settings.cameras.close_after", defaultValue: "Close after", bundle: .macOSBridge),
            control: autoCloseDelayPopup
        )
        doorbellStack.addArrangedSubview(delayRow)
        delayRow.widthAnchor.constraint(equalTo: doorbellStack.widthAnchor).isActive = true

        doorbellBox.addSubview(doorbellStack)
        NSLayoutConstraint.activate([
            doorbellStack.topAnchor.constraint(equalTo: doorbellBox.topAnchor, constant: 4),
            doorbellStack.leadingAnchor.constraint(equalTo: doorbellBox.leadingAnchor, constant: 12),
            doorbellStack.trailingAnchor.constraint(equalTo: doorbellBox.trailingAnchor, constant: -12),
            doorbellStack.bottomAnchor.constraint(equalTo: doorbellBox.bottomAnchor, constant: -4)
        ])

        stackView.addArrangedSubview(doorbellBox)
        doorbellBox.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        addSpacer(height: 16)

        // Camera list
        loadCameras()
        if !cameras.isEmpty {
            let header = AccessorySectionHeader(title: String(localized: "settings.cameras.your_cameras", defaultValue: "Your cameras", bundle: .macOSBridge))
            addView(header, height: 32)
            addSpacer(height: 4)

            let spacing: CGFloat = 4
            let tableHeight = computeTableHeight(spacing: spacing)
            let tableContainer = createCamerasTable(height: tableHeight, rowHeight: 60, spacing: spacing)
            addView(tableContainer, height: tableHeight)
        } else if menuData != nil {
            let emptyLabel = NSTextField(labelWithString: String(localized: "settings.cameras.no_cameras", defaultValue: "No cameras found in this home.", bundle: .macOSBridge))
            emptyLabel.font = .systemFont(ofSize: 11)
            emptyLabel.textColor = .tertiaryLabelColor
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(emptyLabel)
        }

        addSpacer(height: 16)
    }

    private func computeTableHeight(spacing: CGFloat) -> CGFloat {
        var totalHeight: CGFloat = 0
        for camera in cameras {
            let chipLines = computeChipLines(for: camera.uniqueIdentifier)
            if chipLines == 0 {
                totalHeight += 36
            } else {
                totalHeight += 36 + 6 + CGFloat(chipLines) * 20 + CGFloat(chipLines - 1) * 4 + 8
            }
        }
        totalHeight += CGFloat(max(0, cameras.count - 1)) * spacing
        return totalHeight
    }

    private func loadCameras() {
        guard let data = menuData else {
            cameras = []
            return
        }
        let order = PreferencesManager.shared.cameraOrder
        var ordered: [CameraData] = []
        var remaining = data.cameras

        // Apply saved order
        for id in order {
            if let index = remaining.firstIndex(where: { $0.uniqueIdentifier == id }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        // Append any new cameras not in saved order
        ordered.append(contentsOf: remaining)

        cameras = ordered

        // Sync order to prefs if there are new cameras
        if order.count != cameras.count {
            PreferencesManager.shared.cameraOrder = cameras.map { $0.uniqueIdentifier }
        }
    }

    func rebuildContent() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        camerasTableView = nil
        setupContent()
    }

    // MARK: - Table

    private func createCamerasTable(height: CGFloat, rowHeight: CGFloat, spacing: CGFloat) -> NSView {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: spacing)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.gridStyleMask = []
        tableView.registerForDraggedTypes([.cameraItem])
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.allowsMultipleSelection = false
        tableView.usesAutomaticRowHeights = false
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        self.camerasTableView = tableView

        let container = NSView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Row view

    func createCameraRowView(camera: CameraData, row: Int) -> NSView {
        let isPro = ProStatusCache.shared.isPro
        let isHidden = PreferencesManager.shared.isHidden(cameraId: camera.uniqueIdentifier)
        let overlayIds = PreferencesManager.shared.overlayAccessories(for: camera.uniqueIdentifier)

        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Top line: drag, eye, icon, name, add button
        let dragHandle = DragHandleView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.isHidden = !isPro
        container.addSubview(dragHandle)

        let eyeButton = NSButton()
        eyeButton.bezelStyle = .inline
        eyeButton.isBordered = false
        eyeButton.imagePosition = .imageOnly
        eyeButton.imageScaling = .scaleProportionallyUpOrDown
        eyeButton.image = isHidden ? PhosphorIcon.regular("eye") : PhosphorIcon.fill("eye")
        eyeButton.contentTintColor = isHidden ? .tertiaryLabelColor : .secondaryLabelColor
        eyeButton.target = self
        eyeButton.action = #selector(eyeTapped(_:))
        eyeButton.tag = row
        eyeButton.isEnabled = isPro
        eyeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(eyeButton)

        let nameLabel = NSTextField(labelWithString: camera.name)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.alphaValue = isHidden ? 0.5 : 1.0
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let addButton = NSButton(title: String(localized: "settings.cameras.add_accessory", defaultValue: "Add accessory", bundle: .macOSBridge), target: self, action: #selector(addOverlayTapped(_:)))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .regular
        addButton.tag = row
        addButton.isEnabled = isPro
        addButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addButton)

        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            dragHandle.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 12),
            dragHandle.heightAnchor.constraint(equalToConstant: 20),

            eyeButton.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 6),
            eyeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            eyeButton.widthAnchor.constraint(equalToConstant: 20),
            eyeButton.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: eyeButton.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            addButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            addButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
        ])

        // Bottom: chips (only if has overlays)
        if !overlayIds.isEmpty {
            let chipsFlow = FlowLayoutView()
            chipsFlow.spacing = 4
            chipsFlow.lineSpacing = 4
            chipsFlow.translatesAutoresizingMaskIntoConstraints = false

            for serviceId in overlayIds {
                if let service = findService(id: serviceId) {
                    let chip = createAccessoryChip(service: service, cameraId: camera.uniqueIdentifier)
                    chipsFlow.addArrangedSubview(chip)
                }
            }

            container.addSubview(chipsFlow)

            NSLayoutConstraint.activate([
                chipsFlow.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 6),
                chipsFlow.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                chipsFlow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            ])
        }

        return container
    }

    // MARK: - Accessory chips

    private func createAccessoryChip(service: ServiceData, cameraId: String) -> NSView {
        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        chip.layer?.cornerRadius = 10
        chip.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = iconForServiceType(service.serviceType)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(icon)

        let label = NSTextField(labelWithString: service.name)
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(label)

        let removeButton = NSButton(image: PhosphorIcon.fill("x-circle") ?? NSImage(), target: self, action: #selector(removeOverlayTapped(_:)))
        removeButton.bezelStyle = .inline
        removeButton.isBordered = false
        removeButton.contentTintColor = .tertiaryLabelColor
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        // Encode camera+service in identifier
        removeButton.identifier = NSUserInterfaceItemIdentifier("\(cameraId)|\(service.uniqueIdentifier)")
        chip.addSubview(removeButton)

        NSLayoutConstraint.activate([
            chip.heightAnchor.constraint(equalToConstant: 20),

            icon.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 5),
            icon.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 12),
            icon.heightAnchor.constraint(equalToConstant: 12),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 3),
            label.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 60),

            removeButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
            removeButton.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -3),
            removeButton.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 14),
            removeButton.heightAnchor.constraint(equalToConstant: 14)
        ])

        return chip
    }

    // MARK: - Actions

    @objc private func cameraSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.camerasEnabled = sender.state == .on
        rebuildContent()
    }

    @objc private func doorbellSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.doorbellNotifications = sender.state == .on
    }

    @objc private func doorbellSoundSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.doorbellSound = sender.state == .on
    }

    @objc private func autoCloseSwitchChanged(_ sender: NSSwitch) {
        PreferencesManager.shared.doorbellAutoClose = sender.state == .on
        autoCloseDelayPopup.isEnabled = sender.state == .on
    }

    @objc private func autoCloseDelayChanged(_ sender: NSPopUpButton) {
        let delays = [30, 60, 120, 300]
        let index = sender.indexOfSelectedItem
        guard index >= 0, index < delays.count else { return }
        PreferencesManager.shared.doorbellAutoCloseDelay = delays[index]
    }

    @objc private func eyeTapped(_ sender: NSButton) {
        guard sender.tag < cameras.count else { return }
        let camera = cameras[sender.tag]
        PreferencesManager.shared.toggleHidden(cameraId: camera.uniqueIdentifier)
        rebuildContent()
    }

    @objc private func addOverlayTapped(_ sender: NSButton) {
        guard sender.tag < cameras.count else { return }
        let camera = cameras[sender.tag]
        showAccessoryPicker(for: camera, relativeTo: sender)
    }

    @objc private func removeOverlayTapped(_ sender: NSButton) {
        guard let ids = sender.identifier?.rawValue.split(separator: "|"), ids.count == 2 else { return }
        let cameraId = String(ids[0])
        let serviceId = String(ids[1])
        PreferencesManager.shared.removeOverlayAccessory(serviceId: serviceId, from: cameraId)
        rebuildContent()
    }

    // MARK: - Accessory picker

    private func showAccessoryPicker(for camera: CameraData, relativeTo button: NSView) {
        guard let data = menuData else { return }

        let existingIds = Set(PreferencesManager.shared.overlayAccessories(for: camera.uniqueIdentifier))
        let toggleableTypes: Set<String> = [
            ServiceTypes.lightbulb,
            ServiceTypes.switch,
            ServiceTypes.outlet,
            ServiceTypes.garageDoorOpener,
            ServiceTypes.lock
        ]

        // Collect eligible services grouped by room
        var servicesByRoom: [String: [(service: ServiceData, roomName: String)]] = [:]
        let roomNames = data.roomLookup()

        for accessory in data.accessories {
            for service in accessory.services {
                if toggleableTypes.contains(service.serviceType) && !existingIds.contains(service.uniqueIdentifier) {
                    let roomName = accessory.roomIdentifier.flatMap { roomNames[$0] } ?? "Other"
                    servicesByRoom[roomName, default: []].append((service: service, roomName: roomName))
                }
            }
        }

        guard !servicesByRoom.isEmpty else {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.no_accessories.title", defaultValue: "No accessories available", bundle: .macOSBridge)
            alert.informativeText = String(localized: "alert.no_accessories.message", defaultValue: "All compatible accessories (lights, switches, outlets, garage openers, locks) are already assigned to this camera.", bundle: .macOSBridge)
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK", bundle: .macOSBridge))
            alert.runModal()
            return
        }

        // Build menu grouped by room, sorted alphabetically
        let menu = NSMenu()
        let sortedRooms = servicesByRoom.keys.sorted()

        for (index, roomName) in sortedRooms.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }
            let header = NSMenuItem(title: roomName, action: nil, keyEquivalent: "")
            header.isEnabled = false
            header.attributedTitle = NSAttributedString(string: roomName, attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            menu.addItem(header)

            let sortedServices = servicesByRoom[roomName]!.sorted { $0.service.name < $1.service.name }
            for entry in sortedServices {
                let item = NSMenuItem(title: entry.service.name, action: #selector(accessoryPickerItemSelected(_:)), keyEquivalent: "")
                item.target = self
                item.image = iconForServiceType(entry.service.serviceType)
                item.image?.size = NSSize(width: 14, height: 14)
                item.representedObject = (camera.uniqueIdentifier, entry.service.uniqueIdentifier)
                menu.addItem(item)
            }
        }

        let location = NSPoint(x: button.bounds.midX, y: button.bounds.maxY)
        menu.popUp(positioning: nil, at: location, in: button)
    }

    @objc private func accessoryPickerItemSelected(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? (String, String) else { return }
        let (cameraId, serviceId) = pair
        PreferencesManager.shared.addOverlayAccessory(serviceId: serviceId, to: cameraId)
        rebuildContent()
    }

    // MARK: - Helpers

    func findService(id: String) -> ServiceData? {
        guard let data = menuData else { return nil }
        for accessory in data.accessories {
            for service in accessory.services where service.uniqueIdentifier == id {
                return service
            }
        }
        return nil
    }

    func computeChipLines(for cameraId: String) -> Int {
        let ids = PreferencesManager.shared.overlayAccessories(for: cameraId)
        let chipWidths: [CGFloat] = ids.compactMap { id in
            guard let service = findService(id: id) else { return nil }
            let textWidth = min((service.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 10)]).width, 60)
            // icon(5+12+3) + text + gap(2) + remove(14+3)
            return 5 + 12 + 3 + textWidth + 2 + 14 + 3
        }
        if chipWidths.isEmpty { return 0 }

        // Use best available width: table bounds > view bounds > fallback
        let resolvedWidth: CGFloat
        if let tw = camerasTableView?.bounds.width, tw > 0 {
            resolvedWidth = tw
        } else if bounds.width > 0 {
            resolvedWidth = bounds.width
        } else {
            resolvedWidth = 560
        }
        let availableWidth = resolvedWidth - 66

        var x: CGFloat = 0
        var lines = 1
        for width in chipWidths {
            if x > 0 && x + width > availableWidth {
                lines += 1
                x = width + 4
            } else {
                x += width + 4
            }
        }
        return lines
    }

    private func iconForServiceType(_ type: String) -> NSImage? {
        IconMapping.iconForServiceType(type, filled: true)
    }

    private func createSettingRow(label: String, subtitle: String? = nil, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13)
        labelStack.addArrangedSubview(labelField)

        if let subtitle = subtitle {
            let subtitleField = NSTextField(labelWithString: subtitle)
            subtitleField.font = .systemFont(ofSize: 11)
            subtitleField.textColor = .secondaryLabelColor
            subtitleField.lineBreakMode = .byWordWrapping
            subtitleField.maximumNumberOfLines = 2
            labelStack.addArrangedSubview(subtitleField)
        }

        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelStack)
        container.addSubview(control)

        let rowHeight: CGFloat = subtitle != nil ? 56 : 36

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: rowHeight),
            labelStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func addView(_ view: NSView, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func setupBindings() {
        ProManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildContent()
            }
            .store(in: &cancellables)
    }
}

