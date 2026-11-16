//
//  ProRecheck.swift
//  macOSBridge
//
//  Follow-up entitlement checks after a check found no Pro
//

/// At login StoreKit's local transaction cache can still be empty, and
/// `Transaction.updates` only fires for new or changed transactions – so one
/// empty check at launch left a Pro user on the free tier until they pressed
/// Restore (#182).
enum ProRecheck {

    /// After launch: soon, then after a minute, then after five more.
    static let delays: [Duration] = [.seconds(10), .seconds(60), .seconds(300)]

    /// Runs `check` after each delay until it finds Pro. Stops straight away
    /// if the waiting task is cancelled.
    static func run(
        delays: [Duration] = delays,
        sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        check: () async -> Bool
    ) async {
        for delay in delays {
            do {
                try await sleep(delay)
            } catch {
                return
            }
            if await check() { return }
        }
    }
}
