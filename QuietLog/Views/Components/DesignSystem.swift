// DesignSystem.swift
// QuietLog — Noise & Hearing Health

import SwiftUI

// MARK: - Spacing Scale
enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius Scale
enum Radius {
    static let small:  CGFloat = 8
    static let medium: CGFloat = 12
    static let large:  CGFloat = 20
    static let sheet:  CGFloat = 28
}

// MARK: - Typography
extension Font {
    /// 96pt SF Pro Rounded Bold — main dB display
    static var dbDisplay: Font {
        .system(size: 96, weight: .bold, design: .rounded)
    }
    /// 24pt SF Pro Rounded Medium — "dB" unit label
    static var dbUnit: Font {
        .system(size: 24, weight: .medium, design: .rounded)
    }
    /// 34pt SF Pro Display Bold — screen titles
    static var screenTitle: Font {
        .system(size: 34, weight: .bold, design: .default)
    }
    /// 20pt rounded semibold — zone badge
    static var zoneBadge: Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
}

// MARK: - Gradient Backgrounds
extension ShapeStyle where Self == LinearGradient {
    static var quietlogBackground: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - View Modifiers

/// Applies iOS 26 Liquid Glass effect. Only use on navigation-layer elements.
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }
}

struct ProLockedModifier: ViewModifier {
    let isPro: Bool
    func body(content: Content) -> some View {
        content
            .opacity(isPro ? 1 : 0.5)
            .overlay(alignment: .topTrailing) {
                if !isPro {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
            }
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }

    func proLocked(_ isPro: Bool) -> some View {
        modifier(ProLockedModifier(isPro: isPro))
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: LocalizedStringKey
    let value: String
    var unit: String? = nil
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
    }
}

// MARK: - Primary Button Style
struct QuietLogPrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(color)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct QuietLogSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Zone Color Badge
struct ZoneBadge: View {
    let zone: DBZone

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: zone.symbol)
            Text(zone.label)
                .font(.zoneBadge)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(zone.fallbackColor.gradient)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(zone.label) zone")
    }
}
