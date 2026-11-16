//
//  ProManager.swift
//  macOSBridge
//
//  Manages Itsyhome Pro purchases using StoreKit 2
//

import Combine
import OSLog
import StoreKit

/// Notice level, so entitlement checks stay in the system log of a release build.
private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "Pro")

@MainActor
final class ProManager: ObservableObject {

    static let shared = ProManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false {
        didSet {
            ProStatusCache.shared.isPro = isPro
        }
    }
    @Published private(set) var isLoading: Bool = false

    private var transactionListener: Task<Void, Error>?
    private var recheckTask: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            // Entitlements first: the check works offline from the local cache
            // and starts the Pro features, while the product fetch needs the
            // network and can take seconds at login.
            await updateProStatus()
            recheckUntilPro()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    var lifetimeProduct: Product? {
        products.first { $0.id == ProProducts.lifetime }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProProducts.all)
                .sorted { $0.price < $1.price }
        } catch {
            print("[ProManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer {
            isLoading = false
            CatalystWindowGate.allowOrdering = false
            CatalystWindowGate.hideCatalystWindow()
        }

        // Allow the hidden Catalyst window to order front so StoreKit
        // has a presentation context for the purchase sheet.
        CatalystWindowGate.allowOrdering = true
        CatalystWindowGate.orderCatalystWindow()
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateProStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        isLoading = true
        defer {
            isLoading = false
            CatalystWindowGate.allowOrdering = false
            CatalystWindowGate.hideCatalystWindow()
        }

        CatalystWindowGate.allowOrdering = true
        CatalystWindowGate.orderCatalystWindow()
        try? await AppStore.sync()
        await updateProStatus()
    }

    // MARK: - Entitlement check

    @discardableResult
    func updateProStatus() async -> Bool {
        var hasProEntitlement = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if ProProducts.all.contains(transaction.productID) {
                    hasProEntitlement = true
                    break
                }
            }
        }

        // currentEntitlements can come back empty for a valid purchase;
        // latest(for:) looks up the product's own transaction instead.
        var foundByLatest = false
        if !hasProEntitlement {
            for productID in ProProducts.all {
                if case .verified(let transaction) = await Transaction.latest(for: productID),
                   transaction.revocationDate == nil {
                    hasProEntitlement = true
                    foundByLatest = true
                    break
                }
            }
        }

        logger.notice("Entitlement check: Pro \(hasProEntitlement ? "found" : "not found", privacy: .public)\(foundByLatest ? " (latest(for:) fallback)" : "", privacy: .public)")

        // Publish changes only: Settings rebuilds its Pro sections on every
        // value, and rechecks of a free copy would otherwise redraw it.
        if isPro != hasProEntitlement {
            isPro = hasProEntitlement
        }

        // Start or stop Pro features based on status
        if hasProEntitlement {
            CloudSyncManager.shared.startListening()
            WebhookServer.shared.startIfEnabled()
            VirtualBridgeService.shared.startIfEnabled()
            AutomationEngine.shared.startIfEnabled()
        } else {
            CloudSyncManager.shared.stopListening()
            WebhookServer.shared.stop()
            Task { await VirtualBridgeService.shared.stop() }
            AutomationEngine.shared.stop()
            HistoryStore.shared.flush()
        }
        return hasProEntitlement
    }

    // MARK: - Rechecks (#182)

    /// Checks again on the `ProRecheck` schedule while no Pro was found.
    private func recheckUntilPro() {
        guard !isPro, recheckTask == nil else { return }
        recheckTask = Task {
            await ProRecheck.run { await self.updateProStatus() }
            recheckTask = nil
        }
    }

    /// For unlock, wake and network return: StoreKit may have caught up with
    /// the App Store since the last check.
    func recheckIfNotPro() {
        guard !isPro else { return }
        Task { await updateProStatus() }
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updateProStatus()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

/// Thread-safe cache for Pro status, accessible from any thread
final class ProStatusCache: @unchecked Sendable {
    static let shared = ProStatusCache()

    // Local testing switches, honoured only in Debug builds – a Release archive
    // always keeps the paywall, even if one is left on. debugOverride forces Pro
    // (debug builds can't see the App Store purchase); debugForceNotPro previews
    // the non-Pro state (e.g. Pro badges).
    static let debugOverride = false
    static let debugForceNotPro = false

    private let lock = NSLock()
    private var _isPro: Bool = false

    var isPro: Bool {
        get {
            #if DEBUG
            if Self.debugForceNotPro { return false }
            if Self.debugOverride { return true }
            #endif
            lock.lock()
            defer { lock.unlock() }
            return _isPro
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isPro = newValue
        }
    }

    private init() {}

    /// The effective Pro status, read on the main queue each time `changes` fires.
    /// ProManager publishes the App Store entitlement, which a Debug build's
    /// `debugOverride` leaves false – a subscriber that uses the status itself,
    /// not only as a cue to refresh, must take it from here.
    static func effectiveStatus<Changes: Publisher>(
        on changes: Changes,
        isPro: @escaping () -> Bool = { ProStatusCache.shared.isPro }
    ) -> AnyPublisher<Bool, Never> where Changes.Output == Bool, Changes.Failure == Never {
        changes
            .receive(on: DispatchQueue.main)
            .map { _ in isPro() }
            .eraseToAnyPublisher()
    }
}
