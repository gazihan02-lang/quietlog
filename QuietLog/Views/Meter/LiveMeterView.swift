// LiveMeterView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Live Meter View (Tab 0)
struct LiveMeterView: View {

    @State private var viewModel = LiveMeterViewModel()
    @Environment(SubscriptionService.self) private var subscription

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic zone gradient background
                ZoneBackgroundGradient(zone: viewModel.currentZone)

                VStack(spacing: 0) {
                    // MARK: Toolbar (Liquid Glass)
                    toolbarArea

                    Spacer()

                    // MARK: Calibrating indicator
                    if viewModel.isCalibrating {
                        CalibratingIndicator()
                            .transition(.opacity)
                    }

                    // MARK: Permission denied state
                    if viewModel.permissionState == .denied {
                        MicPermissionDeniedView()
                    } else {
                        // MARK: Main DB readout
                        mainReadout

                        Spacer()

                        // MARK: Circular ring
                        CircularDBRingView(
                            currentDB: viewModel.currentDB,
                            peakDB: viewModel.sessionPeak,
                            averageDB: viewModel.sessionAverage,
                            zone: viewModel.currentZone
                        )
                        .frame(width: 240, height: 240)
                        .padding(.vertical, Spacing.lg)

                        Spacer()

                        // MARK: Session bar
                        SessionBar(
                            duration: viewModel.sessionDuration,
                            peakDB: viewModel.sessionPeak,
                            averageDB: viewModel.sessionAverage,
                            isActive: viewModel.isSessionActive
                        )
                        .padding(.bottom, Spacing.sm)
                    }

                    // MARK: FAB — Start/Stop
                    if viewModel.permissionState != .denied {
                        floatingActionButton
                            .padding(.bottom, Spacing.xl)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await viewModel.requestMicrophonePermission() }
            }
        }
    }

    // MARK: - Toolbar
    @ViewBuilder
    private var toolbarArea: some View {
        HStack {
            // App title / headphone indicator
            VStack(alignment: .leading, spacing: 2) {
                Text("app.name")
                    .font(.headline)
                    .foregroundStyle(.white)
                if viewModel.isHeadphoneConnected, let name = viewModel.headphoneName {
                    Label(name, systemImage: "headphones")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            HStack(spacing: Spacing.md) {
                // Share snapshot
                Button {
                    HapticsService.shared.playLightTap()
                    // ShareLink will be in a sheet
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Main Readout
    private var mainReadout: some View {
        VStack(spacing: Spacing.sm) {
            // Large dB number
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(viewModel.formattedDB)
                    .font(.dbDisplay)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: viewModel.currentDB)

                Text("dB")
                    .font(.dbUnit)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Zone badge
            ZoneBadge(zone: viewModel.currentZone)
                .animation(.spring(response: 0.4), value: viewModel.currentZone)

            // Advice text
            Text(viewModel.currentZoneAdvice)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .animation(.easeInOut, value: viewModel.currentZone)
        }
    }

    // MARK: - FAB
    private var floatingActionButton: some View {
        Button(action: {
            HapticsService.shared.playMediumTap()
            viewModel.toggleSession()
        }) {
            Label(
                viewModel.isSessionActive ? "meter.stop_session" : "meter.start_session",
                systemImage: viewModel.isSessionActive ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .scaleEffect(viewModel.isSessionActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: viewModel.isSessionActive)
    }
}

// MARK: - Supporting Views

private struct CalibratingIndicator: View {
    @State private var opacity: Double = 0.5

    var body: some View {
        Label("meter.calibrating", systemImage: "waveform")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                    opacity = 1.0
                }
            }
            .padding(.top, Spacing.lg)
    }
}

private struct MicPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.8))

            Text("permission.mic.denied.title")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("permission.mic.denied.body")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("permission.open_settings")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .frame(maxHeight: .infinity)
    }
}
