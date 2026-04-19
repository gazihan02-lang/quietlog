// AlertEvent.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

@Model
final class AlertEvent {

    @Attribute(.unique) var id: UUID
    var timestamp: Date
    /// "instant_spike" | "cumulative" | "headphone_weekly"
    var type: String
    var triggerDB: Double
    var dismissedAt: Date?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: AlertType,
        triggerDB: Double,
        dismissedAt: Date? = nil
    ) {
        self.id          = id
        self.timestamp   = timestamp
        self.type        = type.rawValue
        self.triggerDB   = triggerDB
        self.dismissedAt = dismissedAt
    }

    var alertType: AlertType {
        AlertType(rawValue: type) ?? .instantSpike
    }

    var isDismissed: Bool {
        dismissedAt != nil
    }
}

// MARK: - Alert Type
enum AlertType: String, Codable, Sendable {
    case instantSpike      = "instant_spike"
    case cumulative        = "cumulative"
    case headphoneWeekly   = "headphone_weekly"

    var title: String {
        switch self {
        case .instantSpike:    return String(localized: "alert.type.instant_spike")
        case .cumulative:      return String(localized: "alert.type.cumulative")
        case .headphoneWeekly: return String(localized: "alert.type.headphone_weekly")
        }
    }

    var systemImage: String {
        switch self {
        case .instantSpike:    return "waveform.badge.exclamationmark"
        case .cumulative:      return "ear.trianglebadge.exclamationmark"
        case .headphoneWeekly: return "headphones.circle.fill"
        }
    }
}
