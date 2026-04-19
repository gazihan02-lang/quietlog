// ExposureCalculator.swift
// QuietLog — Noise & Hearing Health

import Foundation

// MARK: - Exposure Calculator
/// Higher-level exposure analysis on top of DBCalculator.
enum ExposureCalculator {

    // MARK: - Daily Budget

    struct DailyBudget: Sendable {
        var consumed: Double         // 0.0 to 1.0+
        var remainingSeconds: Double // negative means over budget
        var hoursRemaining: Double   { max(0, remainingSeconds / 3600) }
        var isOverBudget: Bool       { consumed >= 1.0 }
        var percentageLabel: String  { "\(Int(min(consumed * 100, 999)))%" }
    }

    /// Computes how much of the safe daily exposure budget has been consumed.
    static func dailyBudget(samples: [DecibelSample]) -> DailyBudget {
        guard !samples.isEmpty else {
            return DailyBudget(consumed: 0, remainingSeconds: 8 * 3600)
        }

        // Group into 1-second bins, compute TWA
        let pairs: [(db: Double, seconds: Double)] = samples.map { ($0.db, 1.0) }
        let fraction = DBCalculator.budgetConsumed(samples: pairs)
        let remaining = (8 * 3600) * (1.0 - fraction)

        return DailyBudget(consumed: fraction, remainingSeconds: remaining)
    }

    // MARK: - Instant Spike Check

    /// Returns true if sustained exposure above `threshold` for `requiredSeconds`.
    static func isSpike(
        recentDBs: [Double],
        threshold: Double,
        requiredSeconds: Int
    ) -> Bool {
        guard recentDBs.count >= requiredSeconds else { return false }
        let tail = recentDBs.suffix(requiredSeconds)
        return tail.allSatisfy { $0 >= threshold }
    }

    // MARK: - Headphone Weekly Check (WHO)

    /// WHO guideline: no more than 40 hours per week above 80 dB for headphones.
    static func isHeadphoneWeeklyLimitExceeded(
        totalHeadphoneSeconds: Int,
        averageDB: Double
    ) -> Bool {
        guard averageDB > 80 else { return false }
        return totalHeadphoneSeconds > 40 * 3600
    }

    // MARK: - Weekly Summary Stats

    struct WeeklyStats: Sendable {
        var averageDB: Double
        var peakDB: Double
        var minutesAbove70: Int
        var minutesAbove85: Int
        var minutesAbove100: Int
        var totalSamples: Int
        var score: Int
    }

    static func weeklyStats(samples: [DecibelSample]) -> WeeklyStats {
        guard !samples.isEmpty else {
            return WeeklyStats(averageDB: 0, peakDB: 0,
                               minutesAbove70: 0, minutesAbove85: 0,
                               minutesAbove100: 0, totalSamples: 0, score: 100)
        }
        let dbs = samples.map(\.db)
        let avg  = dbs.reduce(0, +) / Double(dbs.count)
        let peak = dbs.max() ?? 0
        let above70  = samples.filter { $0.db > 70 }.count  / 60
        let above85  = samples.filter { $0.db > 85 }.count  / 60
        let above100 = samples.filter { $0.db > 100 }.count / 60

        let spikeEvents = samples.filter { $0.db > 100 }.count / 30
        let score = max(0, min(100, 100 - above85 * 5 - spikeEvents * 3))

        return WeeklyStats(
            averageDB: avg,
            peakDB: peak,
            minutesAbove70: above70,
            minutesAbove85: above85,
            minutesAbove100: above100,
            totalSamples: samples.count,
            score: score
        )
    }
}
