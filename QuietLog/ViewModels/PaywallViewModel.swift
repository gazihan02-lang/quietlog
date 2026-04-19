// PaywallViewModel.swift
// QuietLog — Noise & Hearing Health

import Foundation
import StoreKit

@Observable
@MainActor
final class PaywallViewModel {

    // MARK: - State
    var products: [Product]               = []
    var selectedProductID: String         = SubscriptionService.ProductID.annual.rawValue
    var purchaseState: PurchaseState      = .idle
    var errorMessage: String?             = nil
    var isLoading: Bool                   = false
    var isEligibleForTrial: Bool          = false

    // MARK: - Dependencies
    private let subscription = SubscriptionService.shared

    // MARK: - Load
    func onAppear() {
        Task { await loadProducts() }
    }

    func loadProducts() async {
        isLoading = true
        await subscription.loadProducts()
        products          = subscription.products
        isEligibleForTrial = subscription.isEligibleForTrial
        isLoading         = false
    }

    // MARK: - Purchase
    func purchase() async {
        guard let product = products.first(where: { $0.id == selectedProductID }) else {
            return
        }
        await subscription.purchase(product: product)
        purchaseState = subscription.purchaseState
        errorMessage  = subscription.errorMessage
    }

    func restore() async {
        await subscription.restore()
        purchaseState = subscription.purchaseState
        errorMessage  = subscription.errorMessage
    }

    // MARK: - Computed Helpers

    var selectedProduct: Product? {
        products.first { $0.id == selectedProductID }
    }

    var annualProduct: Product? { subscription.annualProduct }
    var monthlyProduct: Product? { subscription.monthlyProduct }
    var lifetimeProduct: Product? { subscription.lifetimeProduct }

    var annualMonthlyEquivalent: String? {
        guard let annual = annualProduct else { return nil }
        return subscription.monthlyEquivalent(for: annual)
    }

    var ctaButtonTitle: String {
        if isEligibleForTrial {
            return String(localized: "paywall.cta.trial")    // "Start 3-Day Free Trial"
        }
        return String(localized: "paywall.cta.subscribe")   // "Subscribe Now"
    }

    var trialLabelText: String {
        if isEligibleForTrial {
            if selectedProductID == SubscriptionService.ProductID.annual.rawValue {
                return String(localized: "paywall.trial.annual")  // "3 days free, then $29.99/year. Cancel anytime."
            } else {
                return String(localized: "paywall.trial.monthly") // "3 days free, then $4.99/month. Cancel anytime."
            }
        }
        return ""
    }

    var isPurchasing: Bool { purchaseState == .purchasing }
    var isRestoring: Bool  { purchaseState == .restoring }
}
