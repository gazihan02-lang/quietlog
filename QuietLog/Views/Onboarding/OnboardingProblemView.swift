// OnboardingProblemView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

struct OnboardingProblemView: View {
    var onContinue: () -> Void

    private let stats: [(number: String, label: LocalizedStringKey)] = [
        ("1 Billion", "onboarding.problem.stat1"),
        ("85 dB",     "onboarding.problem.stat2"),
        ("Forever",   "onboarding.problem.stat3")
    ]

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "ear.trianglebadge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                // Title
                Text("onboarding.problem.title")
                    .font(.screenTitle)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                // Stats cards
                VStack(spacing: Spacing.md) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                        StatisticCard(number: stat.number, label: stat.label)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.12 + 0.3),
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

// MARK: - Statistic Card
private struct StatisticCard: View {
    let number: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(number)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .frame(width: 110, alignment: .leading)

            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
    }
}
