//
//  CamerasSection.swift
//  macOSBridge
//
//  Cameras settings section with ordering, visibility, and overlay accessories
//

import AppKit
import Combine

private extension NSPasteboard.PasteboardType {
    static let cameraItem = NSPasteboard.PasteboardType("com.itsyhome.cameraItem")
}

class CamerasSection: NSView {

    private let stackView = NSStackView()
    private let cameraSwitch = NSSwitch()
    private var camerasTableView: NSTableView?
    private var menuData: MenuData?
    private var cameras: [CameraData] = []
    private var cancellables = Set<AnyCancellable>()

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
            label: "Show cameras in menu bar",
            subtitle: "Display a camera icon in the menu bar to quickly view live camera feeds.",
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

        addSpacer(height: 16)

        // Camera list
        loadCameras()
        if !cameras.isEmpty {
            let header = AccessorySectionHeader(title: "Your cameras")
            addView(header, height: 32)
            addSpacer(height: 4)

            let rowHeight: CGFloat = 46
            let spacing: CGFloat = 4
            let tableHeight = CGFloat(cameras.count) * rowHeight + CGFloat(max(0, cameras.count - 1)) * spacing
            let tableContainer = createCamerasTable(height: tableHeight, rowHeight: rowHeight, spacing: spacing)
            addView(tableContainer, height: tableHeight)
        } else if menuData != nil {
            let emptyLabel = NSTextField(labelWithString: "No cameras found in this home.")
            emptyLabel.font = .systemFont(ofSize: 11)
            emptyLabel.textColor = .tertiaryLabelColor
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(emptyLabel)
        }

        addSpacer(height: 16)
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

    private func rebuildContent() {
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

    private func createCameraRowView(camera: CameraData, row: Int) -> NSView {
        let isPro = ProStatusCache.shared.isPro
        let isHidden = PreferencesManager.shared.isHidden(cameraId: camera.uniqueIdentifier)
        let overlayIds = PreferencesManager.shared.overlayAccessories(for: camera.uniqueIdentifier)

        let container = CardBoxView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Drag handle
        let dragHandle = DragHandleView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.isHidden = !isPro
        container.addSubview(dragHandle)

        // Eye button
        let eyeButton = NSButton()
        eyeButton.bezelStyle = .inline
        eyeButton.isBordered = false
        eyeButton.imagePosition = .imageOnly
        eyeButton.imageScaling = .scaleProportionallyUpOrDown
        let eyeSymbol = isHidden ? "eye.slash" : "eye"
        eyeButton.image = NSImage(systemSymbolName: eyeSymbol, accessibilityDescription: nil)
        eyeButton.contentTintColor = isHidden ? .tertiaryLabelColor : .secondaryLabelColor
        eyeButton.target = self
        eyeButton.action = #selector(eyeTapped(_:))
        eyeButton.tag = row
        eyeButton.isEnabled = isPro
        eyeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(eyeButton)

        // Camera icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "video", accessibilityDescription: camera.name)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        // Name label
        let nameLabel = NSTextField(labelWithString: camera.name)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.alphaValue = isHidden ? 0.5 : 1.0
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        // Overlay accessories chips + add button
        let chipsStack = NSStackView()
        chipsStack.orientation = .horizontal
        chipsStack.spacing = 4
        chipsStack.alignment = .centerY
        chipsStack.translatesAutoresizingMaskIntoConstraints = false

        for serviceId in overlayIds {
            if let service = findService(id: serviceId) {
                let chip = createAccessoryChip(service: service, cameraId: camera.uniqueIdentifier)
                chipsStack.addArrangedSubview(chip)
            }
        }

        // Add button
        let addButton = NSButton(title: "Add accessory", target: self, action: #selector(addOverlayTapped(_:)))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .regular
        addButton.tag = row
        addButton.isEnabled = isPro
        addButton.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.addArrangedSubview(addButton)

        container.addSubview(chipsStack)

        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            dragHandle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 12),
            dragHandle.heightAnchor.constraint(equalToConstant: 20),

            eyeButton.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 6),
            eyeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            eyeButton.widthAnchor.constraint(equalToConstant: 20),
            eyeButton.heightAnchor.constraint(equalToConstant: 20),

            iconView.leadingAnchor.constraint(equalTo: eyeButton.trailingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            chipsStack.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),
            chipsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            chipsStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

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

        let removeButton = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")!, target: self, action: #selector(removeOverlayTapped(_:)))
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
            ServiceTypes.garageDoorOpener
        ]

        // Collect eligible services grouped by room
        var servicesByRoom: [String: [(service: ServiceData, roomName: String)]] = [:]
        let roomNames = Dictionary(uniqueKeysWithValues: data.rooms.map { ($0.uniqueIdentifier, $0.name) })

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
            alert.messageText = "No accessories available"
            alert.informativeText = "All compatible accessories (lights, switches, outlets, garage openers) are already assigned to this camera."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
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

    private func findService(id: String) -> ServiceData? {
        guard let data = menuData else { return nil }
        for accessory in data.accessories {
            for service in accessory.services where service.uniqueIdentifier == id {
                return service
            }
        }
        return nil
    }

    private func iconForServiceType(_ type: String) -> NSImage? {
        let name: String
        switch type {
        case ServiceTypes.lightbulb: name = "lightbulb"
        case ServiceTypes.switch: name = "switch.2"
        case ServiceTypes.outlet: name = "poweroutlet.type.b"
        case ServiceTypes.garageDoorOpener: name = "door.garage.open"
        default: name = "bolt"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
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

// MARK: - Table delegate

extension CamerasSection: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        cameras.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        createCameraRowView(camera: cameras[row], row: row)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        46
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isGroupRowStyle = false
        return rowView
    }

    // MARK: - Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard ProStatusCache.shared.isPro else { return nil }
        let camera = cameras[row]
        let pb = NSPasteboardItem()
        pb.setString(camera.uniqueIdentifier, forType: .cameraItem)
        return pb
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let pb = items.first,
              let draggedId = pb.string(forType: .cameraItem),
              let originalRow = cameras.firstIndex(where: { $0.uniqueIdentifier == draggedId }) else {
            return false
        }

        var newRow = row
        if originalRow < newRow { newRow -= 1 }
        if originalRow == newRow { return false }

        // Update order in preferences
        var order = cameras.map { $0.uniqueIdentifier }
        let item = order.remove(at: originalRow)
        order.insert(item, at: newRow)
        PreferencesManager.shared.cameraOrder = order

        // Rebuild to avoid stale row rendering
        DispatchQueue.main.async { [weak self] in
            self?.rebuildContent()
        }

        return true
    }
}
