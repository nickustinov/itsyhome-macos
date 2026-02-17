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
    /// - Auto-prepends `http://` when no scheme is present
    /// - Strips trailing slashes
    /// - Validates the URL is parseable and has a host
    static func validate(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure("Please enter a server URL")
        }

        // Auto-prepend http:// when no scheme is present
        let urlString: String
        if !trimmed.contains("://") {
            urlString = "http://\(trimmed)"
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
}
