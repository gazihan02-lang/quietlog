// AudioMeterService.swift
// QuietLog — Noise & Hearing Health

import Foundation
import AVFoundation
import Combine

// MARK: - Audio Meter Service
/// Runs AVAudioEngine, computes dB levels, publishes values to observers.
@Observable
@MainActor
final class AudioMeterService: @unchecked Sendable {

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

    // Internal accumulation for 1-second storage
    private var secondAccumulator: [Double] = []
    private var lastStorageTime: Date = Date()

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
        secondAccumulator = []
    }

    // MARK: - Buffer Processing (runs on audio thread)
    private func processTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let channelPointer = channelData[0]

        // Compute RMS
        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = channelPointer[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameCount))

        // dBFS
        let dbFS = 20.0 * log10(max(Double(rms), 1e-9))

        // dBA approximation: dBFS + calibrationOffset + 90
        let calibration = CalibrationService.shared.totalOffset
        let dba = (dbFS + 90.0 + calibration).clamped(to: 0...140)

        // Determine source
        let source: SampleSource = isHeadphoneConnected ? .headphone : .environmental

        // Accumulate for 1-second storage
        secondAccumulator.append(dba)

        let now = Date()
        if now.timeIntervalSince(lastStorageTime) >= storageInterval {
            let avgDB = secondAccumulator.isEmpty ? dba :
                secondAccumulator.reduce(0, +) / Double(secondAccumulator.count)
            secondAccumulator.removeAll()
            lastStorageTime = now
            let avgToStore = avgDB
            let sourceToStore = source
            Task { @MainActor [weak self] in
                self?.onNewSample?(avgToStore, sourceToStore)
            }
        }

        // Update UI at lower frequency
        Task { @MainActor [weak self] in
            self?.publishDB(dba)
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
            isHeadphoneConnected  = true
            connectedHeadphoneName = headphone.portName
        } else {
            isHeadphoneConnected  = false
            connectedHeadphoneName = nil
        }
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
