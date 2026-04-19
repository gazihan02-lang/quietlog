// RootView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI
import SwiftData

// MARK: - Root View (Tab Bar)
struct RootView: View {

    @State private var selectedTab: Tab = .now
    @Environment(\.modelContext) private var modelContext

    enum Tab: Int {
        case now, history, health, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            Tab("tab.now", systemImage: "waveform", value: Tab.now) {
                LiveMeterView()
            }

            Tab("tab.history", systemImage: "chart.bar.xaxis", value: Tab.history) {
                HistoryView()
            }

            Tab("tab.health", systemImage: "heart.text.square", value: Tab.health) {
                HealthView()
            }

            Tab("tab.settings", systemImage: "gear", value: Tab.settings) {
                SettingsView()
            }
        }
        .onAppear {
            injectModelContext()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - Deep Link Handler
    // quietlog://live  → Live Meter tab (from widget tap)
    // quietlog://open  → Live Meter tab (legacy)
    private func handleDeepLink(_ url: URL) {
        switch url.host {
        case "live", "open":
            selectedTab = .now
        case "history":
            selectedTab = .history
        case "health":
            selectedTab = .health
        case "settings":
            selectedTab = .settings
        default:
            selectedTab = .now
        }
    }

    // MARK: - Inject model context into services
    private func injectModelContext() {
        SessionService.shared.modelContext = modelContext
        DataService.shared.modelContext     = modelContext
        ReportService.shared.modelContext   = modelContext
    }
}
