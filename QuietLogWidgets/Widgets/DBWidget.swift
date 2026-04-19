// DBWidget.swift
// QuietLog Widget Extension — All widget families

import SwiftUI
import WidgetKit

// MARK: - Circular (Lock Screen) Widget
struct CircularDBWidget: Widget {
    let kind = "CircularDBWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DBWidgetProvider()) { entry in
            CircularDBWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.circular.name")
        .description("widget.circular.desc")
        .supportedFamilies([.accessoryCircular])
    }
}

struct CircularDBWidgetView: View {
    let entry: DBWidgetEntry

    var body: some View {
        Gauge(value: entry.currentDB, in: 0...140) {
            Image(systemName: "waveform")
        } currentValueLabel: {
            Text("\(Int(entry.currentDB))")
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(entry.zone.fallbackColor)
    }
}

// MARK: - Rectangular (Lock Screen) Widget
struct RectangularDBWidgetView: View {
    let entry: DBWidgetEntry

    var body: some View {
        HStack {
            Image(systemName: entry.zone.symbol)
                .foregroundStyle(entry.zone.fallbackColor)
            VStack(alignment: .leading) {
                Text("\(Int(entry.currentDB)) dB")
                    .font(.headline.bold())
                Text(entry.zone.labelString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .widgetURL(URL(string: "quietlog://open"))
    }
}

// MARK: - Small Home Screen Widget
struct SmallDBWidget: Widget {
    let kind = "SmallDBWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DBWidgetProvider()) { entry in
            SmallDBWidgetView(entry: entry)
                .containerBackground(entry.zone.gradient, for: .widget)
        }
        .configurationDisplayName("widget.small.name")
        .description("widget.small.desc")
        .supportedFamilies([.systemSmall])
    }
}

struct SmallDBWidgetView: View {
    let entry: DBWidgetEntry

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(Int(entry.currentDB))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("dB")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(entry.zone.labelString)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())

            Spacer()

            // Mini sparkline placeholder
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(String(format: "%.0f", entry.peakDB))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(12)
        .widgetURL(URL(string: "quietlog://open"))
    }
}

// MARK: - Medium Home Screen Widget
struct MediumDBWidget: Widget {
    let kind = "MediumDBWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DBWidgetProvider()) { entry in
            MediumDBWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.medium.name")
        .description("widget.medium.desc")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumDBWidgetView: View {
    let entry: DBWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: current dB
            VStack(alignment: .leading, spacing: 4) {
                Text("widget.now")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(entry.currentDB))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("dB")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(entry.zone.labelString)
                    .font(.caption.bold())
                    .foregroundStyle(entry.zone.fallbackColor)
            }

            Divider()

            // Right: peak & avg
            VStack(alignment: .leading, spacing: Spacing.sm) {
                WidgetStatRow(icon: "arrow.up.circle.fill",
                              label: "Peak",
                              value: "\(Int(entry.peakDB)) dB",
                              color: .red)
                WidgetStatRow(icon: "waveform",
                              label: "Avg",
                              value: "\(Int(entry.averageDB)) dB",
                              color: .blue)
                Text("widget.updated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .widgetURL(URL(string: "quietlog://open"))
    }
}

// MARK: - Widget Stat Row
private struct WidgetStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}
