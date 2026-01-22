//
//  ValueConversionTests.swift
//  macOSBridgeTests
//
//  Tests for value conversion utilities
//

import XCTest
@testable import macOSBridge

final class ValueConversionTests: XCTestCase {

    // MARK: - toDouble tests

    func testToDoubleFromDouble() {
        XCTAssertEqual(ValueConversion.toDouble(42.5), 42.5)
        XCTAssertEqual(ValueConversion.toDouble(0.0), 0.0)
        XCTAssertEqual(ValueConversion.toDouble(-10.5), -10.5)
    }

    func testToDoubleFromInt() {
        XCTAssertEqual(ValueConversion.toDouble(42), 42.0)
        XCTAssertEqual(ValueConversion.toDouble(0), 0.0)
        XCTAssertEqual(ValueConversion.toDouble(-10), -10.0)
    }

    func testToDoubleFromFloat() {
        let result1 = ValueConversion.toDouble(Float(42.5))
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1!, 42.5, accuracy: 0.001)

        let result2 = ValueConversion.toDouble(Float(0.0))
        XCTAssertEqual(result2, 0.0)
    }

    func testToDoubleFromBool() {
        XCTAssertEqual(ValueConversion.toDouble(true), 1.0)
        XCTAssertEqual(ValueConversion.toDouble(false), 0.0)
    }

    func testToDoubleFromNSNumber() {
        XCTAssertEqual(ValueConversion.toDouble(NSNumber(value: 42.5)), 42.5)
        XCTAssertEqual(ValueConversion.toDouble(NSNumber(value: 100)), 100.0)
    }

    func testToDoubleFromInvalidTypeReturnsNil() {
        XCTAssertNil(ValueConversion.toDouble("not a number"))
        XCTAssertNil(ValueConversion.toDouble([1, 2, 3]))
        XCTAssertNil(ValueConversion.toDouble(["key": "value"]))
    }

    func testToDoubleWithDefault() {
        XCTAssertEqual(ValueConversion.toDouble(42.5, default: 0.0), 42.5)
        XCTAssertEqual(ValueConversion.toDouble("invalid", default: 99.0), 99.0)
    }

    // MARK: - toInt tests

    func testToIntFromInt() {
        XCTAssertEqual(ValueConversion.toInt(42), 42)
        XCTAssertEqual(ValueConversion.toInt(0), 0)
        XCTAssertEqual(ValueConversion.toInt(-10), -10)
    }

    func testToIntFromDouble() {
        XCTAssertEqual(ValueConversion.toInt(42.9), 42)
        XCTAssertEqual(ValueConversion.toInt(42.1), 42)
    }

    func testToIntFromBool() {
        XCTAssertEqual(ValueConversion.toInt(true), 1)
        XCTAssertEqual(ValueConversion.toInt(false), 0)
    }

    func testToIntFromInvalidTypeReturnsNil() {
        XCTAssertNil(ValueConversion.toInt("not a number"))
    }

    // MARK: - toBool tests

    func testToBoolFromBool() {
        XCTAssertEqual(ValueConversion.toBool(true), true)
        XCTAssertEqual(ValueConversion.toBool(false), false)
    }

    func testToBoolFromInt() {
        XCTAssertEqual(ValueConversion.toBool(1), true)
        XCTAssertEqual(ValueConversion.toBool(0), false)
        XCTAssertEqual(ValueConversion.toBool(42), true)  // Non-zero is true
    }

    func testToBoolFromInvalidTypeReturnsNil() {
        XCTAssertNil(ValueConversion.toBool("true"))
        XCTAssertNil(ValueConversion.toBool(1.5))
    }
}
