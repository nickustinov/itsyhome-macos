//
//  HAURLValidator.swift
//  Itsyhome
//
//  Validates and normalises user-entered Home Assistant server URLs
//

import Foundation

enum HAURLValidator {

    enum Result {
        case success(URL)
        case failure(String)
    }

    /// Validate and normalise a raw user-entered server URL string.
    ///
    /// - Trims whitespace
    /// - Auto-prepends a scheme when none is present:
    ///   `http://` for local addresses, `https://` for remote
    /// - Strips trailing slashes
    /// - Validates the URL is parseable and has a host
    static func validate(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure("Please enter a server URL")
        }

        // Auto-prepend scheme when none is present
        let urlString: String
        if !trimmed.contains("://") {
            let scheme = isLocalAddress(trimmed) ? "http" : "https"
            urlString = "\(scheme)://\(trimmed)"
        } else {
            urlString = trimmed
        }

        // Strip trailing slashes
        let cleaned = urlString.hasSuffix("/")
            ? String(urlString.dropLast())
            : urlString

        guard let url = URL(string: cleaned), url.host != nil, !url.host!.isEmpty else {
            return .failure("Invalid server URL")
        }

        // Only allow http(s) and ws(s) schemes
        let allowedSchemes = ["http", "https", "ws", "wss"]
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else {
            return .failure("URL scheme must be http, https, ws, or wss")
        }

        return .success(url)
    }

    /// Whether a bare hostname (no scheme) looks like a local network address.
    ///
    /// Matches: `localhost`, `.local` mDNS names, private IPv4 ranges
    /// (10.x, 172.16–31.x, 192.168.x), and IPv6 link-local (fe80::).
    private static func isLocalAddress(_ input: String) -> Bool {
        // Strip port if present (take everything before the last colon
        // that isn't part of an IPv6 address)
        let host: String
        if input.contains("[") {
            // IPv6 bracket notation, e.g. [::1]:8123
            host = String(input.prefix(while: { $0 != "]" }).dropFirst())
        } else if let colonRange = input.range(of: ":", options: .backwards),
                  !input[input.startIndex..<colonRange.lowerBound].contains(":") {
            // Single colon → host:port
            host = String(input[input.startIndex..<colonRange.lowerBound])
        } else {
            host = input
        }

        let lower = host.lowercased()

        // localhost / loopback
        if lower == "localhost" || host == "127.0.0.1" || host == "::1" {
            return true
        }

        // mDNS .local domains
        if lower.hasSuffix(".local") {
            return true
        }

        // Private IPv4 ranges
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            if parts[0] == 10 { return true }                              // 10.0.0.0/8
            if parts[0] == 172 && (16...31).contains(parts[1]) { return true } // 172.16.0.0/12
            if parts[0] == 192 && parts[1] == 168 { return true }         // 192.168.0.0/16
        }

        // IPv6 link-local
        if lower.hasPrefix("fe80:") {
            return true
        }

        return false
    }
}
