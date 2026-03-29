import SwiftUI

// MARK: - Instagram Dark Mode Color Palette

extension Color {
    // Backgrounds
    static let igBlack = Color(hex: "000000")           // Pure black (main bg)
    static let igSurface = Color(hex: "121212")          // Cards, elevated surfaces
    static let igSurfaceLight = Color(hex: "1A1A1A")     // Slightly lighter surface
    static let igDivider = Color(hex: "262626")          // Borders, dividers

    // Text
    static let igTextPrimary = Color(hex: "F5F5F5")      // Primary text (near white)
    static let igTextSecondary = Color(hex: "A8A8A8")     // Secondary text
    static let igTextTertiary = Color(hex: "737373")      // Muted text

    // Accent — Instagram blue
    static let igBlue = Color(hex: "0095F6")             // Primary action color
    static let igBlueDark = Color(hex: "0074CC")         // Pressed state

    // Instagram gradient colors (for decorative use)
    static let igGradientPurple = Color(hex: "833AB4")
    static let igGradientPink = Color(hex: "E1306C")
    static let igGradientOrange = Color(hex: "F77737")
    static let igGradientYellow = Color(hex: "FCAF45")

    // Functional
    static let igRed = Color(hex: "ED4956")              // Destructive / hearts
    static let igGreen = Color(hex: "58C322")            // Success

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

// MARK: - Instagram Gradient

struct IGGradient: View {
    var body: some View {
        LinearGradient(
            colors: [.igGradientPurple, .igGradientPink, .igGradientOrange, .igGradientYellow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Styled Capsule Tag

struct CapsuleTag: View {
    let text: String
    var color: Color = .igBlue

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
