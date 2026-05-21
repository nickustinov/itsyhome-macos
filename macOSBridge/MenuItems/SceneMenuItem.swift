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
    private var optimisticUntil: Date?  // Ignore state updates until this time

    private let containerView: HighlightingMenuItemView
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let toggleSwitch: ToggleSwitch

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
            // Set optimistic period to ignore state updates during slow operations
            self.optimisticUntil = Date().addingTimeInterval(30)
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

        // Skip state recalculation during optimistic period (e.g., slow cover operations)
        if let optimisticUntil = optimisticUntil, Date() < optimisticUntil {
            return
        }

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
            let tolerance = SceneStateHelper.tolerance(for: action.characteristicType)
            return abs(currentValue - action.targetValue) < tolerance
        }

        isActive = allMatch
        updateUI()
    }

    private func updateUI() {
        toggleSwitch.setOn(isActive, animated: false)
        toggleSwitch.needsDisplay = true
        iconView.needsDisplay = true
    }

    @objc private func toggleScene(_ sender: ToggleSwitch) {
        // Set optimistic period to ignore state updates during slow operations
        optimisticUntil = Date().addingTimeInterval(30)

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

    private func reverseScene() {
        SceneStateHelper.reverse(scene: sceneData, bridge: bridge)
    }

    /// Optimistically cache the off values for all reversible actions.
    private func cacheOffValues() {
        for action in sceneData.actions {
            guard let charId = UUID(uuidString: action.characteristicId),
                  SceneStateHelper.reversibleTypes.contains(action.characteristicType),
                  let offValue = SceneStateHelper.offValue(for: action) else {
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

    private static func inferIcon(for scene: SceneData) -> NSImage? {
        IconResolver.icon(for: scene)
    }
}
