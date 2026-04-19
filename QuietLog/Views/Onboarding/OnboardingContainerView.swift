// OnboardingContainerView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Onboarding Container
/// Manages the onboarding step flow and the final paywall.
struct OnboardingContainerView: View {

    enum Step: Int, CaseIterable {
        case welcome, problem, solution, permissions, paywall
    }

    @State private var currentStep: Step = .welcome
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @Environment(SubscriptionService.self) private var subscription

    var body: some View {
        ZStack {
            switch currentStep {
            case .welcome:
                OnboardingWelcomeView {
                    advance()
                } onRestore: {
                    Task { await subscription.restore() }
                    if subscription.isPro { completeOnboarding() }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .problem:
                OnboardingProblemView { advance() }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .solution:
                OnboardingSolutionView { advance() }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .permissions:
                OnboardingPermissionsView { advance() }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .paywall:
                PaywallOnboardingView(onClose: completeOnboarding)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentStep)
    }

    // MARK: - Navigation
    private func advance() {
        let all = Step.allCases
        guard let idx = all.firstIndex(of: currentStep),
              idx + 1 < all.count else {
            completeOnboarding()
            return
        }
        currentStep = all[idx + 1]
    }

    private func completeOnboarding() {
        onboardingCompleted = true
    }
}
