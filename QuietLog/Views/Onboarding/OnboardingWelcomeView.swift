// OnboardingWelcomeView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

struct OnboardingWelcomeView: View {
    var onGetStarted: () -> Void
    var onRestore: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Animated waveform background
            AnimatedWaveformBackground(db: 60)

            VStack(spacing: Spacing.xl) {
                Spacer()

                // App icon placeholder / logo
                Image(systemName: "waveform")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.white)
                    .padding(Spacing.xl)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large))
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                // Title & subtitle
                VStack(spacing: Spacing.sm) {
                    Text("onboarding.welcome.title")
                        .font(.screenTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("onboarding.welcome.subtitle")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()

                // CTA
                VStack(spacing: Spacing.sm) {
                    Button(action: onGetStarted) {
                        Text("onboarding.welcome.cta")
                    }
                    .buttonStyle(QuietLogPrimaryButtonStyle(color: .white.opacity(0.9)))
                    .foregroundStyle(.black)

                    Button(action: onRestore) {
                        Text("onboarding.welcome.restore")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxxl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }
}
