//
//  WebRTCSDPReorder.swift
//  Itsyhome
//
//  Ensures SDP m-line order matches Nest camera requirements:
//  audio → video → application (data channel).
//

import Foundation

/// Ensures the SDP m-line order is audio → video → application (data channel).
/// Nest cameras require this specific order. Returns the SDP unchanged if any of
/// the three sections are missing.
func ensureNestSDPOrder(_ sdp: String) -> String {
    // Split SDP into sections at each m= line
    let lines = sdp.components(separatedBy: "\r\n")
    var sections: [(type: String, lines: [String])] = []
    var currentLines: [String] = []
    var currentType = "header"

    for line in lines {
        if line.hasPrefix("m=") {
            sections.append((type: currentType, lines: currentLines))
            currentLines = [line]
            currentType = String(line.dropFirst(2).prefix(while: { $0 != " " }))
        } else {
            currentLines.append(line)
        }
    }
    sections.append((type: currentType, lines: currentLines))

    // Extract header (everything before first m=) and media sections
    guard let headerIndex = sections.firstIndex(where: { $0.type == "header" }) else { return sdp }
    let header = sections[headerIndex]
    let mediaSections = sections.filter { $0.type != "header" }

    // Only reorder if we have all three expected sections
    let types = mediaSections.map(\.type)
    guard types.contains("audio") && types.contains("video") && types.contains("application") else {
        return sdp
    }

    // Already in correct order
    if let ai = types.firstIndex(of: "audio"),
       let vi = types.firstIndex(of: "video"),
       let di = types.firstIndex(of: "application"),
       ai < vi && vi < di {
        return sdp
    }

    // Reorder: audio → video → application, preserving any other sections at the end
    let desiredOrder = ["audio", "video", "application"]
    var ordered: [(type: String, lines: [String])] = []
    for type in desiredOrder {
        if let section = mediaSections.first(where: { $0.type == type }) {
            ordered.append(section)
        }
    }
    for section in mediaSections where !desiredOrder.contains(section.type) {
        ordered.append(section)
    }

    let allLines = header.lines + ordered.flatMap(\.lines)
    return allLines.joined(separator: "\r\n")
}
