// NoiseSession.swift
// QuietLog — Noise & Hearing Health
// (Named NoiseSession to avoid conflict with Foundation.URLSession)

import Foundation
import SwiftData

@Model
final class NoiseSession {

    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var avgDB: Double
    var peakDB: Double
    var durationSeconds: Int
    /// "environmental" | "headphone"
    var source: String
    var deviceName: String?

    init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        avgDB: Double = 0,
        peakDB: Double = 0,
        durationSeconds: Int = 0,
        source: SampleSource = .environmental,
        deviceName: String? = nil
    ) {
        self.id                  = id
        self.startDate           = startDate
        self.endDate             = endDate
        self.avgDB               = avgDB
        self.peakDB              = peakDB
        self.durationSeconds     = durationSeconds
        self.source              = source.rawValue
        self.deviceName          = deviceName
    }

    // MARK: - Computed
    var sampleSource: SampleSource {
        SampleSource(rawValue: source) ?? .environmental
    }

    var duration: TimeInterval {
        Double(durationSeconds)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }


}
