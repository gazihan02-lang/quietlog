// AnimatedWaveformBackground.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Animated Waveform Background
/// Full-screen animated waveform used on the Onboarding welcome screen.
struct AnimatedWaveformBackground: View {
    var db: Double = 60  // can be driven by live dB or simulated

    @State private var phase: Double = 0
    @State private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.18),
                        Color(red: 0.00, green: 0.10, blue: 0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Three overlapping waveforms with different frequencies
                ForEach(0..<3, id: \.self) { index in
                    WaveformShape(
                        phase: phase + Double(index) * .pi / 3,
                        amplitude: amplitudeForDB(db) * (1.0 - Double(index) * 0.2),
                        frequency: 1.5 + Double(index) * 0.3
                    )
                    .stroke(
                        waveColor(index: index),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .opacity(0.7 - Double(index) * 0.15)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .onReceive(timer) { _ in
            phase += 0.05
        }
        .ignoresSafeArea()
    }

    private func amplitudeForDB(_ db: Double) -> Double {
        // Map 0-140 dB → 20...80 pt amplitude
        let clamped = db.clamped(to: 0...140)
        return 20 + (clamped / 140) * 60
    }

    private func waveColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.0, green: 0.8, blue: 1.0),
            Color(red: 0.3, green: 0.5, blue: 1.0),
            Color(red: 0.6, green: 0.3, blue: 1.0)
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Waveform Shape
struct WaveformShape: Shape {
    var phase: Double
    var amplitude: Double
    var frequency: Double

    var animatableData: Double { phase }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width  = rect.width
        let height = rect.height
        let midY   = height / 2
        let step: CGFloat = 2

        path.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 0
        while x <= width {
            let relativeX = x / width
            let y = midY + CGFloat(amplitude) * sin(2 * .pi * frequency * relativeX + phase)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        return path
    }
}

// MARK: - Live Zone Gradient Background
/// Used in LiveMeterView — crossfades between zone gradients.
struct ZoneBackgroundGradient: View {
    let zone: DBZone
    @State private var displayedZone: DBZone = .safe

    var body: some View {
        Rectangle()
            .fill(displayedZone.gradient)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: displayedZone)
            .onChange(of: zone) { _, newZone in
                displayedZone = newZone
            }
            .onAppear { displayedZone = zone }
    }
}
