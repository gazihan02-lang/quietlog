// DecibelSample.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

// MARK: - Decibel Sample (1-second snapshot)
@Model
final class DecibelSample {

    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var db: Double
    /// "environmental" | "headphone"
    var source: String
    var sessionId: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        db: Double,
        source: SampleSource = .environmental,
        sessionId: UUID? = nil
    ) {
        self.id        = id
        self.timestamp = timestamp
        self.db        = db
        self.source    = source.rawValue
        self.sessionId = sessionId
    }

    var sampleSource: SampleSource {
        SampleSource(rawValue: source) ?? .environmental
    }
}

// MARK: - Sample Source
enum SampleSource: String, Codable, Sendable {
    case environmental = "environmental"
    case headphone     = "headphone"
}
