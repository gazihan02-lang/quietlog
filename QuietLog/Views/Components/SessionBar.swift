// SessionBar.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Session Bar
/// Compact session status bar shown at the bottom of LiveMeterView.
struct SessionBar: View {
    var duration: TimeInterval
    var peakDB: Double
    var averageDB: Double
    var isActive: Bool

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Duration
            SessionBarItem(
                icon: "timer",
                label: "session.bar.duration",
                value: formattedDuration
            )

            Divider()
                .frame(height: 32)

            // Average
            SessionBarItem(
                icon: "waveform",
                label: "session.bar.average",
                value: String(format: "%.0f dB", averageDB)
            )

            Divider()
                .frame(height: 32)

            // Peak
            SessionBarItem(
                icon: "arrow.up.circle.fill",
                label: "session.bar.peak",
                value: String(format: "%.0f dB", peakDB),
                valueColor: peakDB > 85 ? .orange : .primary
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
        .padding(.horizontal, Spacing.md)
        .opacity(isActive ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    private var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

private struct SessionBarItem: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
    }
}
