// DBCalculator.swift
// QuietLog — Noise & Hearing Health

import Foundation

// MARK: - DB Calculator
/// Pure functions for decibel math. All functions are static and Sendable-safe.
enum DBCalculator {

    // MARK: - Core Conversion

    /// Converts PCM sample buffer to RMS value.
    static func rms(samples: UnsafePointer<Float>, count: Int) -> Double {
        guard count > 0 else { return 0 }
        var sum: Double = 0
        for i in 0..<count {
            let s = Double(samples[i])
            sum += s * s
        }
        return sqrt(sum / Double(count))
    }

    /// Converts RMS to dBFS (decibels relative to full scale).
    static func dbFS(rms: Double) -> Double {
        20.0 * log10(max(rms, 1e-9))
    }

    /// Converts dBFS to approximate dBA, applying calibration offset.
    /// Formula: dBA = dBFS + 90 + calibrationOffset
    static func dBA(dbFS: Double, calibrationOffset: Double = 0.0) -> Double {
        let raw = dbFS + 90.0 + calibrationOffset
        return raw.clamped(to: 0...140)
    }

    /// Full pipeline: samples buffer → dBA
    static func processBuffer(
        samples: UnsafePointer<Float>,
        count: Int,
        calibrationOffset: Double = 0.0
    ) -> Double {
        let r  = rms(samples: samples, count: count)
        let fs = dbFS(rms: r)
        return dBA(dbFS: fs, calibrationOffset: calibrationOffset)
    }

    // MARK: - Zone Classification

    static func zone(
        db: Double,
        threshold: Double = 85.0
    ) -> DBZone {
        DBZone.classify(db: db, threshold: threshold)
    }

    // MARK: - Safe Listening Budget (WHO / OSHA 3 dB exchange rate)

    /// Returns the maximum safe exposure duration in seconds for a given dB level.
    /// Reference: 85 dB → 28800 s (8 hours). Time halves every 3 dB increase.
    static func maxSafeSeconds(db: Double) -> Double {
        guard db > 0 else { return .infinity }
        let referenceDB: Double = 85.0
        let referenceSeconds: Double = 8 * 3600  // 28800 s
        let exponent = (db - referenceDB) / 3.0
        return referenceSeconds / pow(2.0, exponent)
    }

    /// Fraction of safe budget consumed.
    /// - Parameters:
    ///   - samples: (db, durationSeconds) pairs
    static func budgetConsumed(samples: [(db: Double, seconds: Double)]) -> Double {
        let total = samples.reduce(0.0) { acc, pair in
            let max = maxSafeSeconds(db: pair.db)
            guard max > 0 else { return acc + 1.0 }
            return acc + pair.seconds / max
        }
        return total.clamped(to: 0...1)
    }

    // MARK: - TWA (Time-Weighted Average)
    /// Energy-average (Leq) over all samples — equivalent to 8-hour TWA with 3 dB exchange rate (WHO).
    /// Formula: Leq = 10 * log10( (1/N) * Σ 10^(dBi/10) )
    /// Reference level: 85 dB for 8 hours. Time halves every 3 dB (3 dB exchange rate).
    /// - Parameter dbSamples: Array of dB readings (each representing 1 second)
    static func twa(dbSamples: [Double]) -> Double {
        guard !dbSamples.isEmpty else { return 0 }
        let totalTime = Double(dbSamples.count)
        let sumEnergy = dbSamples.reduce(0.0) { acc, db in
            acc + pow(10.0, db / 10.0)
        }
        return 10.0 * log10(sumEnergy / totalTime)
    }

    // MARK: - Formatting Helpers

    static func format(_ db: Double) -> String {
        String(format: "%.0f", db)
    }

    static func formatWithUnit(_ db: Double) -> String {
        "\(format(db)) dB"
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: seconds) ?? "< 1m"
    }
}
