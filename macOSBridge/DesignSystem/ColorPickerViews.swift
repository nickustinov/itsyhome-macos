//
//  ColorPickerViews.swift
//  macOSBridge
//
//  Reusable color picker views for light controls
//

import AppKit

// MARK: - Clickable color circle

final class ClickableColorCircleView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func mouseUp(with event: NSEvent) {}
}

// MARK: - Rectangular hue/saturation picker (RGB)

class ColorWheelPickerView: NSView {
    private var hue: Double
    private var saturation: Double
    private let onColorChanged: (Double, Double, Bool) -> Void
    private let pickerWidth: CGFloat = 200
    private let pickerHeight: CGFloat = 32
    private let padding: CGFloat = 8
    private var cachedGradient: CGImage?

    init(hue: Double, saturation: Double, onColorChanged: @escaping (Double, Double, Bool) -> Void) {
        self.hue = hue
        self.saturation = saturation
        self.onColorChanged = onColorChanged
        super.init(frame: NSRect(x: 0, y: 0, width: pickerWidth + padding * 2, height: pickerHeight + padding * 2))
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateColor(hue: Double, saturation: Double) {
        self.hue = hue
        self.saturation = saturation
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: pickerWidth + padding * 2, height: pickerHeight + padding * 2)
    }

    private func createGradientImage() -> CGImage? {
        let width = Int(pickerWidth)
        let height = Int(pickerHeight)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let sat = CGFloat(y) / CGFloat(height - 1)  // 0 at bottom, 1 at top
            for x in 0..<width {
                let hueVal = CGFloat(x) / CGFloat(width - 1)
                let color = NSColor(hue: hueVal, saturation: sat, brightness: 1.0, alpha: 1.0)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
                let idx = ((height - 1 - y) * width + x) * 4  // Flip Y for correct orientation
                pixels[idx] = UInt8(r * 255)
                pixels[idx + 1] = UInt8(g * 255)
                pixels[idx + 2] = UInt8(b * 255)
                pixels[idx + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return context.makeImage()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = NSRect(x: padding, y: padding, width: pickerWidth, height: pickerHeight)

        // Draw gradient
        if cachedGradient == nil {
            cachedGradient = createGradientImage()
        }
        if let gradient = cachedGradient, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.addClip()
            context.draw(gradient, in: rect)
            context.restoreGState()
        }

        // Draw border
        NSColor.black.withAlphaComponent(0.2).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        border.lineWidth = 1
        border.stroke()

        // Draw indicator
        let indicatorX = padding + CGFloat(hue / 360.0) * pickerWidth
        let indicatorY = padding + CGFloat(saturation / 100.0) * pickerHeight
        let indicatorRect = NSRect(x: indicatorX - 5, y: indicatorY - 5, width: 10, height: 10)

        NSColor.white.setStroke()
        NSColor.black.withAlphaComponent(0.3).setFill()
        let indicator = NSBezierPath(ovalIn: indicatorRect)
        indicator.fill()
        indicator.lineWidth = 2
        indicator.stroke()
    }

    override func mouseDown(with event: NSEvent) { handleMouse(event, isFinal: false) }
    override func mouseDragged(with event: NSEvent) { handleMouse(event, isFinal: false) }
    override func mouseUp(with event: NSEvent) { handleMouse(event, isFinal: true) }

    private func handleMouse(_ event: NSEvent, isFinal: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let x = min(max(point.x - padding, 0), pickerWidth)
        let y = min(max(point.y - padding, 0), pickerHeight)

        hue = Double(x / pickerWidth) * 360.0
        saturation = Double(y / pickerHeight) * 100.0
        onColorChanged(hue, saturation, isFinal)
        needsDisplay = true
    }
}

// MARK: - Color temperature picker (continuous gradient slider)

class ColorTempPickerView: NSView {
    private let onTempChanged: (Double) -> Void
    private var currentMired: Double
    private let minMired: Double
    private let maxMired: Double
    private let pickerWidth: CGFloat = 200
    private let pickerHeight: CGFloat = 32
    private let padding: CGFloat = 8
    private var cachedGradient: CGImage?

    init(currentMired: Double, minMired: Double, maxMired: Double, onTempChanged: @escaping (Double) -> Void) {
        self.currentMired = currentMired
        self.minMired = minMired
        self.maxMired = maxMired
        self.onTempChanged = onTempChanged
        super.init(frame: NSRect(x: 0, y: 0, width: pickerWidth + padding * 2, height: pickerHeight + padding * 2))
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateMired(_ mired: Double) {
        currentMired = mired
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: pickerWidth + padding * 2, height: pickerHeight + padding * 2)
    }

    private func createGradientImage() -> CGImage? {
        let width = Int(pickerWidth)
        let height = Int(pickerHeight)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                // Left = warm (high mired), right = cool (low mired)
                let t = CGFloat(x) / CGFloat(width - 1)
                let mired = maxMired - t * (maxMired - minMired)
                let color = ColorConversion.miredToColor(mired)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
                let idx = ((height - 1 - y) * width + x) * 4
                pixels[idx] = UInt8(r * 255)
                pixels[idx + 1] = UInt8(g * 255)
                pixels[idx + 2] = UInt8(b * 255)
                pixels[idx + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return context.makeImage()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = NSRect(x: padding, y: padding, width: pickerWidth, height: pickerHeight)

        // Draw gradient
        if cachedGradient == nil {
            cachedGradient = createGradientImage()
        }
        if let gradient = cachedGradient, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.addClip()
            context.draw(gradient, in: rect)
            context.restoreGState()
        }

        // Draw border
        NSColor.black.withAlphaComponent(0.2).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        border.lineWidth = 1
        border.stroke()

        // Draw indicator
        let miredRange = maxMired - minMired
        let t = miredRange > 0 ? (maxMired - currentMired) / miredRange : 0.5
        let indicatorX = padding + CGFloat(t) * pickerWidth
        let indicatorY = padding + pickerHeight / 2
        let indicatorRect = NSRect(x: indicatorX - 5, y: indicatorY - 5, width: 10, height: 10)

        NSColor.white.setStroke()
        NSColor.black.withAlphaComponent(0.3).setFill()
        let indicator = NSBezierPath(ovalIn: indicatorRect)
        indicator.fill()
        indicator.lineWidth = 2
        indicator.stroke()
    }

    override func mouseDown(with event: NSEvent) { handleMouse(event, isFinal: false) }
    override func mouseDragged(with event: NSEvent) { handleMouse(event, isFinal: false) }
    override func mouseUp(with event: NSEvent) { handleMouse(event, isFinal: true) }

    private func handleMouse(_ event: NSEvent, isFinal: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let x = min(max(point.x - padding, 0), pickerWidth)
        let t = Double(x / pickerWidth)
        // Left = warm (high mired), right = cool (low mired)
        currentMired = maxMired - t * (maxMired - minMired)
        if isFinal {
            onTempChanged(currentMired)
        }
        needsDisplay = true
    }
}
