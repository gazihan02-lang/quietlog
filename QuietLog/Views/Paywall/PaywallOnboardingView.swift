// PaywallOnboardingView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI
import StoreKit

// MARK: - Shared Paywall Body
/// Used for both the onboarding paywall and the contextual paywall sheet.
struct PaywallOnboardingView: View {
    var onClose: () -> Void
    var contextualFeature: String? = nil  // nil = onboarding flow

    @State private var viewModel = PaywallViewModel()
    @Environment(SubscriptionService.self) private var subscription

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {

                    // MARK: Hero
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "ear.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.blue)
                            .padding(.top, Spacing.xl)

                        Text(contextualFeature != nil
                             ? "paywall.contextual.title"
                             : "paywall.onboarding.title")
                            .font(.screenTitle)
                            .multilineTextAlignment(.center)

                        Text("paywall.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                    }

                    // MARK: Features
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(proFeatures, id: \.self) { feature in
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                Text(LocalizedStringKey(feature))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // MARK: Plan Selector
                    if !viewModel.isLoading {
                        PlanSelectorView(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                    } else {
                        ProgressView()
                    }

                    // MARK: Trial text
                    if viewModel.isEligibleForTrial && !viewModel.trialLabelText.isEmpty {
                        Text(viewModel.trialLabelText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                    }

                    // MARK: CTA
                    VStack(spacing: Spacing.sm) {
                        Button {
                            HapticsService.shared.playMediumTap()
                            Task { await viewModel.purchase() }
                        } label: {
                            if viewModel.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                                    .frame(height: 22)
                            } else {
                                Text(viewModel.ctaButtonTitle)
                            }
                        }
                        .buttonStyle(QuietLogPrimaryButtonStyle())
                        .disabled(viewModel.isPurchasing)

                        Button {
                            HapticsService.shared.playLightTap()
                            Task { await viewModel.restore() }
                        } label: {
                            Text("paywall.restore")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(viewModel.isRestoring)
                    }
                    .padding(.horizontal, Spacing.lg)

                    // MARK: Footer Links
                    HStack(spacing: Spacing.md) {
                        if let termsURL = URL(string: "https://bestsoft.com.tr/quietlog/terms") {
                            Link("paywall.terms", destination: termsURL)
                        }
                        Text("·")
                        if let privacyURL = URL(string: "https://bestsoft.com.tr/quietlog/privacy") {
                            Link("paywall.privacy", destination: privacyURL)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .accessibilityLabel("paywall.close.accessibility")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: subscription.isPro) { _, isPro in
            if isPro { onClose() }
        }
        .alert("paywall.error.title", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("common.ok") { viewModel.errorMessage = nil }
        } message: {
            if let err = viewModel.errorMessage {
                Text(err)
            }
        }
    }

    private let proFeatures = [
        "paywall.feature.history",
        "paywall.feature.health",
        "paywall.feature.alerts",
        "paywall.feature.widgets",
        "paywall.feature.report",
        "paywall.feature.headphones"
    ]
}

// MARK: - Plan Selector
struct PlanSelectorView: View {
    @Bindable var viewModel: PaywallViewModel

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Annual (default, best value)
            if let annual = viewModel.annualProduct {
                PlanCard(
                    product: annual,
                    badge: "paywall.badge.bestvalue",
                    monthlyEquivalent: viewModel.annualMonthlyEquivalent,
                    isSelected: viewModel.selectedProductID == annual.id
                ) {
                    viewModel.selectedProductID = annual.id
                    HapticsService.shared.playSelection()
                }
            }

            // Monthly
            if let monthly = viewModel.monthlyProduct {
                PlanCard(
                    product: monthly,
                    badge: nil,
                    monthlyEquivalent: nil,
                    isSelected: viewModel.selectedProductID == monthly.id
                ) {
                    viewModel.selectedProductID = monthly.id
                    HapticsService.shared.playSelection()
                }
            }
        }
    }
}

// MARK: - Plan Card
private struct PlanCard: View {
    let product: Product
    let badge: LocalizedStringKey?
    let monthlyEquivalent: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.xs) {
                        Text(product.displayName)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    if let equiv = monthlyEquivalent {
                        Text(String(format: String(localized: "paywall.per_month"), equiv))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3.bold())
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.medium)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
