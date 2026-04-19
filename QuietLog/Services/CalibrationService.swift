// CalibrationService.swift
// QuietLog — Noise & Hearing Health

import Foundation

// MARK: - Calibration Service
/// Provides per-device dB offset to approximate dBA from dBFS
@Observable
final class CalibrationService: @unchecked Sendable {

    static let shared = CalibrationService()
    private init() {}

    // MARK: - Device Calibration Table (empirical offsets in dB)
    private let offsets: [String: Double] = [
        "iPhone15,2": 0.0,   // iPhone 15 Pro
        "iPhone15,3": 0.0,   // iPhone 15 Pro Max
        "iPhone15,4": 0.5,   // iPhone 15
        "iPhone15,5": 0.5,   // iPhone 15 Plus
        "iPhone16,1": -0.5,  // iPhone 16
        "iPhone16,2": -0.5,  // iPhone 16 Plus
        "iPhone16,3": 0.0,   // iPhone 16 Pro
        "iPhone16,4": 0.0,   // iPhone 16 Pro Max
        "iPhone17,1": 0.0,   // iPhone 17 Pro
        "iPhone17,2": 0.0,   // iPhone 17 Pro Max
        "iPhone17,3": 0.5,   // iPhone 17
        "iPhone17,4": 0.5,   // iPhone 17 Plus
    ]

    // MARK: - Public API

    /// Returns the hardware calibration offset for the current device.
    var hardwareOffset: Double {
        let identifier = deviceIdentifier
        return offsets[identifier] ?? 0.0
    }

    /// Combined offset: hardware + user-set calibration
    var totalOffset: Double {
        hardwareOffset + UserPreferences.shared.deviceCalibrationOffset
    }

    /// Current device model identifier (e.g., "iPhone16,1")
    var deviceIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    var deviceName: String {
        let id = deviceIdentifier
        return deviceNames[id] ?? "iPhone"
    }

    // MARK: - User Calibration
    func resetUserCalibration() {
        UserPreferences.shared.deviceCalibrationOffset = 0.0
    }

    func setUserCalibrationOffset(_ offset: Double) {
        UserPreferences.shared.deviceCalibrationOffset = offset
    }

    // MARK: - Private Helpers
    private let deviceNames: [String: String] = [
        "iPhone15,2": "iPhone 15 Pro",
        "iPhone15,3": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 16",
        "iPhone16,2": "iPhone 16 Plus",
        "iPhone16,3": "iPhone 16 Pro",
        "iPhone16,4": "iPhone 16 Pro Max",
        "iPhone17,1": "iPhone 17 Pro",
        "iPhone17,2": "iPhone 17 Pro Max",
        "iPhone17,3": "iPhone 17",
        "iPhone17,4": "iPhone 17 Plus",
    ]
}
