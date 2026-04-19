// HistoryView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI
import Charts

// MARK: - History View (Tab 1)
struct HistoryView: View {

    @State private var viewModel = HistoryViewModel()
    @Environment(SubscriptionService.self) private var subscription

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    // MARK: Scope Picker
                    scopePicker

                    // MARK: Chart
                    chartSection

                    // MARK: Stats row
                    statsRow

                    // MARK: Notable Events
                    if !viewModel.notableEvents.isEmpty {
                        notableEventsList
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("history.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if subscription.isPro, let url = viewModel.exportFileURL() {
                        ShareLink(
                            item: url,
                            subject: Text("history.export.csv"),
                            message: Text("history.export.csv.message")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.refreshCurrentScope()
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallContextualView(
                lockedFeatureName: "paywall.feature.history",
                isPresented: $viewModel.showPaywall
            )
        }
    }

    // MARK: - Scope Picker
    private var scopePicker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryScope.allCases, id: \.self) { scope in
                Button {
                    HapticsService.shared.playSelection()
                    viewModel.loadScope(scope)
                } label: {
                    Text(scope.label)
                        .font(.subheadline.weight(viewModel.scope == scope ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(viewModel.scope == scope ? Color.accentColor.opacity(0.15) : Color.clear)
                }
                .proLocked(subscription.isPro || scope == .day)
            }
        }
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
    }

    // MARK: - Chart
    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else if viewModel.chartPoints.isEmpty {
                NoDataView()
                    .frame(height: 200)
            } else {
                Chart(viewModel.chartPoints) { point in
                    if viewModel.scope == .day {
                        LineMark(
                            x: .value("time", point.date),
                            y: .value("dB", point.value)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("time", point.date),
                            y: .value("dB", point.value)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                    } else {
                        BarMark(
                            x: .value("date", point.date, unit: viewModel.scope == .year ? .month : .day),
                            y: .value("dB", point.value)
                        )
                        .foregroundStyle(barColor(for: point.value).gradient)
                    }
                }
                .chartXAxis { AxisMarks(preset: .aligned, values: .stride(by: xStride)) }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let dB = value.as(Double.self) {
                                Text("\(Int(dB)) dB")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                // Safe threshold reference line at 85 dB
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if let yPos = proxy.position(forY: UserPreferences.shared.customDangerThreshold) {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: yPos))
                                path.addLine(to: CGPoint(x: geo.size.width, y: yPos))
                            }
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            StatCard(
                label: "history.stat.average",
                value: String(format: "%.0f", viewModel.scopeAverage),
                unit: "dB",
                color: DBZone.classify(db: viewModel.scopeAverage).fallbackColor
            )
            StatCard(
                label: "history.stat.peak",
                value: String(format: "%.0f", viewModel.scopePeak),
                unit: "dB",
                color: .red
            )
            StatCard(
                label: "history.stat.over85",
                value: viewModel.formattedOverThreshold,
                color: viewModel.overThresholdDuration > 0 ? .orange : .green
            )
        }
    }

    // MARK: - Notable Events
    private var notableEventsList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("history.notable.title")
                .font(.headline)

            ForEach(viewModel.notableEvents) { event in
                NotableEventRow(event: event)
            }
        }
    }

    // MARK: - Helpers
    private func barColor(for db: Double) -> Color {
        DBZone.classify(db: db, threshold: UserPreferences.shared.customDangerThreshold).fallbackColor
    }

    private var xStride: Calendar.Component {
        switch viewModel.scope {
        case .day:   return .hour
        case .week:  return .day
        case .month: return .weekOfYear
        case .year:  return .month
        }
    }
}

// MARK: - Notable Event Row
private struct NotableEventRow: View {
    let event: NotableEvent

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "waveform.badge.exclamationmark")
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.timestamp, style: .date)
                    .font(.subheadline.weight(.medium))
                if let loc = event.locationName {
                    Text(loc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f dB", event.peakDB))
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text(DBCalculator.formatDuration(Double(event.durationSeconds)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
    }
}

// MARK: - No Data View
private struct NoDataView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("history.no_data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
