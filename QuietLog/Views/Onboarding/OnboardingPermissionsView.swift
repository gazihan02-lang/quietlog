// OnboardingPermissionsView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

struct OnboardingPermissionsView: View {
    var onComplete: () -> Void

    @Environment(AudioMeterService.self) private var audioMeter
    @Environment(NotificationService.self) private var notifications
    @State private var micGranted: Bool   = false
    @State private var notifGranted: Bool = false
    @State private var healthGranted: Bool = false
    @State private var step: PermStep     = .mic
    @State private var appeared = false

    enum PermStep { case mic, notifications, health }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: currentIcon)
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4), value: step)

                Text(currentTitle)
                    .font(.screenTitle)
                    .multilineTextAlignment(.center)

                Text(currentSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                // Permission status pills
                VStack(spacing: Spacing.sm) {
                    PermissionStatusRow(
                        icon: "mic.fill",
                        label: "permission.microphone",
                        granted: micGranted
                    )
                    PermissionStatusRow(
                        icon: "bell.fill",
                        label: "permission.notifications",
                        granted: notifGranted
                    )
                    PermissionStatusRow(
                        icon: "heart.text.square.fill",
                        label: "permission.health",
                        granted: healthGranted
                    )
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                // Mic denied warning
                if !micGranted && step != .mic {
                    Text("permission.mic.denied.hint")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                Button(action: handleNextStep) {
                    Text(buttonTitle)
                }
                .buttonStyle(QuietLogPrimaryButtonStyle())
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Computed
    private var currentIcon: String {
        switch step {
        case .mic:           return "mic.fill"
        case .notifications: return "bell.badge.fill"
        case .health:        return "heart.text.square.fill"
        }
    }

    private var currentTitle: LocalizedStringKey {
        switch step {
        case .mic:           return "permission.mic.title"
        case .notifications: return "permission.notif.title"
        case .health:        return "permission.health.title"
        }
    }

    private var currentSubtitle: LocalizedStringKey {
        switch step {
        case .mic:           return "permission.mic.subtitle"
        case .notifications: return "permission.notif.subtitle"
        case .health:        return "permission.health.subtitle"
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch step {
        case .mic, .notifications: return "permission.allow"
        case .health:              return "permission.continue"
        }
    }

    // MARK: - Actions
    private func handleNextStep() {
        switch step {
        case .mic:
            Task {
                let state = await audioMeter.requestMicrophonePermission()
                micGranted = state == .granted
                step = .notifications
            }
        case .notifications:
            Task {
                notifGranted = await notifications.requestPermission()
                step = .health
            }
        case .health:
            Task {
                healthGranted = await HealthKitService.shared.requestAuthorization()
                // HealthKit is optional; always proceed
                onComplete()
            }
        }
    }
}

// MARK: - Permission Status Row
private struct PermissionStatusRow: View {
    let icon: String
    let label: LocalizedStringKey
    let granted: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
    }
}
