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

    // MARK: - Aggregations

    func samples(in scope: HistoryScope) -> [DecibelSample] {
        guard let ctx = modelContext else { return [] }
        let start = scope.startDate
        let descriptor = FetchDescriptor<DecibelSample>(
            predicate: #Predicate { $0.timestamp >= start },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? ctx.fetch(descriptor)) ?? []
    }

    func averageDB(in scope: HistoryScope) -> Double {
        let s = samples(in: scope)
        guard !s.isEmpty else { return 0 }
        return s.map(\.db).reduce(0, +) / Double(s.count)
    }

    func peakDB(in scope: HistoryScope) -> Double {
        samples(in: scope).map(\.db).max() ?? 0
    }

    func durationOverThreshold(_ threshold: Double, in scope: HistoryScope) -> TimeInterval {
        let s = samples(in: scope).filter { $0.db > threshold }
        return TimeInterval(s.count) // 1 sample ≈ 1 second
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
            let fmt = DateFormatter()
            fmt.dateFormat = "M/d"
            return ChartPoint(date: date, value: avg, label: fmt.string(from: date))
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
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM"
            return ChartPoint(date: date, value: avg, label: fmt.string(from: date))
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
                locationName: s.locationName
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

        let minutesAbove85 = s.filter { $0.db > 85 }.count / 60
        let peakEvents     = s.filter { $0.db > 100 }.count / 30   // group by ~30 sec spike

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

    /// Export samples as CSV string
    func exportCSV(scope: HistoryScope) -> String {
        let s = samples(in: scope)
        var csv = "timestamp,db,source\n"
        let fmt = ISO8601DateFormatter()
        for sample in s {
            csv += "\(fmt.string(from: sample.timestamp)),\(sample.db),\(sample.source)\n"
        }
        return csv
    }
}
