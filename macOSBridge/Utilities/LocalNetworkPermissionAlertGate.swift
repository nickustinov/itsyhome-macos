//
//  LocalNetworkPermissionAlertGate.swift
//  macOSBridge
//

import Foundation
import Network

/// Tracks continuous denial episodes. Call updates and resets on the main queue.
final class LocalNetworkPermissionAlertGate {
    private let gracePeriod: TimeInterval
    private var episodeID: UUID?
    private var pendingConfirmation: DispatchWorkItem?

    init(gracePeriod: TimeInterval = 5) {
        self.gracePeriod = gracePeriod
    }

    func update(status: NWPath.Status, reason: NWPath.UnsatisfiedReason, onConfirmedDenial: @escaping () -> Void) {
        guard status == .unsatisfied, reason == .localNetworkDenied else {
            reset()
            return
        }
        // Repeated reports must neither postpone confirmation nor alert twice.
        guard episodeID == nil else { return }
        let id = UUID()
        episodeID = id
        let confirmation = DispatchWorkItem { [weak self] in
            guard let self, self.episodeID == id else { return }
            self.pendingConfirmation = nil
            onConfirmedDenial()
        }
        pendingConfirmation = confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + gracePeriod, execute: confirmation)
    }

    func reset() {
        pendingConfirmation?.cancel()
        pendingConfirmation = nil
        episodeID = nil
    }

    deinit {
        pendingConfirmation?.cancel()
    }
}
