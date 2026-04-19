// OnboardingSolutionView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

struct OnboardingSolutionView: View {
    var onContinue: () -> Void

    private let features: [(icon: String, title: LocalizedStringKey, desc: LocalizedStringKey)] = [
        ("waveform",          "onboarding.solution.f1.title", "onboarding.solution.f1.desc"),
        ("bell.badge",        "onboarding.solution.f2.title", "onboarding.solution.f2.desc"),
        ("heart.text.square", "onboarding.solution.f3.title", "onboarding.solution.f3.desc")
    ]

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: "shield.checkered")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text("onboarding.solution.title")
                    .font(.screenTitle)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: Spacing.md) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        FeatureRow(
                            icon: feature.icon,
                            title: feature.title,
                            desc: feature.desc
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -30)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index) * 0.1 + 0.3),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                Button(action: onContinue) {
                    Text("onboarding.continue")
                }
                .buttonStyle(QuietLogPrimaryButtonStyle())
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let desc: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.small)
                    .fill(.blue.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
    }
}
