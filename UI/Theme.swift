import SwiftUI

// MARK: - Design System (ForzaDJ visual language)
// Deep cold-graphite surfaces, violet primary, amber "energy" accent,
// hairline borders, layered soft shadows + signature violet glow.

enum Theme {
    enum Colors {
        // MARK: Backgrounds (layered graphite, cold violet undertone)
        static let bgBase = Color(hex: "#0B0C0F")      // deepest — sidebar / chrome
        static let bgPrimary = Color(hex: "#0E0E11")   // content canvas
        static let bgSecondary = Color(hex: "#18181C") // raised card / panel
        static let bgElevated = Color(hex: "#1B1C21")  // popover / menu
        static let bgHover = Color(hex: "#1E1F23")     // hover surface
        static let bgSelected = Color(hex: "#23253A")  // selected (violet-tinted)

        // MARK: Primary accent (violet → indigo)
        static let accentPrimary = Color(hex: "#676CF4")
        static let accentBright = Color(hex: "#7689FF")
        static let accentDeep = Color(hex: "#574EDD")
        static let accentHover = Color(hex: "#7C81FF")
        static let accentPressed = Color(hex: "#574EDD")
        static let accentMuted = Color(hex: "#8E92E8")

        // MARK: Energy accent (warm amber — ratings, hot signals)
        static let energy = Color(hex: "#EFA831")
        static let energyBright = Color(hex: "#FFC24D")

        // MARK: Semantic
        static let destructive = Color(hex: "#FF6467")

        // MARK: Text
        static let textPrimary = Color(hex: "#FAFAFA")
        static let textSecondary = Color(hex: "#A3A4AB")
        static let textMuted = Color(hex: "#6E7079")

        // MARK: Hairline borders (white on dark, by opacity)
        static let border = Color.white.opacity(0.10)
        static let borderStrong = Color.white.opacity(0.16)
        static let borderSubtle = Color.white.opacity(0.06)

        // MARK: Gradients
        static let accentGradient = LinearGradient(
            colors: [accentBright, accentDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Signature energy-colored waveform ramp (low → hot).
        static let waveformRamp: [Color] = [
            Color(hex: "#4ADE80"), // green — calm
            Color(hex: "#A3E635"), // lime
            Color(hex: "#EAB308"), // yellow
            Color(hex: "#EFA831"), // amber
            Color(hex: "#F97316"), // orange — hot
        ]
    }

    enum Layout {
        static let sidebarWidth: CGFloat = 232
        static let inspectorWidth: CGFloat = 300
        static let playerHeight: CGFloat = 88

        static let cornerRadius: CGFloat = 10
        static let cardRadius: CGFloat = 14
        static let buttonRadius: CGFloat = 9
        static let pillRadius: CGFloat = 999
    }
}

// MARK: - Elevation & surface modifiers

extension View {
    /// Soft layered elevation shadow (depth without harshness).
    func softShadow(_ strength: Double = 1.0) -> some View {
        self
            .shadow(color: .black.opacity(0.34 * strength), radius: 16 * strength, x: 0, y: 8 * strength)
            .shadow(color: .black.opacity(0.24 * strength), radius: 4, x: 0, y: 2)
    }

    /// Signature violet glow beneath primary/brand elements.
    func accentGlow(_ strength: Double = 1.0) -> some View {
        self
            .shadow(color: Theme.Colors.accentPrimary.opacity(0.28 * strength), radius: 10 * strength, x: 0, y: 4)
    }

    /// Hairline stroke overlay with a subtle top-light highlight.
    func hairline(_ radius: CGFloat = Theme.Layout.cornerRadius, color: Color = Theme.Colors.border) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: 1)
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension NSImage {
    /// Loads a bundled PNG by name, working in both the packaged `.app`
    /// (main bundle) and SwiftPM debug builds (module resource bundle).
    static func bundled(_ name: String) -> NSImage? {
        if let image = NSImage(named: name) { return image }
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

extension Font {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .semibold, .heavy, .black:
            return .custom("Inter-SemiBold", size: size)
        case .medium:
            return .custom("Inter-Medium", size: size)
        default:
            return .custom("Inter-Regular", size: size)
        }
    }
}
