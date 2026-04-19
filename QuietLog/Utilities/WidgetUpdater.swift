// WidgetUpdater.swift
// QuietLog — Noise & Hearing Health
//
// Main-app side of the widget data pipeline.
// Widget extension READS from App Group UserDefaults.
// This file WRITES to it and triggers WidgetKit reloads.

import Foundation
import WidgetKit

enum WidgetUpdater {

    private static let suiteName    = "group.com.gazihan.quietlog"
    private static let keyIsActive   = "widget.isActive"
    private static let keyLastWrite  = "widget.lastWriteTime"

    // MARK: - Write latest sample values (called every second while session is active)
    // Does NOT trigger a WidgetKit reload — reloads are batched at zone-change / session events.
    static func writeSample(db: Double, peak: Double, avg: Double) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(db,   forKey: "widget.latestDB")
        defaults.set(peak, forKey: "widget.peakDB")
        defaults.set(avg,  forKey: "widget.avgDB")
        // db == 0 is written on stopSession — isActive is the authoritative idle flag
        defaults.set(db > 0, forKey: keyIsActive)
        // Timestamp lets the widget detect stale data from a crash (app killed before stopSession)
        defaults.set(Date().timeIntervalSince1970, forKey: keyLastWrite)
    }

    // MARK: - Write Pro status (called from SubscriptionService.isPro didSet)
    static func writeProStatus(_ isPro: Bool) {
        UserDefaults(suiteName: suiteName)?.set(isPro, forKey: "widget.isPro")
    }

    // MARK: - Trigger WidgetKit timeline refresh
    // Only call at meaningful events: session start, session stop, zone change.
    // WidgetKit throttles to ~40 reloads/day — don't call every second.
    static func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
