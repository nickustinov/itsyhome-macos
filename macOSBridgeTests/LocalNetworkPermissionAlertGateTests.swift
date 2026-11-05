//
//  LocalNetworkPermissionAlertGateTests.swift
//  macOSBridgeTests
//

import Network
import XCTest
@testable import macOSBridge

final class LocalNetworkPermissionAlertGateTests: XCTestCase {

    func testRecoveryOfflineAndRequiresConnectionCancelConfirmation() {
        let gate = LocalNetworkPermissionAlertGate(gracePeriod: 0.05)
        for (status, reason) in [(NWPath.Status.satisfied, NWPath.UnsatisfiedReason.notAvailable),
                                 (.unsatisfied, .notAvailable),
                                 (.requiresConnection, .localNetworkDenied)] {
            let alert = expectation(description: "No alert after denial ends with \(status), \(reason)")
            alert.isInverted = true
            gate.update(status: .unsatisfied, reason: .localNetworkDenied) { alert.fulfill() }
            gate.update(status: status, reason: reason) { alert.fulfill() }
            wait(for: [alert], timeout: 0.2)
        }
        withExtendedLifetime(gate) {}
    }

    func testPersistentDenialAlertsOnceWithoutPostponingAndCanAlertAfterRecovery() {
        let gate = LocalNetworkPermissionAlertGate(gracePeriod: 0.1)
        var alertCount = 0
        let confirmed = expectation(description: "Persistent denial confirmed")
        let repeatedReportsFinished = expectation(description: "Repeated reports finished")
        let notify = {
            alertCount += 1
            confirmed.fulfill()
        }

        gate.update(status: .unsatisfied, reason: .localNetworkDenied, onConfirmedDenial: notify)
        XCTAssertEqual(alertCount, 0)
        for delay in [0.05, 0.1, 0.15, 0.2, 0.25, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                gate.update(status: .unsatisfied, reason: .localNetworkDenied, onConfirmedDenial: notify)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(alertCount, 1, "Repeated reports must not postpone confirmation")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(alertCount, 1)
            repeatedReportsFinished.fulfill()
        }
        wait(for: [confirmed, repeatedReportsFinished], timeout: 1)

        gate.update(status: .satisfied, reason: .notAvailable, onConfirmedDenial: notify)
        let newEpisode = expectation(description: "Denial after recovery confirmed")
        gate.update(status: .unsatisfied, reason: .localNetworkDenied) { newEpisode.fulfill() }
        wait(for: [newEpisode], timeout: 1)
    }

    func testResetCancelsObsoleteConfirmationDuringNewEpisode() {
        let gate = LocalNetworkPermissionAlertGate(gracePeriod: 0.05)
        let obsoleteAlert = expectation(description: "Obsolete episode stays cancelled")
        obsoleteAlert.isInverted = true
        let newAlert = expectation(description: "New episode confirmed")

        gate.update(status: .unsatisfied, reason: .localNetworkDenied) { obsoleteAlert.fulfill() }
        gate.reset()
        gate.update(status: .unsatisfied, reason: .localNetworkDenied) { newAlert.fulfill() }

        wait(for: [obsoleteAlert, newAlert], timeout: 0.2)
    }

    func testReleasingGateCancelsConfirmation() {
        var gate: LocalNetworkPermissionAlertGate? = LocalNetworkPermissionAlertGate(gracePeriod: 0.05)
        weak var releasedGate = gate
        let alert = expectation(description: "Released gate cannot alert")
        alert.isInverted = true

        gate?.update(status: .unsatisfied, reason: .localNetworkDenied) { alert.fulfill() }
        gate = nil

        XCTAssertNil(releasedGate)
        wait(for: [alert], timeout: 0.2)
    }
}
