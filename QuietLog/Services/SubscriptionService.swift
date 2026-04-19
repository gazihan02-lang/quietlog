// SubscriptionService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import StoreKit

// MARK: - Subscription Service (StoreKit 2)
@Observable
@MainActor
final class SubscriptionService: @unchecked Sendable {

    static let shared = SubscriptionService()
    private init() {}

    // MARK: - Product IDs
    enum ProductID: String, CaseIterable {
        case monthly  = "com.gazihan.quietlog.pro.monthly"
        case annual   = "com.gazihan.quietlog.pro.annual"
        case lifetime = "com.gazihan.quietlog.pro.lifetime"
    }

    // MARK: - State
    var products: [Product]         = []
    var isPro: Bool                 = false {
        didSet {
            // Sync Pro status to App Group UserDefaults so widget can read it
            WidgetUpdater.writeProStatus(isPro)
        }
    }
    var purchaseState: PurchaseState = .idle
    var errorMessage: String?       = nil
    var isEligibleForTrial: Bool    = false

    private var transactionObserverTask: Task<Void, Never>?

    // MARK: - Transaction Observer
    func startObservingTransactions() async {
        // Check current entitlements immediately
        await refreshEntitlements()

        // Observe future updates
        transactionObserverTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionResult(result)
            }
        }
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            // Sort: monthly, annual, lifetime
            products.sort { a, b in
                let order: [String] = [ProductID.monthly.rawValue,
                                       ProductID.annual.rawValue,
                                       ProductID.lifetime.rawValue]
                let ai = order.firstIndex(of: a.id) ?? 99
                let bi = order.firstIndex(of: b.id) ?? 99
                return ai < bi
            }
            // Check trial eligibility for annual/monthly
            if let annual = products.first(where: { $0.id == ProductID.annual.rawValue }),
               let subscription = annual.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase
    func purchase(product: Product) async {
        purchaseState = .purchasing
        errorMessage  = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handleTransactionResult(verification)
                purchaseState = .success
                HapticsService.shared.playSuccess()
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            errorMessage  = error.localizedDescription
            purchaseState = .failed
        }
    }

    // MARK: - Restore
    func restore() async {
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isPro ? .success : .idle
        } catch {
            errorMessage  = error.localizedDescription
            purchaseState = .failed
        }
    }

    // MARK: - Entitlement Check
    func refreshEntitlements() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result {
                if ProductID(rawValue: t.productID) != nil {
                    if t.revocationDate == nil {
                        // Check expiration for subscriptions
                        if let expiry = t.expirationDate {
                            hasPro = expiry > Date()
                        } else {
                            hasPro = true  // lifetime
                        }
                    }
                }
            }
        }
        isPro = hasPro
    }

    // MARK: - Handle Transaction
    private func handleTransactionResult(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    // MARK: - Helpers
    var annualProduct: Product? {
        products.first { $0.id == ProductID.annual.rawValue }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == ProductID.lifetime.rawValue }
    }

    func monthlyEquivalent(for product: Product) -> String? {
        guard product.id == ProductID.annual.rawValue else { return nil }
        let perMonth = product.price / 12
        return product.priceFormatStyle.format(perMonth)
    }
}

// MARK: - Purchase State
enum PurchaseState: Equatable, Sendable {
    case idle, purchasing, success, failed, pending, restoring
}
