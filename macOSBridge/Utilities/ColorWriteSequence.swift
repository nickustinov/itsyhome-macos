//
//  ColorWriteSequence.swift
//  macOSBridge
//
//  Shared write order for hue/saturation colour changes
//

import Foundation

/// Every hue/saturation colour change goes out saturation first, then hue
/// `hueDelay` later. The delay (added in 2.4.1) keeps the two writes from being
/// simultaneous, which made Philips Hue bulbs land on the wrong colour. Hue goes
/// LAST so that on Govee/Matter bridges, where a later write overrides an
/// earlier one, the hue value is the one that sticks and colour changes apply
/// instead of only saturation moving (#127).
enum ColorWriteSequence {
    static let hueDelay: TimeInterval = 0.15

    static func run(writeSaturation: () -> Void, writeHue: @escaping () -> Void) {
        writeSaturation()
        DispatchQueue.main.asyncAfter(deadline: .now() + hueDelay, execute: writeHue)
    }
}
