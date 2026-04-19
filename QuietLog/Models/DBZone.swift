// DBZone.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - DB Zone Enum
enum DBZone: String, CaseIterable, Sendable {
    case safe       = "safe"
    case moderate   = "moderate"
    case loud       = "loud"
    case dangerous  = "dangerous"

    // MARK: Classification
    static func classify(db: Double, threshold: Double = 85) -> DBZone {
        switch db {
        case ..<70:              return .safe
        case 70..<threshold:    return .moderate
        case threshold..<100:   return .loud
        default:                return .dangerous
        }
    }

    // MARK: Labels
    var label: LocalizedStringKey {
        switch self {
        case .safe:      return "zone.safe"
        case .moderate:  return "zone.moderate"
        case .loud:      return "zone.loud"
        case .dangerous: return "zone.dangerous"
        }
    }

    var labelString: String {
        switch self {
        case .safe:      return String(localized: "zone.safe")
        case .moderate:  return String(localized: "zone.moderate")
        case .loud:      return String(localized: "zone.loud")
        case .dangerous: return String(localized: "zone.dangerous")
        }
    }

    // MARK: Advice
    var advice: String {
        switch self {
        case .safe:
            return String(localized: "zone.safe.advice")
        case .moderate:
            return String(localized: "zone.moderate.advice")
        case .loud:
            return String(localized: "zone.loud.advice")
        case .dangerous:
            return String(localized: "zone.dangerous.advice")
        }
    }

    // MARK: Colors (dynamic light/dark)
    var color: Color {
        switch self {
        case .safe:      return Color("ZoneSafe")
        case .moderate:  return Color("ZoneModerate")
        case .loud:      return Color("ZoneLoud")
        case .dangerous: return Color("ZoneDangerous")
        }
    }

    /// Fallback color if asset catalog color isn't available
    var fallbackColor: Color {
        switch self {
        case .safe:      return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
        case .moderate:  return Color(red: 1.000, green: 0.800, blue: 0.000) // #FFCC00
        case .loud:      return Color(red: 1.000, green: 0.584, blue: 0.000) // #FF9500
        case .dangerous: return Color(red: 1.000, green: 0.231, blue: 0.188) // #FF3B30
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .safe:
            return LinearGradient(
                colors: [Color(red: 0.204, green: 0.780, blue: 0.349).opacity(0.8),
                         Color(red: 0.000, green: 0.478, blue: 1.000).opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .moderate:
            return LinearGradient(
                colors: [Color(red: 1.000, green: 0.800, blue: 0.000).opacity(0.8),
                         Color(red: 1.000, green: 0.584, blue: 0.000).opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .loud:
            return LinearGradient(
                colors: [Color(red: 1.000, green: 0.584, blue: 0.000).opacity(0.9),
                         Color(red: 1.000, green: 0.231, blue: 0.188).opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dangerous:
            return LinearGradient(
                colors: [Color(red: 1.000, green: 0.231, blue: 0.188),
                         Color(red: 0.694, green: 0.000, blue: 0.502).opacity(0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: SF Symbol
    var symbol: String {
        switch self {
        case .safe:      return "checkmark.circle.fill"
        case .moderate:  return "exclamationmark.circle.fill"
        case .loud:      return "exclamationmark.triangle.fill"
        case .dangerous: return "waveform.badge.exclamationmark"
        }
    }

    // MARK: Safe Listening Duration (WHO)
    /// Returns max safe listening duration at this zone's representative dB
    var safeListeningDuration: String {
        switch self {
        case .safe:      return String(localized: "zone.safe.duration")     // "Unlimited"
        case .moderate:  return String(localized: "zone.moderate.duration") // "8 hours"
        case .loud:      return String(localized: "zone.loud.duration")     // "2 hours"
        case .dangerous: return String(localized: "zone.dangerous.duration") // "< 15 min"
        }
    }
}
