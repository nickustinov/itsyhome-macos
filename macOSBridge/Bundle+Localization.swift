import Foundation

private class _BundleToken {}

extension Bundle {
    static let macOSBridge = Bundle(for: _BundleToken.self)
}
