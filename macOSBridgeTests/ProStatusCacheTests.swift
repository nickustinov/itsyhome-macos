//
//  ProStatusCacheTests.swift
//  macOSBridgeTests
//
//  Tests for ProStatusCache
//

import XCTest
@testable import macOSBridge

final class ProStatusCacheTests: XCTestCase {

    // MARK: - Singleton tests

    func testSharedInstanceExists() {
        XCTAssertNotNil(ProStatusCache.shared)
    }

    func testSharedInstanceIsSingleton() {
        let instance1 = ProStatusCache.shared
        let instance2 = ProStatusCache.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - isPro property tests

    func testIsProCanBeSet() {
        let cache = ProStatusCache.shared
        let originalValue = cache.isPro

        // Set to opposite value
        cache.isPro = !originalValue

        // When debug override is enabled, isPro always returns true
        if ProStatusCache.debugOverride {
            XCTAssertTrue(cache.isPro)
        } else {
            XCTAssertEqual(cache.isPro, !originalValue)
        }

        // Restore original value
        cache.isPro = originalValue
    }

    func testIsProThreadSafety() {
        let cache = ProStatusCache.shared
        let iterations = 1000
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = iterations * 2

        // Concurrent reads and writes
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 2 == 0 {
                cache.isPro = true
                expectation.fulfill()
            } else {
                _ = cache.isPro
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Debug override tests

    func testDebugOverrideIsStatic() {
        // Just verify debug override is accessible
        _ = ProStatusCache.debugOverride
    }

    func testIsProReturnsCorrectValueBasedOnDebugOverride() {
        let cache = ProStatusCache.shared

        if ProStatusCache.debugOverride {
            // When debug override is true, isPro should always return true
            cache.isPro = false
            XCTAssertTrue(cache.isPro)
        }
        // Note: We can't test the false case without changing the static constant
    }
}
