// AudioMeterService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import AVFoundation
import Combine
import os

// MARK: - Audio Thread State (lock-protected, accessed from AVAudioEngine callback)
private struct TapState: Sendable {
    var accumulator: [Double]     = []
    var lastStorageTime: Date     = Date()
    var latestDB: Double          = 0
    var latestSource: SampleSource = .environmental
    var isHeadphone: Bool         = false
    var calibrationOffset: Double = 0
}

// MARK: - Audio Meter Service
/// Runs AVAudioEngine, computes dB levels, publishes values to observers.
@Observable
@MainActor
final class AudioMeterService {

    static let shared = AudioMeterService()
    private init() {}

    // MARK: - Published State
    var currentDB: Double          = 0.0
    var currentZone: DBZone        = .safe
    var isRunning: Bool            = false
    var isCalibrating: Bool        = false
    var permissionState: MicPermissionState = .unknown
    var isHeadphoneConnected: Bool = false
    var connectedHeadphoneName: String? = nil

    // MARK: - Private
    private var audioEngine    = AVAudioEngine()
    private var tapInstalled   = false

    private let sampleRate: Double   = 44100
    private let bufferSize: AVAudioFrameCount = 1024
    private let uiUpdateInterval: TimeInterval = 0.2
    private let storageInterval: TimeInterval  = 1.0

    private var calibrationTimer: Task<Void, Never>?
    private var routeChangeObserver: NSObjectProtocol?

    // Thread-safe tap state (read/written from audio thread via lock)
    private let tapState = OSAllocatedUnfairLock(initialState: TapState())
    // 5 Hz UI timer — publishes currentDB on MainActor without spawning a Task per audio buffer
    private var uiTimer: Timer?

    // Callbacks
    var onNewSample: ((Double, SampleSource) -> Void)?  // called every 1 second

    // MARK: - Audio Session Configuration
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetooth, .mixWithOthers, .defaultToSpeaker]
            )
            try session.setPreferredSampleRate(sampleRate)
        } catch {
            print("AudioMeterService: configureAudioSession failed — \(error)")
        }

        // Observe route changes to detect headphone connect/disconnect
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateHeadphoneState()
            }
        }
    }

    // MARK: - Permission
    func requestMicrophonePermission() async -> MicPermissionState {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            permissionState = .granted
        case .denied, .restricted:
            permissionState = .denied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            permissionState = granted ? .granted : .denied
        @unknown default:
            permissionState = .denied
        }
        return permissionState
    }

    // MARK: - Start / Stop
    func startMeter() async {
        guard permissionState == .granted else {
            let state = await requestMicrophonePermission()
            guard state == .granted else { return }
        }

        guard !isRunning else { return }

        do {
            try AVAudioSession.sharedInstance().setActive(true)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            if tapInstalled {
                inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }

            inputNode.installTap(
                onBus: 0,
                bufferSize: bufferSize,
                format: format
            ) { [weak self] buffer, _ in
                self?.processTapBuffer(buffer)
            }
            tapInstalled = true

            try audioEngine.start()
            isRunning = true

            // Cache calibration offset into tapState so the audio thread can read it safely
            let offset = CalibrationService.shared.totalOffset
            tapState.withLock { $0.calibrationOffset = offset }

            // 5 Hz timer: reads latestDB from tapState and pushes to @Observable properties
            uiTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self else { return }
                let db = self.tapState.withLock { $0.latestDB }
                self.publishDB(db)
            }

            // Show calibrating for 2 seconds
            isCalibrating = true
            calibrationTimer = Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { [weak self] in
                    self?.isCalibrating = false
                }
            }

            updateHeadphoneState()

        } catch {
            print("AudioMeterService: startMeter failed — \(error)")
            isRunning = false
        }
    }

    func stopMeter() {
        calibrationTimer?.cancel()
        calibrationTimer = nil

        uiTimer?.invalidate()
        uiTimer = nil
        tapState.withLock { $0 = TapState() }

        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning      = false
        isCalibrating  = false
        currentDB      = 0.0
        currentZone    = .safe
    }

    // MARK: - Buffer Processing (runs on audio thread — fully nonisolated)
    nonisolated private func processTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Single lock acquisition: read config, run DSP (~5 µs pure float math), update state.
        // Merging the former two withLock calls eliminates any window where another writer
        // could slip in between reading calibrationOffset and writing latestDB.
        let result: (avg: Double, source: SampleSource)? = tapState.withLock { state in
            let dba = DBCalculator.processBuffer(
                samples: channelData[0],
                count: frameCount,
                calibrationOffset: state.calibrationOffset
            )
            state.latestDB = dba
            let source: SampleSource = state.isHeadphone ? .headphone : .environmental
            state.latestSource = source
            state.accumulator.append(dba)
            let now = Date()
            guard now.timeIntervalSince(state.lastStorageTime) >= 1.0 else { return nil }
            let avg = state.accumulator.reduce(0, +) / Double(state.accumulator.count)
            state.accumulator.removeAll()
            state.lastStorageTime = now
            return (avg, source)
        }

        // Dispatch 1-second sample to MainActor (≤1 Task/sec — no Task spam)
        if let (avg, source) = result {
            Task { @MainActor [weak self] in
                self?.onNewSample?(avg, source)
            }
        }
        // UI refresh is handled by the 5 Hz uiTimer — no per-buffer Task needed
    }

    // MARK: - UI Timer Lifecycle
    /// Pause the 5 Hz UI timer when the app is backgrounded (UI is not visible).
    func pauseUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }

    /// Resume the 5 Hz UI timer when the app returns to foreground (only if a session is active).
    func resumeUITimer() {
        guard isRunning, uiTimer == nil else { return }
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let db = self.tapState.withLock { $0.latestDB }
            self.publishDB(db)
        }
    }

    @MainActor
    private func publishDB(_ db: Double) {
        currentDB = db
        currentZone = DBZone.classify(
            db: db,
            threshold: UserPreferences.shared.customDangerThreshold
        )
    }

    // MARK: - Headphone Detection
    private func updateHeadphoneState() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let headphoneTypes: [AVAudioSession.Port] = [
            .headphones, .bluetoothA2DP, .bluetoothHFP, .airPlay
        ]
        if let headphone = outputs.first(where: { headphoneTypes.contains($0.portType) }) {
            isHeadphoneConnected   = true
            connectedHeadphoneName = headphone.portName
        } else {
            isHeadphoneConnected   = false
            connectedHeadphoneName = nil
        }
        // Mirror to tapState so audio thread can determine SampleSource without touching MainActor
        let isHP = isHeadphoneConnected
        tapState.withLock { $0.isHeadphone = isHP }
    }
}

// MARK: - Supporting Types

enum MicPermissionState: Sendable {
    case unknown, granted, denied
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
