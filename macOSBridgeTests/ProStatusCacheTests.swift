//
//  ProStatusCacheTests.swift
//  macOSBridgeTests
//
//  Tests for ProStatusCache
//

import Combine
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

        // concurrentPerform is synchronous — verifies no crashes from concurrent access
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 2 == 0 {
                cache.isPro = true
            } else {
                _ = cache.isPro
            }
        }
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

    // MARK: - Effective status on Pro changes

    func testEffectiveStatusIsReadFromTheCacheNotThePublishedEntitlement() {
        // A Debug build with debugOverride: ProManager publishes the App Store
        // entitlement (false) while the effective status is Pro.
        let received = expectation(description: "status received")
        var status: Bool?
        let subscription = ProStatusCache.effectiveStatus(on: Just(false), isPro: { true })
            .sink {
                status = $0
                received.fulfill()
            }
        wait(for: [received], timeout: 1)
        XCTAssertEqual(status, true)
        subscription.cancel()
    }

    func testEffectiveStatusArrivesOnTheMainQueue() {
        let received = expectation(description: "status received")
        let subscription = ProStatusCache.effectiveStatus(on: Just(true).subscribe(on: DispatchQueue.global()),
                                                          isPro: { true })
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
                received.fulfill()
            }
        wait(for: [received], timeout: 1)
        subscription.cancel()
    }
}
