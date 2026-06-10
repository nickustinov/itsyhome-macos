//
//  HAPSetupQRCodeTests.swift
//  macOSBridgeTests
//
//  X-HM:// payload vectors computed independently (HAP spec 5.10.3 layout:
//  category << 31 | flags << 27 | code, base36-encoded to 9 chars + setup ID).
//
import XCTest
@testable import macOSBridge

final class HAPSetupQRCodeTests: XCTestCase {

    func testSetupURIEncodesKnownVectors() {
        XCTAssertEqual(HAPSetupQRCode.setupURI(setupCode: "031-45-154", setupID: "ACMN"),
                       "X-HM://0023ISYWYACMN")
        XCTAssertEqual(HAPSetupQRCode.setupURI(setupCode: "123-44-321", setupID: "ACMN"),
                       "X-HM://0023OA51DACMN")
        XCTAssertEqual(HAPSetupQRCode.setupURI(setupCode: "000-00-001", setupID: "ACMN"),
                       "X-HM://0023GXK3LACMN")
        XCTAssertEqual(HAPSetupQRCode.setupURI(setupCode: "999-99-999", setupID: "ACMN"),
                       "X-HM://00254GWLBACMN")
    }

    func testSetupURIAcceptsCodeWithoutDashes() {
        XCTAssertEqual(HAPSetupQRCode.setupURI(setupCode: "03145154", setupID: "ACMN"),
                       "X-HM://0023ISYWYACMN")
    }

    func testSetupURIRejectsMalformedCodes() {
        XCTAssertNil(HAPSetupQRCode.setupURI(setupCode: "", setupID: "ACMN"))
        XCTAssertNil(HAPSetupQRCode.setupURI(setupCode: "123-45", setupID: "ACMN"))
        XCTAssertNil(HAPSetupQRCode.setupURI(setupCode: "123-45-67890", setupID: "ACMN"))
        XCTAssertNil(HAPSetupQRCode.setupURI(setupCode: "abc-de-fgh", setupID: "ACMN"))
    }

    func testQRImageIsGenerated() {
        let image = HAPSetupQRCode.qrImage(uri: "X-HM://0023ISYWYACMN", size: 140)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width, 140)
        XCTAssertEqual(image?.size.height, 140)
    }
}
