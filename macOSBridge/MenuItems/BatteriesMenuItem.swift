//
//  BatteriesMenuItem.swift
//  macOSBridge
//
//  "Batteries" submenu listing every battery-powered device sorted by charge
//  level, lowest first, so devices that need charging surface at the top
//  (#144). Devices are deduped by battery characteristic – every service of an
//  accessory shares the accessory's battery sensor (sibling battery service on
//  HomeKit, same-device battery sensor on HA). Can be turned off in
//  Settings → Advanced.
//

import AppKit

/// One battery-powered device in the submenu.
struct BatteryDevice {
    let name: String
    let levelId: UUID
    let lowId: UUID?
    /// A service of the device, used for the row icon and the battery badge.
    let iconService: ServiceData
}

class BatteriesMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    weak var bridge: Mac2iOS?

    private var rows: [BatteryDeviceRow] = []
    private var levels: [UUID: Int] = [:]

    var characteristicIdentifiers: [UUID] {
        rows.flatMap { [$0.device.levelId] + ($0.device.lowId.map { [$0] } ?? []) }
    }

    /// Device names in current submenu order (lowest battery first). For tests.
    var orderedDeviceNames: [String] {
        submenu?.items.compactMap { ($0 as? BatteryDeviceRow)?.device.name } ?? []
    }

    /// Returns nil when no accessory exposes a battery.
    init?(accessories: [AccessoryData], bridge: Mac2iOS?) {
        let devices = Self.devices(from: accessories)
        guard !devices.isEmpty else { return nil }
        self.bridge = bridge

        let title = String(localized: "menu.batteries", defaultValue: "Batteries", bundle: .macOSBridge)
        super.init(title: title, action: nil, keyEquivalent: "")
        // The header view comes from MenuBuilder (kept out of the test target),
        // which assigns it when adding the item to the menu.

        // Rows are read-only, so a plain NSMenu is enough (no StayOpenMenu).
        let submenu = NSMenu()
        for device in devices {
            let row = BatteryDeviceRow(device: device)
            rows.append(row)
            submenu.addItem(row)
        }
        self.submenu = submenu
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Extract battery-powered devices, one per battery characteristic. All
    /// services of an accessory carry the same battery ids, so the first
    /// service with a battery represents its accessory.
    static func devices(from accessories: [AccessoryData]) -> [BatteryDevice] {
        var seen: Set<UUID> = []
        var devices: [BatteryDevice] = []
        for accessory in accessories {
            for service in accessory.services {
                guard let levelId = service.batteryLevelId.flatMap({ UUID(uuidString: $0) }),
                      !seen.contains(levelId) else { continue }
                seen.insert(levelId)
                devices.append(BatteryDevice(
                    name: accessory.name,
                    levelId: levelId,
                    lowId: service.statusLowBatteryId.flatMap { UUID(uuidString: $0) },
                    iconService: service
                ))
            }
        }
        return devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - CharacteristicUpdatable

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        guard let row = rows.first(where: {
            $0.device.levelId == characteristicId || $0.device.lowId == characteristicId
        }) else { return }

        row.batteryBadge?.updateValue(for: characteristicId, value: value)

        if row.device.levelId == characteristicId, let level = ValueConversion.toInt(value) {
            levels[characteristicId] = level
            resort()
        }
    }

    /// Reorder rows by charge level, lowest first; devices that have not
    /// reported a level yet stay at the bottom, alphabetically.
    private func resort() {
        guard let submenu else { return }
        let sorted = rows.sorted { a, b in
            let la = levels[a.device.levelId] ?? Int.max
            let lb = levels[b.device.levelId] ?? Int.max
            if la != lb { return la < lb }
            return a.device.name.localizedCaseInsensitiveCompare(b.device.name) == .orderedAscending
        }
        guard !sorted.elementsEqual(submenu.items.compactMap { $0 as? BatteryDeviceRow }, by: ===) else { return }
        submenu.removeAllItems()
        sorted.forEach { submenu.addItem($0) }
    }
}

/// A read-only row: device icon and name on the left, battery badge (gauge +
/// percentage) right-aligned. The parent item routes value updates here.
private final class BatteryDeviceRow: NSMenuItem {

    let device: BatteryDevice
    let batteryBadge: BatteryBadgeView?

    init(device: BatteryDevice) {
        self.device = device

        let height = DS.ControlSize.menuItemHeight
        let width = DS.ControlSize.menuItemWidth
        let containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let iconY = (height - DS.ControlSize.iconMedium) / 2
        let iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = IconResolver.icon(for: device.iconService)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        let badgeX = width - DS.Spacing.md - BatteryBadgeView.width
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let nameLabel = NSTextField(labelWithString: device.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: badgeX - labelX - DS.Spacing.xs, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        batteryBadge = BatteryBadgeView(serviceData: device.iconService)
        if let badge = batteryBadge {
            badge.setFrameOrigin(NSPoint(x: badgeX, y: (height - badge.frame.height) / 2))
            containerView.addSubview(badge)
        }

        super.init(title: device.name, action: nil, keyEquivalent: "")
        view = containerView
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
