// CircularDBRingView.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Circular DB Ring
/// Circular progress ring showing current dB with peak and average markers.
struct CircularDBRingView: View {
    var currentDB: Double
    var peakDB: Double    = 0
    var averageDB: Double = 0
    var zone: DBZone      = .safe
    let range: ClosedRange<Double> = 0...140

    private var fraction: Double {
        ((currentDB - range.lowerBound) / (range.upperBound - range.lowerBound))
            .clamped(to: 0...1)
    }
    private var peakFraction: Double {
        ((peakDB - range.lowerBound) / (range.upperBound - range.lowerBound))
            .clamped(to: 0...1)
    }
    private var avgFraction: Double {
        ((averageDB - range.lowerBound) / (range.upperBound - range.lowerBound))
            .clamped(to: 0...1)
    }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Color(.systemFill), lineWidth: ringWidth)
                .padding(ringPadding)

            // Zone color segments (static reference marks at 70, 85, 100 dB)
            ZoneSegmentsRing()
                .padding(ringPadding)

            // Active fill arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    zone.fallbackColor,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(ringPadding)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fraction)

            // Peak marker
            if peakDB > 0 {
                RingMarker(fraction: peakFraction, color: .white.opacity(0.8), size: 8)
            }

            // Average marker
            if averageDB > 0 {
                RingMarker(fraction: avgFraction, color: .white.opacity(0.5), size: 6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private let ringWidth: CGFloat   = 12
    private let ringPadding: CGFloat = 12
}

// MARK: - Zone Segments Ring (static background decoration)
private struct ZoneSegmentsRing: View {
    var body: some View {
        ZStack {
            // Moderate zone start (70/140 = 0.5)
            Circle()
                .trim(from: 0.5, to: 70.0/140)
                .stroke(Color.yellow.opacity(0.25), lineWidth: 4)
                .rotationEffect(.degrees(-90))

            // Loud zone (85/140)
            Circle()
                .trim(from: 85.0/140, to: 100.0/140)
                .stroke(Color.orange.opacity(0.25), lineWidth: 4)
                .rotationEffect(.degrees(-90))

            // Dangerous zone (100/140+)
            Circle()
                .trim(from: 100.0/140, to: 1.0)
                .stroke(Color.red.opacity(0.25), lineWidth: 4)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Ring Marker (tick at a fraction position)
private struct RingMarker: View {
    var fraction: Double
    var color: Color
    var size: CGFloat

    var body: some View {
        GeometryReader { geo in
            let radius  = min(geo.size.width, geo.size.height) / 2 - 12
            let angle   = (fraction * 360 - 90) * .pi / 180
            let x = geo.size.width  / 2 + CGFloat(cos(angle)) * radius
            let y = geo.size.height / 2 + CGFloat(sin(angle)) * radius
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .position(x: x, y: y)
        }
    }
}
