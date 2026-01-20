//
//  LockMenuItem.swift
//  macOSBridge
//
//  Menu item for door locks
//

import AppKit

class LockMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let serviceData: ServiceData
    weak var bridge: Mac2iOS?

    private var lockStateCharacteristicId: UUID?
    private var targetStateCharacteristicId: UUID?
    private var isLocked: Bool = true

    private let containerView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let statusLabel: NSTextField
    private let actionButton: NSButton

    var characteristicIdentifiers: [UUID] {
        var ids: [UUID] = []
        if let id = lockStateCharacteristicId { ids.append(id) }
        return ids
    }

    init(serviceData: ServiceData, bridge: Mac2iOS?) {
        self.serviceData = serviceData
        self.bridge = bridge

        // Extract characteristic UUIDs from ServiceData
        self.lockStateCharacteristicId = serviceData.lockCurrentStateId.flatMap { UUID(uuidString: $0) }
        self.targetStateCharacteristicId = serviceData.lockTargetStateId.flatMap { UUID(uuidString: $0) }

        // Create the custom view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))

        // Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 5, width: 20, height: 20))
        iconView.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .systemGreen
        containerView.addSubview(iconView)

        // Name label
        nameLabel = NSTextField(labelWithString: serviceData.name)
        nameLabel.frame = NSRect(x: 38, y: 6, width: 100, height: 17)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        containerView.addSubview(nameLabel)

        // Status label
        statusLabel = NSTextField(labelWithString: "Locked")
        statusLabel.frame = NSRect(x: 140, y: 6, width: 50, height: 17)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        containerView.addSubview(statusLabel)

        // Action button
        actionButton = NSButton(frame: NSRect(x: 195, y: 2, width: 50, height: 26))
        actionButton.bezelStyle = .inline
        actionButton.title = "Unlock"
        actionButton.font = NSFont.systemFont(ofSize: 11)
        containerView.addSubview(actionButton)

        super.init(title: serviceData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        // Set up action
        actionButton.target = self
        actionButton.action = #selector(toggleLock(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any) {
        if characteristicId == lockStateCharacteristicId {
            // 0 = unsecured, 1 = secured
            if let state = value as? Int {
                isLocked = state == 1
                updateUI()
            }
        }
    }

    private func updateUI() {
        iconView.image = NSImage(systemSymbolName: isLocked ? "lock.fill" : "lock.open", accessibilityDescription: nil)
        iconView.contentTintColor = isLocked ? .systemGreen : .systemOrange
        statusLabel.stringValue = isLocked ? "Locked" : "Unlocked"
        actionButton.title = isLocked ? "Unlock" : "Lock"
    }

    @objc private func toggleLock(_ sender: NSButton) {
        if isLocked {
            // Show confirmation before unlocking
            let alert = NSAlert()
            alert.messageText = "Unlock \(serviceData.name)?"
            alert.informativeText = "Are you sure you want to unlock this door?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Unlock")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                setLockState(locked: false)
            }
        } else {
            setLockState(locked: true)
        }
    }

    private func setLockState(locked: Bool) {
        if let id = targetStateCharacteristicId {
            bridge?.writeCharacteristic(identifier: id, value: locked ? 1 : 0)
            isLocked = locked
            updateUI()
        }
    }
}
