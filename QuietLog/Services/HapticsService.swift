// HapticsService.swift
// QuietLog — Noise & Hearing Health

import UIKit

// MARK: - Haptics Service
/// Thin wrapper around UIFeedbackGenerator family.
@Observable
final class HapticsService: @unchecked Sendable {

    static let shared = HapticsService()
    private init() {}

    // MARK: - Generators (prepared lazily)
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    private lazy var lightImpact           = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact          = UIImpactFeedbackGenerator(style: .medium)
    private lazy var selectionGenerator    = UISelectionFeedbackGenerator()

    // MARK: - Public API

    /// Play when dB enters .loud zone
    func playWarning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Play when dB enters .dangerous zone
    func playError() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
    }

    /// Play on successful purchase / action
    func playSuccess() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    /// Standard button tap
    func playLightTap() {
        lightImpact.prepare()
        lightImpact.impactOccurred()
    }

    /// Heavier tap for primary actions
    func playMediumTap() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred()
    }

    /// Chart scrub / segment picker changes
    func playSelection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
