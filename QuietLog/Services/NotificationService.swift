// NotificationService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import UserNotifications

// MARK: - Notification Service
@Observable
@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - State
    var permissionGranted: Bool = false

    // Cooldown tracking
    private var lastAlertDates: [AlertType: Date] = [:]
    private let cooldownMinutes: Double = 15

    // MARK: - Permission
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            return granted
        } catch {
            return false
        }
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Smart Alerts

    func sendInstantSpikeAlert(db: Double) {
        guard UserPreferences.shared.notifyOnDanger else { return }
        guard shouldSendAlert(type: .instantSpike) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "alert.instant.title")
        content.body  = String(
            format: String(localized: "alert.instant.body"),
            Int(db)
        )
        content.sound = .default
        content.categoryIdentifier = "NOISE_ALERT"
        schedule(content: content, id: "instant_spike_\(Date().timeIntervalSince1970)")
        recordAlert(type: .instantSpike)
    }

    func sendCumulativeAlert(twaDB: Double) {
        guard UserPreferences.shared.notifyOnDanger else { return }
        guard shouldSendAlert(type: .cumulative) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "alert.cumulative.title")
        content.body  = String(
            format: String(localized: "alert.cumulative.body"),
            Int(twaDB)
        )
        content.sound = .default
        schedule(content: content, id: "cumulative_\(Date().timeIntervalSince1970)")
        recordAlert(type: .cumulative)
    }

    func sendHeadphoneWeeklyAlert() {
        guard UserPreferences.shared.notifyOnDanger else { return }
        guard shouldSendAlert(type: .headphoneWeekly) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "alert.headphone.weekly.title")
        content.body  = String(localized: "alert.headphone.weekly.body")
        content.sound = .default
        schedule(content: content, id: "headphone_weekly")
        recordAlert(type: .headphoneWeekly)
    }

    // MARK: - Scheduled Notifications

    func scheduleDailySummary() {
        guard UserPreferences.shared.notifyDaily else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.daily.title")
        content.body  = String(localized: "notification.daily.body")
        content.sound = .default

        var components = DateComponents()
        components.hour   = 21  // 9 PM
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWeeklyReport() {
        guard UserPreferences.shared.notifyWeekly else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.weekly.title")
        content.body  = String(localized: "notification.weekly.body")
        content.sound = .default

        var components = DateComponents()
        components.weekday = 2  // Monday
        components.hour    = 9
        components.minute  = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_report", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private Helpers

    private func schedule(content: UNMutableNotificationContent, id: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func shouldSendAlert(type: AlertType) -> Bool {
        guard let last = lastAlertDates[type] else { return true }
        return Date().timeIntervalSince(last) > cooldownMinutes * 60
    }

    private func recordAlert(type: AlertType) {
        lastAlertDates[type] = Date()
    }
}
