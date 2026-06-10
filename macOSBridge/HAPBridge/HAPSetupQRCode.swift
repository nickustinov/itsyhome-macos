//
//  HAPSetupQRCode.swift
//  macOSBridge
//
//  Builds the X-HM:// setup payload Apple Home scans to pair an accessory
//  (HAP spec 5.10.3): a 45-bit value - category << 31 | transport flags << 27 |
//  numeric setup code - base36-encoded to 9 characters, followed by the 4-char
//  setup ID the advertiser hashes into the mDNS "sh" record.
//
import AppKit
import CoreImage

enum HAPSetupQRCode {

    /// HAP accessory category: bridge.
    private static let bridgeCategory: UInt64 = 2
    /// Transport flag: HAP over IP.
    private static let ipTransportFlag: UInt64 = 2

    /// The scannable pairing URI for a setup code like "031-45-154".
    /// Returns nil if the code does not contain exactly 8 digits.
    static func setupURI(setupCode: String, setupID: String) -> String? {
        let digits = setupCode.filter(\.isNumber)
        guard digits.count == 8, setupCode.allSatisfy({ $0.isNumber || $0 == "-" }),
              let code = UInt64(digits) else { return nil }
        let payload = bridgeCategory << 31 | ipTransportFlag << 27 | code
        return "X-HM://" + base36(payload, width: 9) + setupID
    }

    /// Renders the URI as a crisp (nearest-neighbour upscaled) QR code.
    static func qrImage(uri: String, size: CGFloat) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(uri.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    private static func base36(_ value: UInt64, width: Int) -> String {
        let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var value = value
        var result = ""
        while value > 0 {
            result = String(digits[Int(value % 36)]) + result
            value /= 36
        }
        return String(repeating: "0", count: max(0, width - result.count)) + result
    }
}
