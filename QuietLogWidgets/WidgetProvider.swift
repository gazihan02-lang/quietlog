// WidgetProvider.swift
// QuietLog Widget Extension

import WidgetKit
import SwiftData
import Foundation

// MARK: - Widget Entry
struct DBWidgetEntry: TimelineEntry {
    let date: Date
    let currentDB: Double
    let zone: DBZone
    let peakDB: Double
    let averageDB: Double
    let isPro: Bool
}

// MARK: - Shared Widget Provider
struct DBWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> DBWidgetEntry {
        DBWidgetEntry(
            date: Date(),
            currentDB: 65,
            zone: .safe,
            peakDB: 72,
            averageDB: 62,
            isPro: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DBWidgetEntry) -> Void) {
        completion(latestEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DBWidgetEntry>) -> Void) {
        let entry    = latestEntry()
        // Refresh every 15 minutes (WidgetKit policy maximum for on-demand updates)
        let nextDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextDate))
        completion(timeline)
    }

    // MARK: - Read latest sample from shared App Group UserDefaults
    private func latestEntry() -> DBWidgetEntry {
        // Widgets cannot run AVAudioEngine; they read last-saved value written by main app via WidgetUpdater
        let defaults = UserDefaults(suiteName: WidgetDataWriter.suiteName) ?? .standard
        let db       = defaults.double(forKey: WidgetDataWriter.keyDB)
        let peak     = defaults.double(forKey: WidgetDataWriter.keyPeak)
        let avg      = defaults.double(forKey: WidgetDataWriter.keyAvg)
        let isPro    = defaults.bool(forKey: WidgetDataWriter.keyIsPro)

        return DBWidgetEntry(
            date: Date(),
            currentDB: db > 0 ? db : 0,
            zone: DBZone.classify(db: db),
            peakDB: peak,
            averageDB: avg,
            isPro: isPro
        )
    }
}

// MARK: - Widget Data Writer (legacy stub — actual writing is done by WidgetUpdater in main app)
// This enum is kept as a namespace for the shared UserDefaults key constants.
enum WidgetDataWriter {
    static let suiteName = "group.com.gazihan.quietlog"

    // Keys mirrored in WidgetUpdater (main app) and DBWidgetProvider (widget extension)
    static let keyDB    = "widget.latestDB"
    static let keyPeak  = "widget.peakDB"
    static let keyAvg   = "widget.avgDB"
    static let keyIsPro = "widget.isPro"
}
