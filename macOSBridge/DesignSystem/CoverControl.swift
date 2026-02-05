//
//  CoverControl.swift
//  macOSBridge
//
//  3-position control for covers without position support
//  Looks like ToggleSwitch but with 3 positions: open/stop/close
//

import AppKit

/// State representation for cover control
enum CoverState: Int {
    case closed = 0   // Down position
    case stopped = 1  // Middle position
    case open = 2     // Up position
}

/// A 3-position toggle-like control for cover open/stop/close actions
class CoverControl: NSControl {

    // MARK: - Properties

    private var _state: CoverState = .closed

    var coverState: CoverState {
        get { _state }
        set {
            guard newValue != _state else { return }
            _state = newValue
            animateThumb()
        }
    }

    /// Set state without animation
    func setState(_ state: CoverState) {
        guard state != _state else { return }
        _state = state
        layoutLayers()
    }

    /// Callback for actions: 0=close, 1=stop, 2=open
    var onAction: ((Int) -> Void)?

    // Layers
    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()
    private let thumbShadowLayer = CALayer()

    // Icon image views (on track) - just arrows, no stop
    private let downIcon = NSImageView()
    private let upIcon = NSImageView()

    // Icon on thumb (shows current state)
    private let thumbIcon = NSImageView()

    private var trackingArea: NSTrackingArea?

    // Sizing - use DS constants for consistency with ToggleSwitch
    private let controlWidth: CGFloat = 42  // Wider for 3 positions
    private var controlHeight: CGFloat { DS.ControlSize.switchHeight }
    private var thumbSize: CGFloat { DS.ControlSize.switchThumbSize }
    private var thumbPadding: CGFloat { DS.ControlSize.switchThumbPadding }
    private let iconSize: CGFloat = 8

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
        self.init(frame: NSRect(x: 0, y: 0, width: 42, height: DS.ControlSize.switchHeight))
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Track layer (pill background)
        trackLayer.cornerRadius = controlHeight / 2
        trackLayer.masksToBounds = true
        layer?.addSublayer(trackLayer)

        // Setup icons - just arrows, no stop
        setupIcon(downIcon, symbolName: "arrow.down")
        setupIcon(upIcon, symbolName: "arrow.up")

        addSubview(downIcon)
        addSubview(upIcon)

        // Thumb icon (shows current state on thumb)
        setupIcon(thumbIcon, symbolName: "arrow.down")

        // Thumb shadow
        thumbShadowLayer.cornerRadius = thumbSize / 2
        thumbShadowLayer.shadowColor = NSColor.black.cgColor
        thumbShadowLayer.shadowOffset = CGSize(width: 0, height: 1)
        thumbShadowLayer.shadowRadius = 2
        thumbShadowLayer.shadowOpacity = 0.2
        layer?.addSublayer(thumbShadowLayer)

        // Thumb
        thumbLayer.cornerRadius = thumbSize / 2
        thumbLayer.masksToBounds = true
        layer?.addSublayer(thumbLayer)

        // Add thumb icon on top
        addSubview(thumbIcon)

        updateColors()
        layoutLayers()
    }

    private func setupIcon(_ imageView: NSImageView, symbolName: String) {
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            imageView.image = image
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
    }

    // MARK: - Layout

    override var intrinsicContentSize: NSSize {
        NSSize(width: controlWidth, height: DS.ControlSize.switchHeight)
    }

    override func layout() {
        super.layout()
        layoutLayers()
    }

    private func layoutLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Center track in view
        let trackX = (bounds.width - controlWidth) / 2
        let trackY = (bounds.height - controlHeight) / 2
        trackLayer.frame = CGRect(x: trackX, y: trackY, width: controlWidth, height: controlHeight)

        // Position icons at fixed locations (left, center, right)
        let segmentWidth = controlWidth / 3
        let iconOffset = (segmentWidth - iconSize) / 2

        // Position arrows at left and right edges
        downIcon.frame = CGRect(
            x: trackX + iconOffset,
            y: trackY + (controlHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        upIcon.frame = CGRect(
            x: trackX + segmentWidth * 2 + iconOffset,
            y: trackY + (controlHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        // Calculate thumb position based on state
        let thumbX: CGFloat
        switch _state {
        case .closed:
            thumbX = trackX + thumbPadding
        case .stopped:
            thumbX = trackX + (controlWidth - thumbSize) / 2
        case .open:
            thumbX = trackX + controlWidth - thumbSize - thumbPadding
        }
        let thumbY = trackY + (controlHeight - thumbSize) / 2

        let thumbFrame = CGRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)
        thumbLayer.frame = thumbFrame
        thumbShadowLayer.frame = thumbFrame
        thumbShadowLayer.backgroundColor = NSColor.white.cgColor

        // Position thumb icon centered on thumb
        thumbIcon.frame = CGRect(
            x: thumbX + (thumbSize - iconSize) / 2,
            y: thumbY + (thumbSize - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        CATransaction.commit()

        updateIconColors()
        updateThumbIcon()
    }

    // MARK: - Appearance

    private func updateColors() {
        let appearance = effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            // Blue background matching blind slider
            trackLayer.backgroundColor = DS.Colors.sliderFan.cgColor
            thumbLayer.backgroundColor = NSColor.white.cgColor
        }
        updateIconColors()
    }

    private func updateIconColors() {
        // Icons under thumb are hidden, others show in contrasting color
        let appearance = effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            // All icons white to contrast with green track
            downIcon.contentTintColor = _state == .closed ? .clear : .white
            upIcon.contentTintColor = _state == .open ? .clear : .white
        }
    }

    private func updateThumbIcon() {
        // Set thumb icon to match current state, inverted color (dark on white thumb), dimmed
        // When stopped (middle), hide the icon
        if _state == .stopped {
            thumbIcon.isHidden = true
            return
        }

        thumbIcon.isHidden = false
        let symbolName = _state == .closed ? "arrow.down" : "arrow.up"

        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            thumbIcon.image = image
        }
        thumbIcon.contentTintColor = NSColor.black.withAlphaComponent(0.5)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    // MARK: - Animation

    private func animateThumb() {
        let trackX = (bounds.width - controlWidth) / 2
        let trackY = (bounds.height - controlHeight) / 2

        let thumbX: CGFloat
        switch _state {
        case .closed:
            thumbX = trackX + thumbPadding
        case .stopped:
            thumbX = trackX + (controlWidth - thumbSize) / 2
        case .open:
            thumbX = trackX + controlWidth - thumbSize - thumbPadding
        }
        let thumbY = trackY + (controlHeight - thumbSize) / 2
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
        CATransaction.commit()

        // Animate thumb icon position
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            thumbIcon.frame = CGRect(
                x: thumbFrame.minX + (thumbSize - iconSize) / 2,
                y: thumbFrame.minY + (thumbSize - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
        }

        updateIconColors()
        updateThumbIcon()
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
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        let location = convert(event.locationInWindow, from: nil)
        let trackX = (bounds.width - controlWidth) / 2
        let relativeX = location.x - trackX

        // Determine which third was clicked
        let thirdWidth = controlWidth / 3
        let newState: CoverState
        let action: Int

        if relativeX < thirdWidth {
            // Left third - close
            newState = .closed
            action = 2  // close action
        } else if relativeX < thirdWidth * 2 {
            // Middle third - stop
            newState = .stopped
            action = 1  // stop action
        } else {
            // Right third - open
            newState = .open
            action = 0  // open action
        }

        coverState = newState
        onAction?(action)
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .slider }
    override func accessibilityValue() -> Any? { _state.rawValue }
}
