//
//  DesignSystem.swift
//  macOSBridge
//
//  Design system inspired by shadcn/ui
//  Provides consistent styling across all menu bar controls
//

import AppKit

// MARK: - Design tokens

enum DS {

    // MARK: - Colors

    enum Colors {
        // Semantic colors that adapt to light/dark mode
        static var background: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.145, alpha: 1) : NSColor(white: 1, alpha: 1)
            }
        }

        static var foreground: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.985, alpha: 1) : NSColor(white: 0.145, alpha: 1)
            }
        }

        static var primary: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.985, alpha: 1) : NSColor(white: 0.205, alpha: 1)
            }
        }

        static var primaryForeground: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.205, alpha: 1) : NSColor(white: 0.985, alpha: 1)
            }
        }

        static var secondary: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.269, alpha: 1) : NSColor(white: 0.97, alpha: 1)
            }
        }

        static var secondaryForeground: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.985, alpha: 1) : NSColor(white: 0.205, alpha: 1)
            }
        }

        static var muted: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.269, alpha: 1) : NSColor(white: 0.85, alpha: 1)
            }
        }

        static var mutedForeground: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.708, alpha: 1) : NSColor(white: 0.556, alpha: 1)
            }
        }

        /// Icon color - same as foreground for icons in menu items
        static var iconForeground: NSColor {
            foreground
        }

        static var accent: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.269, alpha: 1) : NSColor(white: 0.97, alpha: 1)
            }
        }

        static var border: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.269, alpha: 1) : NSColor(white: 0.922, alpha: 1)
            }
        }

        static var input: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.35, alpha: 1) : NSColor(white: 0.88, alpha: 1)
            }
        }

        /// Shared color for slider tracks and toggle off state
        static var controlTrack: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.35, alpha: 1) : NSColor(white: 0.65, alpha: 1)
            }
        }

        static var ring: NSColor {
            NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(white: 0.556, alpha: 1) : NSColor(white: 0.708, alpha: 1)
            }
        }

        // Status colors
        static let success = NSColor(red: 0.22, green: 0.78, blue: 0.45, alpha: 1) // Green
        static let warning = NSColor(red: 0.95, green: 0.68, blue: 0.25, alpha: 1) // Orange
        static let destructive = NSColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1) // Red
        static let info = NSColor(red: 0.25, green: 0.60, blue: 0.95, alpha: 1) // Blue

        // Device-specific accent colors
        static let lightOn = NSColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1) // Warm yellow
        static let fanOn = NSColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1) // Cyan
        static let thermostatHeat = NSColor(red: 0.95, green: 0.50, blue: 0.25, alpha: 1) // Orange
        static let thermostatCool = NSColor(red: 0.30, green: 0.60, blue: 0.95, alpha: 1) // Blue
        static let lockLocked = NSColor(red: 0.22, green: 0.78, blue: 0.45, alpha: 1) // Green
        static let lockUnlocked = NSColor(red: 0.95, green: 0.68, blue: 0.25, alpha: 1) // Orange

        // Control colors
        static let switchOn = NSColor(red: 0.22, green: 0.78, blue: 0.45, alpha: 1) // Green

        // Slider colors by device type
        static let sliderLight = NSColor(red: 0.95, green: 0.60, blue: 0.20, alpha: 1) // Orange
        static let sliderThermostat = NSColor(red: 0.90, green: 0.45, blue: 0.15, alpha: 1) // Dark orange
        static let sliderFan = NSColor(red: 0.25, green: 0.60, blue: 0.95, alpha: 1) // Blue (info)
        static let sliderBlind = NSColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1) // Cyan (fanOn)

    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let full: CGFloat = 9999
    }

    // MARK: - Typography

    enum Typography {
        static let labelSmall = NSFont.systemFont(ofSize: 11, weight: .regular)
        static let label = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let labelMedium = NSFont.systemFont(ofSize: 13, weight: .medium)
        static let body = NSFont.systemFont(ofSize: 14, weight: .regular)
        static let bodyMedium = NSFont.systemFont(ofSize: 14, weight: .medium)
        static let headline = NSFont.systemFont(ofSize: 15, weight: .semibold)
    }

    // MARK: - Shadows

    enum Shadow {
        static func small() -> NSShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
            shadow.shadowOffset = NSSize(width: 0, height: 1)
            shadow.shadowBlurRadius = 2
            return shadow
        }

        static func medium() -> NSShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
            shadow.shadowOffset = NSSize(width: 0, height: 2)
            shadow.shadowBlurRadius = 4
            return shadow
        }
    }

    // MARK: - Animation

    enum Animation {
        static let fast: CFTimeInterval = 0.15
        static let normal: CFTimeInterval = 0.25
        static let slow: CFTimeInterval = 0.35

        static let springDamping: CGFloat = 0.7
        static let springVelocity: CGFloat = 0.5
    }

    // MARK: - Control sizes

    enum ControlSize {
        // Toggle switch (compact size)
        static let switchWidth: CGFloat = 28
        static let switchHeight: CGFloat = 16
        static let switchThumbSize: CGFloat = 12
        static let switchThumbPadding: CGFloat = 2

        // Slider
        static let sliderTrackHeight: CGFloat = 6
        static let sliderThumbSize: CGFloat = 12
        static let sliderWidth: CGFloat = 60

        // Icon
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 14
        static let iconLarge: CGFloat = 22

        // Menu item
        static let menuItemHeight: CGFloat = 28
        static let menuItemHeightLarge: CGFloat = 52
        static let menuItemWidth: CGFloat = 260
    }
}

// MARK: - Stepper Button

/// A small +/- button for temperature steppers. Creates a borderless button
/// with a subtle background, matching the style used in temperature controls.
enum StepperButton {
    enum Size {
        case regular  // 20x20
        case small    // 16x16
        case mini     // 11x11
    }

    static func create(title: String, size: Size = .regular) -> NSButton {
        let dimension: CGFloat
        let cornerRadius: CGFloat
        let fontSize: CGFloat
        switch size {
        case .regular:
            dimension = 20
            cornerRadius = 4
            fontSize = 12
        case .small:
            dimension = 16
            cornerRadius = 3
            fontSize = 10
        case .mini:
            dimension = 11
            cornerRadius = 2
            fontSize = 8
        }
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: dimension, height: dimension))

        button.isBordered = false
        button.wantsLayer = true

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bgAlpha: CGFloat = isDark ? 0.2 : 0.08
        button.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(bgAlpha).cgColor
        button.layer?.cornerRadius = cornerRadius

        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)

        if isDark {
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: NSColor.white,
                .font: font
            ])
        } else {
            button.title = title
            button.font = font
            button.contentTintColor = .secondaryLabelColor
        }

        return button
    }
}

// MARK: - NSAppearance extension

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - NSColor convenience

extension NSColor {
    func resolvedColor(for appearance: NSAppearance? = nil) -> NSColor {
        let appearance = appearance ?? NSAppearance.current ?? NSApp.effectiveAppearance
        var resolved = self
        appearance.performAsCurrentDrawingAppearance {
            resolved = self.usingColorSpace(.deviceRGB) ?? self
        }
        return resolved
    }

    var cgColorResolved: CGColor {
        resolvedColor().cgColor
    }
}
