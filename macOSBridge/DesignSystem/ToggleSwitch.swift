//
//  ToggleSwitch.swift
//  macOSBridge
//
//  Custom toggle switch control inspired by shadcn/ui
//  Pill-shaped track with animated circular thumb
//

import AppKit
import QuartzCore

class ToggleSwitch: NSControl {

    // MARK: - Properties

    private var _isOn: Bool = false

    var isOn: Bool {
        get { _isOn }
        set {
            guard newValue != _isOn else { return }
            _isOn = newValue
            animateToggle()
            sendAction(action, to: target)
        }
    }

    /// Set state without firing action (use for external updates)
    func setOn(_ on: Bool, animated: Bool = true) {
        guard on != _isOn else { return }
        _isOn = on
        if animated {
            animateToggle()
        } else {
            layoutLayers()
            updateColors()
        }
    }

    var onTintColor: NSColor = DS.Colors.switchOn {
        didSet { updateColors() }
    }

    var offTintColor: NSColor = DS.Colors.input {
        didSet { updateColors() }
    }

    var thumbColor: NSColor = .white {
        didSet { updateColors() }
    }

    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()
    private let thumbShadowLayer = CALayer()

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isMouseDown = false

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    convenience init() {
        self.init(frame: NSRect(x: 0, y: 0, width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight))
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Track layer
        trackLayer.cornerRadius = DS.ControlSize.switchHeight / 2
        trackLayer.masksToBounds = true
        layer?.addSublayer(trackLayer)

        // Thumb shadow layer
        thumbShadowLayer.cornerRadius = DS.ControlSize.switchThumbSize / 2
        thumbShadowLayer.shadowColor = NSColor.black.cgColor
        thumbShadowLayer.shadowOffset = CGSize(width: 0, height: 1)
        thumbShadowLayer.shadowRadius = 2
        thumbShadowLayer.shadowOpacity = 0.2
        layer?.addSublayer(thumbShadowLayer)

        // Thumb layer
        thumbLayer.cornerRadius = DS.ControlSize.switchThumbSize / 2
        thumbLayer.masksToBounds = true
        layer?.addSublayer(thumbLayer)

        updateColors()
        layoutLayers()
    }

    // MARK: - Layout

    override var intrinsicContentSize: NSSize {
        NSSize(width: DS.ControlSize.switchWidth, height: DS.ControlSize.switchHeight)
    }

    override func layout() {
        super.layout()
        layoutLayers()
    }

    private func layoutLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let trackWidth = DS.ControlSize.switchWidth
        let trackHeight = DS.ControlSize.switchHeight
        let thumbSize = DS.ControlSize.switchThumbSize
        let padding = DS.ControlSize.switchThumbPadding

        // Center track in view
        let trackX = (bounds.width - trackWidth) / 2
        let trackY = (bounds.height - trackHeight) / 2
        trackLayer.frame = CGRect(x: trackX, y: trackY, width: trackWidth, height: trackHeight)

        // Calculate thumb position
        let thumbX: CGFloat
        if isOn {
            thumbX = trackX + trackWidth - thumbSize - padding
        } else {
            thumbX = trackX + padding
        }
        let thumbY = trackY + (trackHeight - thumbSize) / 2

        let thumbFrame = CGRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)
        thumbLayer.frame = thumbFrame
        thumbShadowLayer.frame = thumbFrame
        thumbShadowLayer.backgroundColor = NSColor.white.cgColor

        CATransaction.commit()
    }

    // MARK: - Appearance

    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let appearance = effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            trackLayer.backgroundColor = isOn ? onTintColor.cgColor : offTintColor.cgColor
            thumbLayer.backgroundColor = thumbColor.cgColor
        }

        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    // MARK: - Animation

    private func animateToggle() {
        let trackWidth = DS.ControlSize.switchWidth
        let thumbSize = DS.ControlSize.switchThumbSize
        let padding = DS.ControlSize.switchThumbPadding

        let trackX = (bounds.width - trackWidth) / 2
        let trackY = (bounds.height - DS.ControlSize.switchHeight) / 2

        let thumbX: CGFloat
        if isOn {
            thumbX = trackX + trackWidth - thumbSize - padding
        } else {
            thumbX = trackX + padding
        }
        let thumbY = trackY + (DS.ControlSize.switchHeight - thumbSize) / 2
        let thumbFrame = CGRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)

        // Animate thumb position
        let positionAnimation = CASpringAnimation(keyPath: "position")
        positionAnimation.fromValue = thumbLayer.position
        positionAnimation.toValue = CGPoint(x: thumbFrame.midX, y: thumbFrame.midY)
        positionAnimation.damping = 15
        positionAnimation.stiffness = 300
        positionAnimation.mass = 1
        positionAnimation.duration = positionAnimation.settlingDuration

        CATransaction.begin()
        thumbLayer.add(positionAnimation, forKey: "position")
        thumbShadowLayer.add(positionAnimation, forKey: "position")
        thumbLayer.position = CGPoint(x: thumbFrame.midX, y: thumbFrame.midY)
        thumbShadowLayer.position = CGPoint(x: thumbFrame.midX, y: thumbFrame.midY)

        // Animate track color
        let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
        let appearance = effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            colorAnimation.fromValue = trackLayer.backgroundColor
            colorAnimation.toValue = isOn ? onTintColor.cgColor : offTintColor.cgColor
            trackLayer.backgroundColor = isOn ? onTintColor.cgColor : offTintColor.cgColor
        }
        colorAnimation.duration = DS.Animation.fast
        trackLayer.add(colorAnimation, forKey: "backgroundColor")

        CATransaction.commit()
    }

    // MARK: - Mouse handling

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        // Verify click is inside our bounds
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            isMouseDown = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, isMouseDown else { return }
        isMouseDown = false
        // Only toggle if mouse is still inside the control
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            isOn.toggle()
        }
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .checkBox }

    override func accessibilityValue() -> Any? { isOn }

    override func accessibilityPerformPress() -> Bool {
        isOn.toggle()
        return true
    }
}
