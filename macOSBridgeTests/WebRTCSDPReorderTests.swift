//
//  WebRTCSDPReorderTests.swift
//  macOSBridgeTests
//

import XCTest

final class WebRTCSDPReorderTests: XCTestCase {

    // MARK: - Test helpers

    private func makeSDP(header: String = "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0",
                         sections: [(type: String, content: String)]) -> String {
        var sdp = header
        for section in sections {
            sdp += "\r\n" + section.content
        }
        return sdp
    }

    private let audioSection = """
    m=audio 9 UDP/TLS/RTP/SAVPF 111\r\nc=IN IP4 0.0.0.0\r\na=rtpmap:111 opus/48000/2
    """

    private let videoSection = """
    m=video 9 UDP/TLS/RTP/SAVPF 96\r\nc=IN IP4 0.0.0.0\r\na=rtpmap:96 VP8/90000
    """

    private let applicationSection = """
    m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\nc=IN IP4 0.0.0.0\r\na=sctp-port:5000
    """

    private let header = "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0"

    // MARK: - Tests

    func testCorrectOrderUnchanged() {
        let sdp = header + "\r\n" + audioSection + "\r\n" + videoSection + "\r\n" + applicationSection
        let result = ensureNestSDPOrder(sdp)
        XCTAssertEqual(result, sdp)
    }

    func testVideoAudioApplicationReordered() {
        let sdp = header + "\r\n" + videoSection + "\r\n" + audioSection + "\r\n" + applicationSection
        let result = ensureNestSDPOrder(sdp)

        let lines = result.components(separatedBy: "\r\n")
        let mLines = lines.filter { $0.hasPrefix("m=") }
        XCTAssertEqual(mLines.count, 3)
        XCTAssertTrue(mLines[0].hasPrefix("m=audio"))
        XCTAssertTrue(mLines[1].hasPrefix("m=video"))
        XCTAssertTrue(mLines[2].hasPrefix("m=application"))
    }

    func testApplicationVideoAudioReordered() {
        let sdp = header + "\r\n" + applicationSection + "\r\n" + videoSection + "\r\n" + audioSection
        let result = ensureNestSDPOrder(sdp)

        let lines = result.components(separatedBy: "\r\n")
        let mLines = lines.filter { $0.hasPrefix("m=") }
        XCTAssertEqual(mLines.count, 3)
        XCTAssertTrue(mLines[0].hasPrefix("m=audio"))
        XCTAssertTrue(mLines[1].hasPrefix("m=video"))
        XCTAssertTrue(mLines[2].hasPrefix("m=application"))
    }

    func testMissingSectionLeftAlone() {
        // Only audio and video – no application section
        let sdp = header + "\r\n" + videoSection + "\r\n" + audioSection
        let result = ensureNestSDPOrder(sdp)
        XCTAssertEqual(result, sdp, "SDP without all three sections should be unchanged")
    }

    func testAudioOnlyLeftAlone() {
        let sdp = header + "\r\n" + audioSection
        let result = ensureNestSDPOrder(sdp)
        XCTAssertEqual(result, sdp)
    }

    func testContentPreservedAfterReorder() {
        let sdp = header + "\r\n" + videoSection + "\r\n" + audioSection + "\r\n" + applicationSection
        let result = ensureNestSDPOrder(sdp)

        // All original content should still be present
        XCTAssertTrue(result.contains("m=audio 9 UDP/TLS/RTP/SAVPF 111"))
        XCTAssertTrue(result.contains("a=rtpmap:111 opus/48000/2"))
        XCTAssertTrue(result.contains("m=video 9 UDP/TLS/RTP/SAVPF 96"))
        XCTAssertTrue(result.contains("a=rtpmap:96 VP8/90000"))
        XCTAssertTrue(result.contains("m=application 9 UDP/DTLS/SCTP webrtc-datachannel"))
        XCTAssertTrue(result.contains("a=sctp-port:5000"))
        XCTAssertTrue(result.contains("v=0"))
    }

    func testHeaderPreserved() {
        let sdp = header + "\r\n" + videoSection + "\r\n" + audioSection + "\r\n" + applicationSection
        let result = ensureNestSDPOrder(sdp)
        XCTAssertTrue(result.hasPrefix("v=0\r\no=- 0 0 IN IP4 127.0.0.1"))
    }
}
