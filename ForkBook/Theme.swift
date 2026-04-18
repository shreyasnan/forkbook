import SwiftUI

// MARK: - ForkBook Design System
//
// Token values matched to the finalized HTML prototypes.
// Naming: fb* prefix for ForkBook-specific tokens.

extension Color {

    // ── Backgrounds ──
    static let fbBg         = Color(hex: "000000")   // Pure black (main bg)
    static let fbSurface    = Color(hex: "121214")   // Cards, elevated surfaces
    static let fbSurface2      = Color(hex: "1A1A1D")   // Slightly lighter surface
    static let fbSurfaceLight  = fbSurface2              // Alias for clarity
    static let fbBorder     = Color(hex: "26262A")   // Borders, dividers

    // ── Text ──
    static let fbText       = Color.white            // Primary text
    static let fbTextLight  = Color(hex: "D6D6DA")   // Slightly dimmed (names in proof)
    static let fbMuted      = Color(hex: "8E8E93")   // Secondary text
    static let fbMuted2     = Color(hex: "6B6B70")   // Tertiary / captions

    // ── Accent ──
    static let fbAccent1    = Color(hex: "FF7A45")   // Orange — recommendations, primary accent
    static let fbAccent2    = Color(hex: "FF2D87")   // Pink — dish gradient endpoint only

    // ── State & signal ──
    static let fbCommit     = Color(hex: "E8C87A")   // Amber — planned/committed state
    static let fbWarm       = Color(hex: "C4A882")   // Warm sand — trust signals (people)
    static let fbGreen      = Color(hex: "34C759")   // Legacy — prefer fbCommit for planned

    // ── Functional (kept for backward compat) ──
    static let fbRed        = Color(hex: "ED4956")   // Destructive

    // ── Legacy aliases (so existing code still compiles) ──
    static let igBlack         = fbBg
    static let igSurface       = fbSurface
    static let igSurfaceLight  = fbSurface2
    static let igDivider       = fbBorder
    static let igTextPrimary   = fbText
    static let igTextSecondary = fbMuted
    static let igTextTertiary  = fbMuted2
    static let igBlue          = fbAccent1          // Primary action = orange now
    static let igBlueDark      = Color(hex: "E06830")
    static let igRed           = fbRed
    static let igGreen         = fbGreen

    // Hex initializer
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Dish Gradient

/// The signature orange-to-pink gradient used for lead dish names and CTAs.
struct FBDishGradient: ShapeStyle, View {
    var body: some View {
        LinearGradient(
            colors: [.fbAccent1, .fbAccent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ShapeStyle where Self == LinearGradient {
    /// `Text("Fried rice").foregroundStyle(.dishGradient)`
    static var dishGradient: LinearGradient {
        LinearGradient(
            colors: [.fbAccent1, .fbAccent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Styled Card

struct FBCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.fbSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.fbBorder, lineWidth: 1)
            )
    }
}

extension View {
    func fbCard(padding: CGFloat = 16) -> some View {
        modifier(FBCard(padding: padding))
    }
}

// MARK: - Capsule Tag (badge)

struct CapsuleTag: View {
    let text: String
    var color: Color = .fbAccent1

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Section Label (uppercase muted)

struct FBSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Color.fbMuted2)
    }
}

// MARK: - Section Header (larger)

struct FBSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.fbText)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.fbMuted)
            }
        }
    }
}

// MARK: - Primary Button Style (gradient CTA)

struct FBPrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isDestructive
                            ? LinearGradient(colors: [.fbRed], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.fbAccent1, .fbAccent2], startPoint: .leading, endPoint: .trailing)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct FBSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundColor(Color.fbText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.fbSurface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.fbBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Tertiary Button Style (text only)

struct FBTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundColor(Color.fbMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

// MARK: - Toast View

struct FBToast: View {
    enum Style {
        /// Subtle dark pill — blends with dark backgrounds. Default.
        case standard
        /// Warm-accent pill with glow — pops against dark backgrounds for
        /// high-signal confirmations like "Go here \u{2014} we\u{2019}ll check in".
        case prominent
    }

    let message: String
    var style: Style = .standard

    var body: some View {
        switch style {
        case .standard:
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.fbText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(hex: "1C1C1E"))
                        .overlay(Capsule().stroke(Color.fbBorder, lineWidth: 1))
                )
        case .prominent:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fbWarm)
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fbText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(hex: "2A241C"))     // warm-tinted dark
                    .overlay(Capsule().stroke(Color.fbWarm.opacity(0.55), lineWidth: 1))
            )
            .shadow(color: Color.fbWarm.opacity(0.35), radius: 18, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Reaction Picker

struct ReactionPicker: View {
    @Binding var rating: Int

    private let reactions: [(emoji: String, label: String, value: Int)] = [
        ("😐", "Meh", 1),
        ("👍", "Liked", 2),
        ("❤️", "Loved", 3),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(reactions, id: \.value) { item in
                Button {
                    rating = (rating == item.value) ? 0 : item.value
                } label: {
                    Text(item.emoji)
                        .font(.title2)
                        .opacity(rating == 0 || rating == item.value ? 1.0 : 0.3)
                        .scaleEffect(rating == item.value ? 1.2 : 1.0)
                        .animation(.spring(response: 0.25), value: rating)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
