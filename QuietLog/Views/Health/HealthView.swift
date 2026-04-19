// HealthView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Health View (Tab 2)
struct HealthView: View {

    @State private var viewModel = HealthViewModel()
    @Environment(SubscriptionService.self) private var subscription
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if !subscription.isPro {
                    ProLockedPlaceholder {
                        showPaywall = true
                    }
                } else {
                    healthContent
                }
            }
            .navigationTitle("health.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if subscription.isPro {
                        Menu {
                            ForEach(ExportFormat.allCases, id: \.self) { fmt in
                                Button {
                                    viewModel.exportData(format: fmt)
                                } label: {
                                    Label(
                                        "health.export.\(fmt.rawValue.lowercased())",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear { viewModel.onAppear() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallContextualView(
                lockedFeatureName: "paywall.feature.health",
                isPresented: $showPaywall
            )
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            if let url = viewModel.exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Health Content
    private var healthContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {

                // HealthKit Status Card
                HealthStatusCard(viewModel: viewModel)

                // Toggles
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { viewModel.healthKitWriteEnabled },
                        set: { val in Task { await viewModel.toggleHealthKitWrite(val) } }
                    )) {
                        Label("health.write_toggle", systemImage: "arrow.up.heart.fill")
                    }
                    .padding(Spacing.md)

                    Divider().padding(.leading, 56)

                    Toggle(isOn: Binding(
                        get: { viewModel.healthKitReadEnabled },
                        set: { viewModel.healthKitReadEnabled = $0 }
                    )) {
                        Label("health.read_toggle", systemImage: "arrow.down.heart.fill")
                    }
                    .padding(Spacing.md)
                }
                .background(.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.large))

                // Weekly Report Card
                if viewModel.isGeneratingReport {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                } else if let report = viewModel.weeklyReport {
                    WeeklyReportCardView(report: report)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }
}

// MARK: - Health Status Card
private struct HealthStatusCard: View {
    let viewModel: HealthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("health.status.title")
                        .font(.headline)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                statusIcon
            }

            if let syncDate = viewModel.lastSyncDate {
                Label(
                    String(format: String(localized: "health.last_sync"), syncDate.formatted()),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if viewModel.recordsWritten > 0 {
                Text(String(format: String(localized: "health.records_written"), viewModel.recordsWritten))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let err = viewModel.syncError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }

    private var statusLabel: LocalizedStringKey {
        switch viewModel.healthKitStatus {
        case .enabled:  return "health.status.enabled"
        case .disabled: return "health.status.disabled"
        case .denied:   return "health.status.denied"
        case .unknown:  return "health.status.unknown"
        }
    }

    private var statusColor: Color {
        switch viewModel.healthKitStatus {
        case .enabled:  return .green
        case .disabled: return .secondary
        case .denied:   return .red
        case .unknown:  return .secondary
        }
    }

    private var statusIcon: some View {
        Image(systemName: viewModel.healthKitStatus == .enabled ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(statusColor)
    }
}

// MARK: - Weekly Report Card (summary)
private struct WeeklyReportCardView: View {
    let report: WeeklyReport
    @State private var showFullReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("health.weekly_report.title")
                    .font(.headline)
                Spacer()
                Button("health.weekly_report.view") {
                    showFullReport = true
                }
                .font(.subheadline)
            }

            // Score circle
            HStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(.fill, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: Double(report.score) / 100)
                        .stroke(scoreColor(report.score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(report.score)")
                        .font(.title2.bold())
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(report.scoreInterpretation)
                        .font(.subheadline.weight(.semibold))
                    Text(report.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
        .sheet(isPresented: $showFullReport) {
            WeeklyReportView(report: report)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...100: return .green
        case 70..<90:  return .blue
        case 50..<70:  return .orange
        default:       return .red
        }
    }
}

// MARK: - Pro Locked Placeholder
private struct ProLockedPlaceholder: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink.opacity(0.5))

            Text("health.pro_only.title")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("health.pro_only.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button(action: onUpgrade) {
                Text("paywall.cta.subscribe")
            }
            .buttonStyle(QuietLogPrimaryButtonStyle())
            .padding(.horizontal, Spacing.xl)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
