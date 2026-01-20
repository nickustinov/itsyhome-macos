//
//  ModernSlider.swift
//  macOSBridge
//
//  Custom slider control inspired by shadcn/ui
//  Rounded track with filled range and circular thumb
//

import AppKit
import QuartzCore

class ModernSlider: NSControl {

    // MARK: - Properties

    var minValue: Double = 0 {
        didSet { updateThumbPosition() }
    }

    var maxValue: Double = 100 {
        didSet { updateThumbPosition() }
    }

    private var _doubleValue: Double = 0

    override var doubleValue: Double {
        get { _doubleValue }
        set {
            let clamped = min(max(newValue, minValue), maxValue)
            if _doubleValue != clamped {
                _doubleValue = clamped
                updateThumbPosition()
            }
        }
    }

    // isContinuous is inherited from NSControl

    var trackTintColor: NSColor = DS.Colors.muted {
        didSet { updateColors() }
    }

    var progressTintColor: NSColor = DS.Colors.foreground {
        didSet { updateColors() }
    }

    var thumbColor: NSColor = .white {
        didSet { updateColors() }
    }

    private let trackLayer = CALayer()
    private let progressLayer = CALayer()
    private let thumbLayer = CALayer()

    private var trackingArea: NSTrackingArea?
    private var isDragging = false
    private var isHovered = false

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    convenience init(minValue: Double = 0, maxValue: Double = 100) {
        self.init(frame: NSRect(x: 0, y: 0, width: 150, height: 20))
        self.minValue = minValue
        self.maxValue = maxValue
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Track layer (background)
        trackLayer.cornerRadius = DS.ControlSize.sliderTrackHeight / 2
        trackLayer.masksToBounds = true
        layer?.addSublayer(trackLayer)

        // Progress layer (filled part)
        progressLayer.cornerRadius = DS.ControlSize.sliderTrackHeight / 2
        progressLayer.masksToBounds = true
        layer?.addSublayer(progressLayer)

        // Thumb layer
        thumbLayer.cornerRadius = DS.ControlSize.sliderThumbSize / 2
        thumbLayer.borderWidth = 1.5
        thumbLayer.masksToBounds = true
        layer?.addSublayer(thumbLayer)

        updateColors()
        layoutLayers()
    }

    // MARK: - Layout

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: DS.ControlSize.sliderThumbSize)
    }

    override func layout() {
        super.layout()
        layoutLayers()
    }

    private func layoutLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let trackHeight = DS.ControlSize.sliderTrackHeight
        let thumbSize = DS.ControlSize.sliderThumbSize
        let trackWidth = bounds.width - thumbSize
        let trackY = (bounds.height - trackHeight) / 2
        let trackX = thumbSize / 2

        // Track frame
        trackLayer.frame = CGRect(x: trackX, y: trackY, width: trackWidth, height: trackHeight)

        // Calculate thumb position
        let progress = (doubleValue - minValue) / (maxValue - minValue)
        let thumbX = trackX + CGFloat(progress) * trackWidth - thumbSize / 2
        let thumbY = (bounds.height - thumbSize) / 2
        let thumbFrame = CGRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)

        thumbLayer.frame = thumbFrame

        // Progress frame
        let progressWidth = CGFloat(progress) * trackWidth
        progressLayer.frame = CGRect(x: trackX, y: trackY, width: progressWidth, height: trackHeight)

        CATransaction.commit()
    }

    private func updateThumbPosition() {
        layoutLayers()
    }

    // MARK: - Appearance

    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let appearance = effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            trackLayer.backgroundColor = trackTintColor.cgColor
            progressLayer.backgroundColor = progressTintColor.cgColor
            thumbLayer.backgroundColor = thumbColor.cgColor
            thumbLayer.borderColor = progressTintColor.cgColor
        }

        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
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
        animateThumbScale(scale: 1.1)
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            isHovered = false
            animateThumbScale(scale: 1.0)
            NSCursor.pop()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isDragging = true
        updateValueFromEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, isEnabled else { return }
        updateValueFromEvent(event)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if !isHovered {
            animateThumbScale(scale: 1.0)
        }
        if !isContinuous {
            sendAction(action, to: target)
        }
    }

    private func updateValueFromEvent(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let thumbSize = DS.ControlSize.sliderThumbSize
        let trackWidth = bounds.width - thumbSize
        let trackX = thumbSize / 2

        let relativeX = location.x - trackX
        let progress = max(0, min(1, relativeX / trackWidth))
        let newValue = minValue + Double(progress) * (maxValue - minValue)

        if newValue != doubleValue {
            doubleValue = newValue
            if isContinuous {
                sendAction(action, to: target)
            }
        }
    }

    private func animateThumbScale(scale: CGFloat) {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = thumbLayer.presentation()?.value(forKeyPath: "transform.scale") ?? 1.0
        animation.toValue = scale
        animation.damping = 15
        animation.stiffness = 300
        animation.duration = animation.settlingDuration

        thumbLayer.add(animation, forKey: "scale")
        thumbLayer.setValue(scale, forKeyPath: "transform.scale")
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .slider }

    override func accessibilityValue() -> Any? { doubleValue }

    override func accessibilityMinValue() -> Any? { minValue }

    override func accessibilityMaxValue() -> Any? { maxValue }

    override func accessibilityPerformIncrement() -> Bool {
        let step = (maxValue - minValue) / 10
        doubleValue = min(maxValue, doubleValue + step)
        sendAction(action, to: target)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        let step = (maxValue - minValue) / 10
        doubleValue = max(minValue, doubleValue - step)
        sendAction(action, to: target)
        return true
    }
}
