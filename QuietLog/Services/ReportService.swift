// ReportService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

// MARK: - Weekly Report Model
struct WeeklyReport: Sendable {
    var score: Int                        // 0-100
    var averageDB: Double
    var peakDB: Double
    var minutesAbove85: Int
    var minutesAbove100: Int
    var totalSessionMinutes: Int
    var startDate: Date
    var endDate: Date
    var summary: String
    var recommendations: [String]
    var chartPoints: [ChartPoint]
    var scoreInterpretation: String
}

// MARK: - Report Service
@Observable
@MainActor
final class ReportService {

    static let shared = ReportService()
    private init() {}

    var modelContext: ModelContext?
    var currentReport: WeeklyReport?

    // MARK: - Generate Weekly Report

    func generateWeeklyReport() -> WeeklyReport {
        let cal = Calendar.current
        let endDate   = Date()
        let startDate = cal.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        guard let ctx = modelContext else {
            return emptyReport(start: startDate, end: endDate)
        }

        let descriptor = FetchDescriptor<DecibelSample>(
            predicate: #Predicate { $0.timestamp >= startDate }
        )
        let samples = (try? ctx.fetch(descriptor)) ?? []

        guard !samples.isEmpty else {
            return emptyReport(start: startDate, end: endDate)
        }

        let avgDB        = samples.map(\.db).reduce(0, +) / Double(samples.count)
        let peakDB       = samples.map(\.db).max() ?? 0
        // C7: use Double division to avoid integer truncation
        let above85      = Int(Double(samples.filter { $0.db > 85 }.count) / 60.0)
        let above100     = Int(Double(samples.filter { $0.db > 100 }.count) / 60.0)
        let sessionMins  = samples.count / 60
        let score        = computeScore(minutesAbove85: above85, peakEvents: Int(Double(samples.filter { $0.db > 100 }.count) / 30.0))

        let report = WeeklyReport(
            score: score,
            averageDB: avgDB,
            peakDB: peakDB,
            minutesAbove85: above85,
            minutesAbove100: above100,
            totalSessionMinutes: sessionMins,
            startDate: startDate,
            endDate: endDate,
            summary: generateSummary(avg: avgDB, above85: above85, score: score),
            recommendations: generateRecommendations(avg: avgDB, above85: above85, score: score),
            chartPoints: DataService.shared.chartPoints(for: .week),
            scoreInterpretation: interpretation(score: score)
        )
        currentReport = report
        return report
    }

    // MARK: - Score
    private func computeScore(minutesAbove85: Int, peakEvents: Int) -> Int {
        let raw = 100 - (minutesAbove85 * 5) - (peakEvents * 3)
        return max(0, min(100, raw))
    }

    private func interpretation(score: Int) -> String {
        switch score {
        case 90...100: return String(localized: "report.score.excellent")
        case 70..<90:  return String(localized: "report.score.good")
        case 50..<70:  return String(localized: "report.score.caution")
        default:       return String(localized: "report.score.atrisk")
        }
    }

    // MARK: - Summary Text
    private func generateSummary(avg: Double, above85: Int, score: Int) -> String {
        if above85 == 0 {
            return String(localized: "report.summary.excellent")
        } else if above85 < 30 {
            return String(format: String(localized: "report.summary.moderate"), above85)
        } else {
            return String(format: String(localized: "report.summary.high"), above85)
        }
    }

    // MARK: - Recommendations
    private func generateRecommendations(avg: Double, above85: Int, score: Int) -> [String] {
        var recs: [String] = []
        if avg > 80 {
            recs.append(String(localized: "recommendation.lower_volume"))
        }
        if above85 > 60 {
            recs.append(String(localized: "recommendation.take_breaks"))
            recs.append(String(localized: "recommendation.ear_protection"))
        }
        if above85 > 0 {
            recs.append(String(localized: "recommendation.quiet_time"))
        }
        if recs.isEmpty {
            recs.append(String(localized: "recommendation.keep_it_up"))
        }
        return recs
    }

    // MARK: - PDF Export
    func generatePDFData(report: WeeklyReport) -> Data? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        return renderer.pdfData { ctx in
            ctx.beginPage()

            let title = String(localized: "report.pdf.title") as NSString
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            title.draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            let dateStr = "\(report.startDate.formatted(date: .abbreviated, time: .omitted)) – \(report.endDate.formatted(date: .abbreviated, time: .omitted))" as NSString
            dateStr.draw(at: CGPoint(x: 40, y: 80), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ])

            // Score
            let scoreStr = String(format: String(localized: "report.pdf.score"), report.score) as NSString
            scoreStr.draw(at: CGPoint(x: 40, y: 120), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ])

            // Stats
            var yPos: CGFloat = 170
            let statsAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
            let lines: [String] = [
                String(format: String(localized: "report.pdf.average"), report.averageDB),
                String(format: String(localized: "report.pdf.peak"), report.peakDB),
                String(format: String(localized: "report.pdf.above85"), report.minutesAbove85),
                "",
                String(localized: "report.pdf.summary_header"),
                report.summary,
                "",
                String(localized: "report.pdf.recommendations_header")
            ] + report.recommendations

            for line in lines {
                (line as NSString).draw(at: CGPoint(x: 40, y: yPos), withAttributes: statsAttrs)
                yPos += 22
            }
        }
    }

    // MARK: - Empty Report
    private func emptyReport(start: Date, end: Date) -> WeeklyReport {
        WeeklyReport(
            score: 100,
            averageDB: 0,
            peakDB: 0,
            minutesAbove85: 0,
            minutesAbove100: 0,
            totalSessionMinutes: 0,
            startDate: start,
            endDate: end,
            summary: String(localized: "report.summary.nodata"),
            recommendations: [String(localized: "recommendation.start_tracking")],
            chartPoints: [],
            scoreInterpretation: interpretation(score: 100)
        )
    }
}
