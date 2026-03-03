//
//  ProManager.swift
//  macOSBridge
//
//  Manages Itsyhome Pro purchases using StoreKit 2
//

import StoreKit

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

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updateProStatus()
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
        defer { isLoading = false }

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
        defer { isLoading = false }

        try? await AppStore.sync()
        await updateProStatus()
    }

    // MARK: - Entitlement check

    func updateProStatus() async {
        var hasProEntitlement = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if ProProducts.all.contains(transaction.productID) {
                    hasProEntitlement = true
                    break
                }
            }
        }

        isPro = hasProEntitlement

        // Start or stop Pro features based on status
        if hasProEntitlement {
            CloudSyncManager.shared.startListening()
            WebhookServer.shared.startIfEnabled()
        } else {
            CloudSyncManager.shared.stopListening()
            WebhookServer.shared.stop()
        }
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

    // Set to true for TestFlight builds, false for App Store
    static let debugOverride = false

    private let lock = NSLock()
    private var _isPro: Bool = false

    var isPro: Bool {
        get {
            if Self.debugOverride { return true }
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
}
