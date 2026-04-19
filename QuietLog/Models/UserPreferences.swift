// UserPreferences.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftUI

// MARK: - User Preferences (stored via @AppStorage / UserDefaults)
final class UserPreferences: ObservableObject {

    static let shared = UserPreferences()

    // Subscription
    @AppStorage("onboardingCompleted")      var onboardingCompleted: Bool   = false
    @AppStorage("firstLaunchDate")          var firstLaunchDateString: String = ""

    // Thresholds
    @AppStorage("customDangerThreshold")    var customDangerThreshold: Double = 85.0
    @AppStorage("alertSensitivity")         var alertSensitivity: String      = "medium"

    // HealthKit
    @AppStorage("healthKitWriteEnabled")    var healthKitWriteEnabled: Bool   = true
    @AppStorage("healthKitReadEnabled")     var healthKitReadEnabled: Bool    = true

    // Notifications
    @AppStorage("notifyOnDanger")           var notifyOnDanger: Bool  = true
    @AppStorage("notifyDaily")              var notifyDaily: Bool     = false
    @AppStorage("notifyWeekly")             var notifyWeekly: Bool    = true

    // Calibration
    @AppStorage("deviceCalibrationOffset")  var deviceCalibrationOffset: Double = 0.0

    // Appearance
    @AppStorage("accentColorOverride")      var accentColorOverride: String = "default"

    // MARK: - Computed
    var firstLaunchDate: Date? {
        get {
            guard !firstLaunchDateString.isEmpty else { return nil }
            return ISO8601DateFormatter().date(from: firstLaunchDateString)
        }
        set {
            firstLaunchDateString = newValue.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        }
    }

    var alertSensitivityEnum: AlertSensitivity {
        AlertSensitivity(rawValue: alertSensitivity) ?? .medium
    }

    private init() {
        // Record first launch
        if firstLaunchDateString.isEmpty {
            firstLaunchDate = Date()
        }
    }
}

// MARK: - Alert Sensitivity
enum AlertSensitivity: String, CaseIterable, Sendable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var label: String {
        switch self {
        case .low:    return String(localized: "settings.sensitivity.low")
        case .medium: return String(localized: "settings.sensitivity.medium")
        case .high:   return String(localized: "settings.sensitivity.high")
        }
    }

    /// How many consecutive seconds above threshold to trigger instant-spike alert
    var sustainedSeconds: Int {
        switch self {
        case .low:    return 10
        case .medium: return 5
        case .high:   return 2
        }
    }
}
