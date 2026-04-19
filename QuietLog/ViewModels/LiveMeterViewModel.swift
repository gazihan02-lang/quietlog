// LiveMeterViewModel.swift
// QuietLog — Noise & Hearing Health

import Foundation
import SwiftData

// MARK: - Live Meter View Model
@Observable
@MainActor
final class LiveMeterViewModel {

    // MARK: - Observed State (mirrored from services)
    var currentDB: Double          = 0.0
    var currentZone: DBZone        = .safe
    var currentZoneAdvice: String  = ""
    var isSessionActive: Bool      = false
    var sessionDuration: TimeInterval = 0
    var sessionPeak: Double        = 0
    var sessionAverage: Double     = 0
    var permissionState: MicPermissionState = .unknown
    var isCalibrating: Bool        = false
    var isHeadphoneConnected: Bool = false
    var headphoneName: String?     = nil

    // Daily budget
    var dailyBudget: ExposureCalculator.DailyBudget =
        ExposureCalculator.DailyBudget(consumed: 0, remainingSeconds: 8 * 3600)

    // Spike tracking for alerts (5-minute rolling window @ 1 sample/sec)
    private var recentDBs: [Double] = []
    private let maxRecentDBs = 300

    // Auto-stop timer (4 hours)
    private var autoStopTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?

    // MARK: - Dependencies
    private let audioMeter      = AudioMeterService.shared
    private let sessionService  = SessionService.shared
    private let haptics         = HapticsService.shared
    private let notifications   = NotificationService.shared
    private let prefs           = UserPreferences.shared
    private let calibration     = CalibrationService.shared
    private let dataService     = DataService.shared

    // MARK: - Init
    init() {
        setupObservation()
    }

    // MARK: - Setup
    private func setupObservation() {
        // Wire AudioMeterService callback for new 1-second samples
        audioMeter.onNewSample = { [weak self] db, source in
            Task { @MainActor in
                self?.handleNewSample(db: db, source: source)
            }
        }
    }

    // MARK: - Session Control

    func startSession() {
        guard audioMeter.permissionState == .granted else {
            Task { await requestMicrophonePermission() }
            return
        }
        Task {
            await audioMeter.startMeter()
            sessionService.startSession(source: audioMeter.isHeadphoneConnected ? .headphone : .environmental)
            isSessionActive = true
            haptics.playMediumTap()
            startDurationTimer()
            scheduleAutoStop()
            // Trigger widget refresh so it shows an active session immediately
            WidgetUpdater.reloadTimelines()
        }
    }

    func stopSession() {
        audioMeter.stopMeter()
        sessionService.stopSession()
        isSessionActive = false
        cancelAutoStop()
        durationTask?.cancel()
        haptics.playLightTap()
        recentDBs.removeAll()
        // Clear widget to show idle state and trigger a fresh timeline
        WidgetUpdater.writeSample(db: 0, peak: 0, avg: 0)
        WidgetUpdater.reloadTimelines()
    }

    func toggleSession() {
        if isSessionActive { stopSession() } else { startSession() }
    }

    // MARK: - Permissions
    func requestMicrophonePermission() async {
        permissionState = await audioMeter.requestMicrophonePermission()
    }

    // MARK: - Sample Handling
    private func handleNewSample(db: Double, source: SampleSource) {
        // Mirror state from services
        currentDB          = audioMeter.currentDB
        currentZone        = audioMeter.currentZone
        currentZoneAdvice  = currentZone.advice
        isCalibrating      = audioMeter.isCalibrating
        isHeadphoneConnected = audioMeter.isHeadphoneConnected
        headphoneName      = audioMeter.connectedHeadphoneName

        // Persist via session
        sessionService.ingestSample(db: db, source: source)
        sessionPeak    = sessionService.sessionPeak
        sessionAverage = sessionService.sessionAverage

        // Track recent dBs for spike detection
        recentDBs.append(db)
        if recentDBs.count > maxRecentDBs { recentDBs.removeFirst() }

        // Haptic zone transitions
        checkZoneHaptics(db: db)

        // Smart alerts
        checkAlerts(db: db)

        // Health sync
        HealthKitService.shared.enqueueSample(db: db, source: source)

        // Update widget data (writes UserDefaults; does NOT reload WidgetKit timeline)
        WidgetUpdater.writeSample(db: db, peak: sessionPeak, avg: sessionAverage)
    }

    // MARK: - Haptics on Zone Transition
    private var lastHapticZone: DBZone = .safe
    private func checkZoneHaptics(db: Double) {
        let zone = DBZone.classify(db: db, threshold: prefs.customDangerThreshold)
        guard zone != lastHapticZone else { return }
        lastHapticZone = zone
        switch zone {
        case .loud:      haptics.playWarning()
        case .dangerous: haptics.playError()
        default: break
        }
        // Zone change is a meaningful event — reload widget timeline here (not every second)
        WidgetUpdater.reloadTimelines()
    }

    // MARK: - Alert Checks
    private func checkAlerts(db: Double) {
        // Instant spike
        let requiredSecs = prefs.alertSensitivityEnum.sustainedSeconds
        if ExposureCalculator.isSpike(
            recentDBs: recentDBs,
            threshold: 100,
            requiredSeconds: requiredSecs
        ) {
            notifications.sendInstantSpikeAlert(db: db)
        }

        // Cumulative TWA — requires at least maxRecentDBs samples (5 minutes)
        if recentDBs.count >= maxRecentDBs {
            let twa = DBCalculator.twa(dbSamples: recentDBs)
            if twa > prefs.customDangerThreshold {
                notifications.sendCumulativeAlert(twaDB: twa)
            }
        }
    }

    // MARK: - Duration Timer
    private func startDurationTimer() {
        durationTask?.cancel()
        durationTask = Task {
            while !Task.isCancelled && isSessionActive {
                sessionDuration = sessionService.sessionDuration
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Auto-Stop (4 hours)
    private func scheduleAutoStop() {
        cancelAutoStop()
        autoStopTask = Task {
            try? await Task.sleep(for: .seconds(4 * 3600))
            await MainActor.run { [weak self] in
                self?.stopSession()
                NotificationService.shared.sendAutoStopAlert()
            }
        }
    }

    private func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    // MARK: - Formatted Helpers
    var formattedDuration: String {
        DBCalculator.formatDuration(sessionDuration)
    }

    var formattedDB: String {
        DBCalculator.format(currentDB)
    }
}
