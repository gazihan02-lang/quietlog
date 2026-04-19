// PaywallContextualView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Paywall Contextual Sheet
/// Shown as a sheet when a free user taps a Pro-locked feature.
struct PaywallContextualView: View {
    let lockedFeatureName: LocalizedStringKey
    @Binding var isPresented: Bool

    var body: some View {
        PaywallOnboardingView(
            onClose: { isPresented = false },
            contextualFeature: String(localized: lockedFeatureName)
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
