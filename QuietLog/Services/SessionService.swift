// SessionService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

// MARK: - Session Service
/// Manages start/stop of noise measurement sessions and persists them via SwiftData.
@Observable
@MainActor
final class SessionService {

    static let shared = SessionService()
    private init() {}

    // MARK: - State
    var isSessionActive: Bool   = false
    var sessionStartTime: Date? = nil
    var sessionPeak: Double     = 0.0
    var sessionAverage: Double  = 0.0
    var sessionSampleCount: Int = 0
    var sessionRunningSum: Double = 0.0
    var currentSessionId: UUID? = nil

    // MARK: - Dependencies (injected)
    var modelContext: ModelContext?

    // MARK: - Session Control

    func startSession(source: SampleSource = .environmental) {
        let id = UUID()
        currentSessionId  = id
        sessionStartTime  = Date()
        sessionPeak       = 0.0
        sessionAverage    = 0.0
        sessionSampleCount = 0
        sessionRunningSum  = 0.0
        isSessionActive   = true

        // Insert a new session placeholder; will be updated on stop
        guard let ctx = modelContext else { return }
        let session = NoiseSession(
            id: id,
            startDate: Date(),
            source: source,
            deviceName: CalibrationService.shared.deviceName
        )
        ctx.insert(session)
        try? ctx.save()
    }

    func stopSession() {
        guard isSessionActive, let startTime = sessionStartTime,
              let sessionId = currentSessionId else { return }

        let duration = Int(Date().timeIntervalSince(startTime))
        let avg = sessionSampleCount > 0 ? sessionRunningSum / Double(sessionSampleCount) : 0

        // Update persisted session
        if let ctx = modelContext {
            let descriptor = FetchDescriptor<NoiseSession>(
                predicate: #Predicate { $0.id == sessionId }
            )
            if let session = try? ctx.fetch(descriptor).first {
                session.endDate         = Date()
                session.avgDB           = avg
                session.peakDB          = sessionPeak
                session.durationSeconds = duration
                try? ctx.save()
            }
        }

        isSessionActive   = false
        sessionStartTime  = nil
        currentSessionId  = nil
    }

    // MARK: - Sample Ingestion
    func ingestSample(db: Double, source: SampleSource) {
        guard isSessionActive else { return }

        // Update running stats
        sessionRunningSum  += db
        sessionSampleCount += 1
        sessionAverage      = sessionRunningSum / Double(sessionSampleCount)
        if db > sessionPeak { sessionPeak = db }

        // Persist the sample
        guard let ctx = modelContext else { return }
        let sample = DecibelSample(
            timestamp: Date(),
            db: db,
            source: source,
            sessionId: currentSessionId
        )
        ctx.insert(sample)
        // Batch save every 10 samples to avoid excessive I/O
        if sessionSampleCount % 10 == 0 {
            try? ctx.save()
        }
    }

    // MARK: - Computed
    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var formattedDuration: String {
        let fmt = DateComponentsFormatter()
        fmt.allowedUnits = [.hour, .minute, .second]
        fmt.unitsStyle = .positional
        fmt.zeroFormattingBehavior = .pad
        return fmt.string(from: sessionDuration) ?? "00:00"
    }
}
