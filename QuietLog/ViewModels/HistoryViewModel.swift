// HistoryViewModel.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

@Observable
@MainActor
final class HistoryViewModel {

    // MARK: - State
    var scope: HistoryScope             = .day
    var chartPoints: [ChartPoint]       = []
    var scopeAverage: Double            = 0
    var scopePeak: Double               = 0
    var overThresholdDuration: TimeInterval = 0
    var notableEvents: [NotableEvent]   = []
    var isLoading: Bool                 = false
    var showPaywall: Bool               = false

    // MARK: - Dependencies
    private let dataService      = DataService.shared
    private let subscriptionSvc  = SubscriptionService.shared
    private let prefs            = UserPreferences.shared

    // MARK: - Load

    func loadScope(_ newScope: HistoryScope) {
        // Free users: only .day allowed
        if !subscriptionSvc.isPro && newScope != .day {
            showPaywall = true
            return
        }
        scope    = newScope
        isLoading = true
        Task {
            await performLoad()
            isLoading = false
        }
    }

    func refreshCurrentScope() {
        Task {
            isLoading = true
            await performLoad()
            isLoading = false
        }
    }

    private func performLoad() async {
        chartPoints          = dataService.chartPoints(for: scope)
        scopeAverage         = dataService.averageDB(in: scope)
        scopePeak            = dataService.peakDB(in: scope)
        overThresholdDuration = dataService.durationOverThreshold(
            prefs.customDangerThreshold,
            in: scope
        )
        notableEvents        = dataService.notableEvents(in: scope, limit: 5)
    }

    // MARK: - Export
    func exportCSV() -> String {
        dataService.exportCSV(scope: scope)
    }

    /// Writes CSV to a temp file and returns the URL for ShareLink/UIActivityViewController.
    func exportFileURL() -> URL? {
        let csv = exportCSV()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quietlog_\(scope.rawValue.lowercased()).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Formatted Stats
    var formattedAverage: String   { DBCalculator.formatWithUnit(scopeAverage) }
    var formattedPeak: String      { DBCalculator.formatWithUnit(scopePeak) }
    var formattedOverThreshold: String {
        DBCalculator.formatDuration(overThresholdDuration)
    }
}
