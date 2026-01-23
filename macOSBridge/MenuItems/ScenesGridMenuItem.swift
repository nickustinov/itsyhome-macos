//
//  ScenesGridMenuItem.swift
//  macOSBridge
//
//  Grid of pill-shaped scene buttons like native Home app
//

import AppKit

class ScenesGridMenuItem: NSMenuItem, CharacteristicUpdatable, CharacteristicRefreshable {

    private let scenes: [SceneData]
    weak var bridge: Mac2iOS?

    private let containerView: NSView
    private var sceneButtons: [SceneButton] = []

    var characteristicIdentifiers: [UUID] {
        scenes.flatMap { scene in
            scene.actions.compactMap { UUID(uuidString: $0.characteristicId) }
        }
    }

    init(scenes: [SceneData], bridge: Mac2iOS?) {
        self.scenes = scenes
        self.bridge = bridge

        // Calculate grid layout - fixed 2 columns
        let padding: CGFloat = DS.Spacing.md
        let horizontalSpacing: CGFloat = 8
        let verticalSpacing: CGFloat = 8
        let buttonsPerRow = 2
        let buttonWidth: CGFloat = (DS.ControlSize.menuItemWidth - (padding * 2) - horizontalSpacing) / 2
        let buttonHeight: CGFloat = 36

        let rows = (scenes.count + buttonsPerRow - 1) / buttonsPerRow
        let totalHeight = CGFloat(rows) * buttonHeight + CGFloat(max(0, rows - 1)) * verticalSpacing + (padding * 2)

        containerView = NSView(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.menuItemWidth, height: totalHeight))

        // Create scene buttons
        for (index, scene) in scenes.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow

            let x = padding + CGFloat(col) * (buttonWidth + horizontalSpacing)
            let y = totalHeight - padding - buttonHeight - CGFloat(row) * (buttonHeight + verticalSpacing)

            let button = SceneButton(sceneData: scene, bridge: bridge)
            button.frame = NSRect(x: x, y: y, width: buttonWidth, height: buttonHeight)
            containerView.addSubview(button)
            sceneButtons.append(button)
        }

        super.init(title: "", action: nil, keyEquivalent: "")
        self.view = containerView
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool) {
        for button in sceneButtons {
            button.updateValue(for: characteristicId, value: value)
        }
    }
}

// MARK: - Scene Button

class SceneButton: NSView {

    let sceneData: SceneData
    weak var bridge: Mac2iOS?

    private var currentValues: [UUID: Double] = [:]
    private var isActive: Bool = false

    private let backgroundView: NSView
    private let iconView: NSImageView
    private let nameLabel: NSTextField

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

    init(sceneData: SceneData, bridge: Mac2iOS?) {
        self.sceneData = sceneData
        self.bridge = bridge

        backgroundView = NSView()
        iconView = NSImageView()
        nameLabel = NSTextField(labelWithString: sceneData.name)

        super.init(frame: .zero)

        setupViews()
        updateUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Background with rounded corners
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 10
        addSubview(backgroundView)

        // Icon
        iconView.image = inferIcon(for: sceneData)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        // Name label
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 2
        nameLabel.cell?.wraps = true
        nameLabel.cell?.truncatesLastVisibleLine = true
        nameLabel.alignment = .left
        addSubview(nameLabel)

        // Click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(clickGesture)
    }

    override func layout() {
        super.layout()

        backgroundView.frame = bounds

        let iconSize: CGFloat = 16
        let iconX: CGFloat = 10
        let iconY = (bounds.height - iconSize) / 2
        iconView.frame = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)

        let labelX = iconX + iconSize + 6
        let labelWidth = bounds.width - labelX - 8

        // Calculate actual text height to center properly
        let textHeight = nameLabel.attributedStringValue.boundingRect(
            with: NSSize(width: labelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height

        // Use single line height if text fits, otherwise allow 2 lines
        let singleLineHeight: CGFloat = 14
        let labelHeight = textHeight <= singleLineHeight + 2 ? singleLineHeight : 28
        let labelY = (bounds.height - labelHeight) / 2
        nameLabel.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
    }

    func updateValue(for characteristicId: UUID, value: Any) {
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

    // Tolerance for matching characteristic values - position-based values need larger tolerance
    private static func tolerance(for characteristicType: String) -> Double {
        switch characteristicType {
        case CharacteristicTypes.targetPosition,
             CharacteristicTypes.currentPosition,
             CharacteristicTypes.brightness,
             CharacteristicTypes.rotationSpeed:
            // Position/percentage values: allow 5% tolerance for hardware variance
            return 5.0
        default:
            // Boolean/discrete values: strict tolerance
            return 0.01
        }
    }

    private func updateUI() {
        if isActive {
            // Active: solid light background, dark text
            backgroundView.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor
            iconView.contentTintColor = DS.Colors.warning
            nameLabel.textColor = NSColor(white: 0.1, alpha: 1.0)
        } else {
            // Inactive: semi-transparent dark background, light text
            backgroundView.layer?.backgroundColor = NSColor(white: 0.3, alpha: 0.5).cgColor
            iconView.contentTintColor = NSColor(white: 0.7, alpha: 1.0)
            nameLabel.textColor = NSColor(white: 0.95, alpha: 1.0)
        }
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        if isActive {
            reverseScene()
            // Optimistically update to inactive and cache opposite values
            for action in sceneData.actions {
                if let charId = UUID(uuidString: action.characteristicId),
                   Self.reversibleTypes.contains(action.characteristicType) {
                    let oppositeValue = calculateOppositeValue(for: action)
                    if let doubleValue = ValueConversion.toDouble(oppositeValue) {
                        currentValues[charId] = doubleValue
                    }
                    notifyLocalChange(characteristicId: charId, value: oppositeValue)
                }
            }
            isActive = false
        } else {
            executeScene()
            // Optimistically update to active and cache expected values
            for action in sceneData.actions {
                if let charId = UUID(uuidString: action.characteristicId) {
                    currentValues[charId] = action.targetValue
                    notifyLocalChange(characteristicId: charId, value: action.targetValue)
                }
            }
            isActive = true
        }
        updateUI()

        // Visual feedback
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.05
            backgroundView.animator().alphaValue = 0.6
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                self.backgroundView.animator().alphaValue = 1.0
            }
        }
    }

    private func executeScene() {
        guard let uuid = UUID(uuidString: sceneData.uniqueIdentifier) else { return }
        bridge?.executeScene(identifier: uuid)
    }

    private func reverseScene() {
        for action in sceneData.actions {
            guard let charId = UUID(uuidString: action.characteristicId),
                  Self.reversibleTypes.contains(action.characteristicType) else {
                continue
            }
            let oppositeValue = calculateOppositeValue(for: action)
            bridge?.writeCharacteristic(identifier: charId, value: oppositeValue)
        }
    }

    private func calculateOppositeValue(for action: SceneActionData) -> Any {
        let charType = action.characteristicType
        let targetValue = action.targetValue

        switch charType {
        case CharacteristicTypes.powerState, CharacteristicTypes.active:
            return targetValue > 0.5 ? false : true
        case CharacteristicTypes.brightness, CharacteristicTypes.rotationSpeed:
            return 0
        case CharacteristicTypes.targetPosition:
            return targetValue > 50 ? 0 : 100
        case CharacteristicTypes.lockTargetState, CharacteristicTypes.targetDoorState:
            return targetValue > 0.5 ? 0 : 1
        default:
            return targetValue > 0.5 ? 0 : 1
        }
    }

    private func notifyLocalChange(characteristicId: UUID, value: Any) {
        NotificationCenter.default.post(
            name: .characteristicDidChangeLocally,
            object: self,
            userInfo: ["characteristicId": characteristicId, "value": value]
        )
    }

    private func inferIcon(for scene: SceneData) -> NSImage? {
        SceneIconInference.icon(for: scene.name)
    }
}
