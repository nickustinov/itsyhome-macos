//
//  SceneMenuItem.swift
//  macOSBridge
//
//  Menu item for controlling scenes with toggle switch (list style)
//

import AppKit

class SceneMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    let sceneData: SceneData
    weak var bridge: Mac2iOS?

    private var currentValues: [UUID: Double] = [:]
    private var isActive: Bool = false

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let toggleSwitch: ToggleSwitch

    // Characteristic types that can be reversed
    private static let reversibleTypes: Set<String> = [
        CharacteristicTypes.powerState,
        CharacteristicTypes.brightness,
        CharacteristicTypes.targetPosition,
        CharacteristicTypes.lockTargetState,
        CharacteristicTypes.targetDoorState,
        CharacteristicTypes.active,
        CharacteristicTypes.rotationSpeed
    ]

    var characteristicIdentifiers: [UUID] {
        sceneData.actions.compactMap { UUID(uuidString: $0.characteristicId) }
    }

    init(sceneData: SceneData, bridge: Mac2iOS?) {
        self.sceneData = sceneData
        self.bridge = bridge

        let height = DS.ControlSize.menuItemHeight

        // Create the custom view
        containerView = HighlightingMenuItemView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: height))

        // Icon
        let iconY = (height - DS.ControlSize.iconMedium) / 2
        iconView = NSImageView(frame: NSRect(x: DS.Spacing.md, y: iconY, width: DS.ControlSize.iconMedium, height: DS.ControlSize.iconMedium))
        iconView.image = Self.inferIcon(for: sceneData)
        iconView.contentTintColor = DS.Colors.iconForeground
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        // Name label
        let labelX = DS.Spacing.md + DS.ControlSize.iconMedium + DS.Spacing.sm
        let labelY = (height - 17) / 2
        let labelWidth = DS.ControlSize.menuItemWidth - labelX - DS.ControlSize.switchWidth - DS.Spacing.lg - DS.Spacing.md
        nameLabel = NSTextField(labelWithString: sceneData.name)
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: 17)
        nameLabel.font = DS.Typography.label
        nameLabel.textColor = DS.Colors.foreground
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)

        // Toggle switch
        let switchX = DS.ControlSize.menuItemWidth - DS.ControlSize.switchWidth - DS.Spacing.md
        let switchY = (height - DS.ControlSize.switchHeight) / 2
        toggleSwitch = ToggleSwitch()
        toggleSwitch.frame = NSRect(x: switchX, y: switchY, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
        containerView.addSubview(toggleSwitch)

        super.init(title: sceneData.name, action: nil, keyEquivalent: "")

        self.view = containerView

        containerView.closesMenuOnAction = false
        containerView.onAction = { [weak self] in
            guard let self else { return }
            self.isActive.toggle()
            self.toggleSwitch.setOn(self.isActive, animated: true)
            if self.isActive {
                self.executeScene()
                for action in self.sceneData.actions {
                    if let charId = UUID(uuidString: action.characteristicId) {
                        self.currentValues[charId] = action.targetValue
                    }
                }
            } else {
                self.reverseScene()
                self.cacheOffValues()
            }
            self.updateUI()
        }

        // Set up action
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleScene(_:))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool = false) {
        // Check if this characteristic belongs to this scene
        guard sceneData.actions.contains(where: { $0.characteristicId == characteristicId.uuidString }) else {
            return
        }

        // Convert value to Double
        guard let doubleValue = ValueConversion.toDouble(value) else {
            return
        }

        currentValues[characteristicId] = doubleValue
        updateActiveState()
    }

    private func updateActiveState() {
        guard !sceneData.actions.isEmpty else {
            isActive = false
            updateUI()
            return
        }

        let allMatch = sceneData.actions.allSatisfy { action in
            guard let charId = UUID(uuidString: action.characteristicId),
                  let currentValue = currentValues[charId] else {
                return false
            }
            let tolerance = Self.tolerance(for: action.characteristicType)
            return abs(currentValue - action.targetValue) < tolerance
        }

        isActive = allMatch
        updateUI()
    }

    private static func tolerance(for characteristicType: String) -> Double {
        switch characteristicType {
        case CharacteristicTypes.targetPosition,
             CharacteristicTypes.currentPosition,
             CharacteristicTypes.brightness,
             CharacteristicTypes.rotationSpeed:
            return 5.0
        default:
            return 0.01
        }
    }

    private func updateUI() {
        toggleSwitch.setOn(isActive, animated: false)
        toggleSwitch.needsDisplay = true
        iconView.needsDisplay = true
    }

    @objc private func toggleScene(_ sender: ToggleSwitch) {
        if sender.isOn {
            executeScene()
            // Optimistically update cached values
            for action in sceneData.actions {
                if let charId = UUID(uuidString: action.characteristicId) {
                    currentValues[charId] = action.targetValue
                }
            }
            isActive = true
        } else {
            reverseScene()
            cacheOffValues()
            isActive = false
        }
        updateUI()
    }

    private func executeScene() {
        guard let uuid = UUID(uuidString: sceneData.uniqueIdentifier) else { return }
        bridge?.executeScene(identifier: uuid)
    }

    /// Deactivate a scene by turning off only things the scene turned on.
    /// Matches Apple Home behaviour: deactivating a scene never turns on lights,
    /// unlocks doors, or opens garage doors.
    private func reverseScene() {
        for action in sceneData.actions {
            guard let charId = UUID(uuidString: action.characteristicId),
                  Self.reversibleTypes.contains(action.characteristicType),
                  let offValue = Self.offValue(for: action) else {
                continue
            }
            bridge?.writeCharacteristic(identifier: charId, value: offValue)
        }
    }

    /// Optimistically cache the off values for all reversible actions.
    private func cacheOffValues() {
        for action in sceneData.actions {
            guard let charId = UUID(uuidString: action.characteristicId),
                  Self.reversibleTypes.contains(action.characteristicType),
                  let offValue = Self.offValue(for: action) else {
                continue
            }
            if let doubleValue = offValue as? Double {
                currentValues[charId] = doubleValue
            } else if let intValue = offValue as? Int {
                currentValues[charId] = Double(intValue)
            } else if let boolValue = offValue as? Bool {
                currentValues[charId] = boolValue ? 1.0 : 0.0
            }
        }
    }

    /// Returns the "off" value for an action if the scene turned the device on,
    /// or nil if the scene already set the device to its off state (no action needed).
    static func offValue(for action: SceneActionData) -> Any? {
        let charType = action.characteristicType
        let target = action.targetValue

        switch charType {
        case CharacteristicTypes.powerState, CharacteristicTypes.active:
            // Only turn off if the scene turned it on
            return target > 0.5 ? false : nil
        case CharacteristicTypes.brightness, CharacteristicTypes.rotationSpeed:
            // Only set to 0 if the scene set a non-zero value
            return target > 0.5 ? 0 : nil
        case CharacteristicTypes.targetPosition:
            // Only close if the scene opened (position > 50 means open)
            return target > 50 ? 0 : nil
        case CharacteristicTypes.lockTargetState:
            // Lock target: 1 = secured, 0 = unsecured. Never unlock.
            return nil
        case CharacteristicTypes.targetDoorState:
            // Door target: 0 = open, 1 = closed. Only close if the scene opened.
            return target < 0.5 ? 1 : nil
        default:
            return target > 0.5 ? 0 : nil
        }
    }

    private static func inferIcon(for scene: SceneData) -> NSImage? {
        IconResolver.icon(for: scene)
    }
}
