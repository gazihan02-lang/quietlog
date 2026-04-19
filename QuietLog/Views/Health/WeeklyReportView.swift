// WeeklyReportView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI
import Charts

struct WeeklyReportView: View {
    let report: WeeklyReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {

                    // MARK: Header / Score
                    scoreHeader

                    // MARK: Summary
                    Text(report.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)

                    // MARK: 7-day chart
                    if !report.chartPoints.isEmpty {
                        weeklyChart
                    }

                    // MARK: Stats
                    statsSection

                    // MARK: Recommendations
                    recommendationsSection

                    // MARK: Disclaimer
                    Text("report.disclaimer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
            }
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let pdfData = ReportService.shared.generatePDFData(report: report),
                       let url = writePDFToTemp(pdfData) {
                        ShareLink(item: url, subject: Text("report.pdf.title")) {
                            Label("report.share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Score Header
    private var scoreHeader: some View {
        VStack(spacing: Spacing.sm) {
            // Date range
            Text("\(report.startDate.formatted(date: .abbreviated, time: .omitted)) – \(report.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: Double(report.score) / 100)
                    .stroke(
                        scoreColor(report.score),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: report.score)

                VStack(spacing: 2) {
                    Text("\(report.score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("report.score.label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, height: 140)

            Text(report.scoreInterpretation)
                .font(.title3.weight(.semibold))
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: - Weekly Chart
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("report.chart.title")
                .font(.headline)

            Chart(report.chartPoints) { point in
                BarMark(
                    x: .value("date", point.date, unit: .day),
                    y: .value("dB", point.value)
                )
                .foregroundStyle(
                    DBZone.classify(
                        db: point.value,
                        threshold: UserPreferences.shared.customDangerThreshold
                    ).fallbackColor.gradient
                )
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday()) } }
            .frame(height: 180)
        }
        .padding(Spacing.md)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }

    // MARK: - Stats
    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
            StatCard(
                label: "report.stat.average",
                value: String(format: "%.1f", report.averageDB),
                unit: "dB"
            )
            StatCard(
                label: "report.stat.peak",
                value: String(format: "%.1f", report.peakDB),
                unit: "dB",
                color: .red
            )
            StatCard(
                label: "report.stat.above85",
                value: "\(report.minutesAbove85)",
                unit: "min",
                color: report.minutesAbove85 > 0 ? .orange : .green
            )
            StatCard(
                label: "report.stat.total",
                value: "\(report.totalSessionMinutes)",
                unit: "min"
            )
        }
    }

    // MARK: - Recommendations
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("report.recommendations.title")
                .font(.headline)

            ForEach(report.recommendations, id: \.self) { rec in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                        .padding(.top, 2)
                    Text(rec)
                        .font(.subheadline)
                }
                .padding(Spacing.md)
                .background(.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            }
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

    private func writePDFToTemp(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quietlog_report.pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
