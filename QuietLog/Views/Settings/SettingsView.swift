// SettingsView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Settings View (Tab 3)
struct SettingsView: View {

    @State private var viewModel = SettingsViewModel()
    @Environment(SubscriptionService.self) private var subscription
    @ObservedObject private var prefs = UserPreferences.shared
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {

                // MARK: Subscription
                Section("settings.section.subscription") {
                    HStack {
                        Label("settings.row.plan", systemImage: "crown.fill")
                        Spacer()
                        Text(viewModel.currentPlanDisplay)
                            .foregroundStyle(.secondary)
                    }
                    Button("settings.row.manage") {
                        viewModel.openManageSubscriptions()
                    }
                    .foregroundStyle(.primary)
                    Button("settings.row.restore") {
                        viewModel.restorePurchases()
                    }
                    .foregroundStyle(.primary)
                    if !subscription.isPro {
                        Button("settings.row.upgrade") {
                            showPaywall = true
                        }
                        .foregroundStyle(.blue)
                    }
                }

                // MARK: Thresholds (Pro)
                Section("settings.section.thresholds") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Label("settings.row.danger_threshold", systemImage: "exclamationmark.triangle.fill")
                            Spacer()
                            Text("\(Int(prefs.customDangerThreshold)) dB")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $prefs.customDangerThreshold, in: 70...120, step: 1)
                            .disabled(!subscription.isPro)
                            .opacity(subscription.isPro ? 1 : 0.5)
                    }
                    .padding(.vertical, Spacing.xs)
                }

                // MARK: Health
                Section("settings.section.health") {
                    Toggle(isOn: $prefs.healthKitWriteEnabled) {
                        Label("health.write_toggle", systemImage: "heart.fill")
                    }
                    .disabled(!subscription.isPro)
                    Toggle(isOn: $prefs.healthKitReadEnabled) {
                        Label("health.read_toggle", systemImage: "arrow.down.heart.fill")
                    }
                    .disabled(!subscription.isPro)
                    Button("settings.row.reset_calibration") {
                        viewModel.resetCalibration()
                    }
                    .foregroundStyle(.primary)
                }

                // MARK: Notifications
                Section("settings.section.notifications") {
                    Toggle(isOn: Binding(
                        get: { prefs.notifyOnDanger },
                        set: { viewModel.toggleDangerAlerts($0) }
                    )) {
                        Label("settings.row.notify_danger", systemImage: "bell.badge.fill")
                    }
                    Toggle(isOn: Binding(
                        get: { prefs.notifyDaily },
                        set: { viewModel.toggleDailyNotification($0) }
                    )) {
                        Label("settings.row.notify_daily", systemImage: "bell.fill")
                    }
                    Toggle(isOn: Binding(
                        get: { prefs.notifyWeekly },
                        set: { viewModel.toggleWeeklyNotification($0) }
                    )) {
                        Label("settings.row.notify_weekly", systemImage: "calendar.badge.clock")
                    }
                }

                // MARK: Data
                Section("settings.section.data") {
                    Button("settings.row.export") {
                        viewModel.exportData()
                    }
                    .foregroundStyle(.primary)
                    .disabled(!subscription.isPro)

                    Button(role: .destructive) {
                        viewModel.confirmDeleteAll()
                    } label: {
                        Label("settings.row.delete_all", systemImage: "trash.fill")
                    }
                }

                // MARK: About
                Section("settings.section.about") {
                    Button("settings.row.privacy_policy") { viewModel.openPrivacyPolicy() }
                        .foregroundStyle(.primary)
                    Button("settings.row.terms") { viewModel.openTerms() }
                        .foregroundStyle(.primary)
                    Button("settings.row.rate") { viewModel.rateApp() }
                        .foregroundStyle(.primary)
                    Button("settings.row.support") { viewModel.openSupport() }
                        .foregroundStyle(.primary)
                    HStack {
                        Text("settings.row.version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Disclaimer
                Section {
                    Text("settings.disclaimer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .navigationTitle("settings.title")
        }
        .confirmationDialog(
            "settings.delete.confirm.title",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.delete.confirm.action", role: .destructive) {
                viewModel.deleteAllData()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.delete.confirm.message")
        }
        .alert("common.notice", isPresented: .constant(viewModel.alertMessage != nil)) {
            Button("common.ok") { viewModel.alertMessage = nil }
        } message: {
            if let msg = viewModel.alertMessage { Text(msg) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallContextualView(
                lockedFeatureName: "paywall.feature.all",
                isPresented: $showPaywall
            )
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            if let url = viewModel.exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
