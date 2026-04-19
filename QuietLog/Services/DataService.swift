// DataService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

// MARK: - History Scope
enum HistoryScope: String, CaseIterable, Sendable {
    case day   = "Day"
    case week  = "Week"
    case month = "Month"
    case year  = "Year"

    var label: LocalizedStringKey {
        switch self {
        case .day:   return "history.scope.day"
        case .week:  return "history.scope.week"
        case .month: return "history.scope.month"
        case .year:  return "history.scope.year"
        }
    }

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .day:   return cal.startOfDay(for: now)
        case .week:  return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .month: return cal.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:  return cal.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }
}

// MARK: - Chart Point
struct ChartPoint: Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var value: Double
    var label: String
}

// MARK: - Notable Event
struct NotableEvent: Identifiable, Sendable {
    var id = UUID()
    var timestamp: Date
    var peakDB: Double
    var durationSeconds: Int
    var locationName: String?
}

// MARK: - Data Service
/// SwiftData queries and aggregations for HistoryView, WeeklyReport etc.
@Observable
@MainActor
final class DataService {

    static let shared = DataService()
    private init() {}

    var modelContext: ModelContext?

    // MARK: - Static Formatters (allocated once, thread-safe for read)
    private static let mdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    private static let mmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // MARK: - Aggregations

    /// Single fetch + in-memory compute — avoids N+1 queries.
    func computeStats(for scope: HistoryScope) -> (avg: Double, peak: Double, overThreshold: TimeInterval) {
        let s = samples(in: scope)
        guard !s.isEmpty else { return (0, 0, 0) }
        let dbs = s.map(\.db)
        let avg = dbs.reduce(0, +) / Double(dbs.count)
        let peak = dbs.max() ?? 0
        let threshold = UserPreferences.shared.customDangerThreshold
        let over = TimeInterval(s.filter { $0.db > threshold }.count)
        return (avg, peak, over)
    }

    func samples(in scope: HistoryScope) -> [DecibelSample] {
        guard let ctx = modelContext else { return [] }
        let start = scope.startDate
        let descriptor = FetchDescriptor<DecibelSample>(
            predicate: #Predicate { $0.timestamp >= start },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? ctx.fetch(descriptor)) ?? []
    }

    func averageDB(in scope: HistoryScope) -> Double       { computeStats(for: scope).avg }
    func peakDB(in scope: HistoryScope) -> Double          { computeStats(for: scope).peak }
    func durationOverThreshold(_ threshold: Double, in scope: HistoryScope) -> TimeInterval {
        computeStats(for: scope).overThreshold
    }

    // MARK: - Chart Data

    func chartPoints(for scope: HistoryScope) -> [ChartPoint] {
        let raw = samples(in: scope)
        let cal = Calendar.current

        switch scope {
        case .day:
            return hourlyPoints(samples: raw, calendar: cal)
        case .week:
            return dailyPoints(samples: raw, calendar: cal, days: 7)
        case .month:
            return dailyPoints(samples: raw, calendar: cal, days: 30)
        case .year:
            return monthlyPoints(samples: raw, calendar: cal)
        }
    }

    private func hourlyPoints(samples: [DecibelSample], calendar: Calendar) -> [ChartPoint] {
        var buckets: [Int: [Double]] = [:]
        for s in samples {
            let hour = calendar.component(.hour, from: s.timestamp)
            buckets[hour, default: []].append(s.db)
        }
        let today = calendar.startOfDay(for: Date())
        return (0..<24).compactMap { hour -> ChartPoint? in
            guard let vals = buckets[hour], !vals.isEmpty else { return nil }
            let date = calendar.date(byAdding: .hour, value: hour, to: today) ?? today
            return ChartPoint(date: date,
                              value: vals.reduce(0, +) / Double(vals.count),
                              label: "\(hour):00")
        }
    }

    private func dailyPoints(samples: [DecibelSample], calendar: Calendar, days: Int) -> [ChartPoint] {
        var buckets: [Date: [Double]] = [:]
        for s in samples {
            let day = calendar.startOfDay(for: s.timestamp)
            buckets[day, default: []].append(s.db)
        }
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { offset -> ChartPoint? in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else { return nil }
            let vals = buckets[date] ?? []
            let avg = vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
            return ChartPoint(date: date, value: avg, label: DataService.mdFormatter.string(from: date))
        }
    }

    private func monthlyPoints(samples: [DecibelSample], calendar: Calendar) -> [ChartPoint] {
        var buckets: [Date: [Double]] = [:]
        for s in samples {
            let comps = calendar.dateComponents([.year, .month], from: s.timestamp)
            if let start = calendar.date(from: comps) {
                buckets[start, default: []].append(s.db)
            }
        }
        return buckets.keys.sorted().compactMap { date -> ChartPoint? in
            guard let vals = buckets[date], !vals.isEmpty else { return nil }
            let avg = vals.reduce(0, +) / Double(vals.count)
            return ChartPoint(date: date, value: avg, label: DataService.mmmFormatter.string(from: date))
        }
    }

    // MARK: - Notable Events
    func notableEvents(in scope: HistoryScope, limit: Int = 5) -> [NotableEvent] {
        guard let ctx = modelContext else { return [] }
        let start = scope.startDate
        let descriptor = FetchDescriptor<NoiseSession>(
            predicate: #Predicate { $0.startDate >= start },
            sortBy: [SortDescriptor(\.peakDB, order: .reverse)]
        )
        let sessions = (try? ctx.fetch(descriptor)) ?? []
        return sessions.prefix(limit).map { s in
            NotableEvent(
                timestamp: s.startDate,
                peakDB: s.peakDB,
                durationSeconds: s.durationSeconds,
                locationName: nil
            )
        }
    }

    // MARK: - Weekly Score
    func weeklyHearingScore() -> Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        guard let ctx = modelContext else { return 100 }
        let descriptor = FetchDescriptor<DecibelSample>(
            predicate: #Predicate { $0.timestamp >= oneWeekAgo }
        )
        let s = (try? ctx.fetch(descriptor)) ?? []

        // C7 fix: use Double division before converting to Int
        let minutesAbove85 = Int(Double(s.filter { $0.db > 85 }.count) / 60.0)
        let peakEvents     = Int(Double(s.filter { $0.db > 100 }.count) / 30.0)

        let score = 100 - (minutesAbove85 * 5) - (peakEvents * 3)
        return max(0, min(100, score))
    }

    // MARK: - Data Management
    func deleteAllData() throws {
        guard let ctx = modelContext else { return }
        try ctx.delete(model: DecibelSample.self)
        try ctx.delete(model: NoiseSession.self)
        try ctx.delete(model: AlertEvent.self)
        try ctx.save()
    }

    private static let exportISO8601: ISO8601DateFormatter = ISO8601DateFormatter()

    /// Export samples as CSV string
    func exportCSV(scope: HistoryScope) -> String {
        let s = samples(in: scope)
        var csv = "timestamp,db,source\n"
        for sample in s {
            csv += "\(DataService.exportISO8601.string(from: sample.timestamp)),\(sample.db),\(sample.source)\n"
        }
        return csv
    }
}
