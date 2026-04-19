// SettingsViewModel.swift
// QuietLog — Noise & Hearing Health

import Foundation
import UIKit

@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - State (mirrors UserPreferences via bindings)
    var showDeleteConfirmation: Bool = false
    var showExportSheet: Bool        = false
    var exportURL: URL?              = nil
    var alertMessage: String?        = nil

    // MARK: - Dependencies
    private let prefs          = UserPreferences.shared
    private let subscription   = SubscriptionService.shared
    private let notifications  = NotificationService.shared
    private let healthKit      = HealthKitService.shared
    private let dataService    = DataService.shared

    // MARK: - Subscription Display
    var currentPlanDisplay: String {
        if subscription.isPro { return String(localized: "settings.plan.pro") }
        return String(localized: "settings.plan.free")
    }

    // MARK: - Notification Toggles
    func toggleDangerAlerts(_ on: Bool) {
        prefs.notifyOnDanger = on
        if on {
            Task { await notifications.requestPermission() }
        }
        rescheduleNotifications()
    }

    func toggleDailyNotification(_ on: Bool) {
        prefs.notifyDaily = on
        rescheduleNotifications()
    }

    func toggleWeeklyNotification(_ on: Bool) {
        prefs.notifyWeekly = on
        rescheduleNotifications()
    }

    private func rescheduleNotifications() {
        notifications.scheduleDailySummary()
        notifications.scheduleWeeklyReport()
    }

    // MARK: - App Store Actions

    func openManageSubscriptions() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    func restorePurchases() {
        Task { await subscription.restore() }
    }

    func rateApp() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Data Actions

    func exportData() {
        let csv = dataService.exportCSV(scope: .year)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("quietlog_full_export.csv")
        if let data = csv.data(using: .utf8) {
            try? data.write(to: url)
            exportURL      = url
            showExportSheet = true
        }
    }

    func confirmDeleteAll() {
        showDeleteConfirmation = true
    }

    func deleteAllData() {
        do {
            try dataService.deleteAllData()
            alertMessage = String(localized: "settings.data.deleted")
        } catch {
            alertMessage = error.localizedDescription
        }
        showDeleteConfirmation = false
    }

    // MARK: - Calibration
    func resetCalibration() {
        CalibrationService.shared.resetUserCalibration()
        alertMessage = String(localized: "settings.calibration.reset")
    }

    // MARK: - URL Openers
    func openPrivacyPolicy() {
        open(urlString: "https://bestsoft.com.tr/quietlog/privacy")
    }

    func openTerms() {
        open(urlString: "https://bestsoft.com.tr/quietlog/terms")
    }

    func openSupport() {
        open(urlString: "mailto:support@bestsoft.com.tr")
    }

    private func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
