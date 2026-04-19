// HealthViewModel.swift
// QuietLog — Noise & Hearing Health

import Foundation
import HealthKit

@Observable
@MainActor
final class HealthViewModel {

    // MARK: - State
    var healthKitStatus: HealthKitStatus    = .unknown
    var lastSyncDate: Date?                 = nil
    var recordsWritten: Int                 = 0
    var weeklyReport: WeeklyReport?         = nil
    var isGeneratingReport: Bool            = false
    var showExportSheet: Bool               = false
    var exportURL: URL?                     = nil
    var syncError: String?                  = nil

    var healthKitWriteEnabled: Bool {
        get { UserPreferences.shared.healthKitWriteEnabled }
        set { UserPreferences.shared.healthKitWriteEnabled = newValue }
    }
    var healthKitReadEnabled: Bool {
        get { UserPreferences.shared.healthKitReadEnabled }
        set { UserPreferences.shared.healthKitReadEnabled = newValue }
    }

    // MARK: - Dependencies
    private let healthKit   = HealthKitService.shared
    private let report      = ReportService.shared

    // MARK: - On Appear
    func onAppear() {
        Task {
            await refreshStatus()
            await generateWeeklyReport()
        }
    }

    // MARK: - HealthKit Toggle
    func toggleHealthKitWrite(_ enabled: Bool) async {
        healthKitWriteEnabled = enabled
        if enabled {
            let authorized = await healthKit.requestAuthorization()
            if authorized {
                healthKitStatus = .enabled
            } else {
                healthKitWriteEnabled = false
                healthKitStatus = .denied
            }
        } else {
            healthKitStatus = .disabled
        }
    }

    // MARK: - Status
    func refreshStatus() async {
        lastSyncDate    = healthKit.lastSyncDate
        recordsWritten  = healthKit.recordsWrittenCount
        syncError       = healthKit.syncError
        healthKitStatus = healthKitWriteEnabled ? .enabled : .disabled
    }

    // MARK: - Weekly Report
    func generateWeeklyReport() async {
        isGeneratingReport = true
        weeklyReport = report.generateWeeklyReport()
        isGeneratingReport = false
    }

    // MARK: - Export
    func exportData(format: ExportFormat) {
        Task {
            switch format {
            case .csv:
                let csv = DataService.shared.exportCSV(scope: .week)
                exportURL = writeTemp(string: csv, name: "quietlog_export.csv")
            case .json:
                exportURL = nil // TODO: implement JSON export in DataService
            case .pdf:
                if let r = weeklyReport,
                   let pdfData = report.generatePDFData(report: r) {
                    exportURL = writeTemp(data: pdfData, name: "quietlog_report.pdf")
                }
            }
            showExportSheet = exportURL != nil
        }
    }

    private func writeTemp(string: String, name: String) -> URL? {
        guard let data = string.data(using: .utf8) else { return nil }
        return writeTemp(data: data, name: name)
    }

    private func writeTemp(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

// MARK: - Supporting Types

enum HealthKitStatus: Sendable {
    case unknown, enabled, disabled, denied
}

enum ExportFormat: String, CaseIterable, Sendable {
    case csv  = "CSV"
    case json = "JSON"
    case pdf  = "PDF"
}
