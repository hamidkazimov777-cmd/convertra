import SwiftUI
import AppKit

// MARK: - Design System (ForzaDJ visual language)
// Deep cold-graphite surfaces, violet primary, amber "energy" accent,
// hairline borders, layered soft shadows + signature violet glow.
//
// Surfaces, text and borders are appearance-adaptive: each resolves to a dark
// or light value against the effective appearance (driven by the Appearance
// setting via `NSApplication.appearance` — see `AppSettings.applyAppearance()`).
// The violet/amber accents, gradients and waveform ramp are shared across both
// themes — they read on either background — so only one value is kept for them.

enum Theme {
    enum Colors {
        /// Dynamic color that resolves per effective appearance. Both inputs are
        /// hex strings (`dark` for dark mode, `light` for light mode).
        private static func adaptive(dark: String, light: String) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(Color(hex: isDark ? dark : light))
            })
        }

        /// Hairline that is white-by-opacity on dark and black-by-opacity on
        /// light, so borders stay visible in both themes.
        private static func adaptiveHairline(dark: Double, light: Double) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return isDark ? NSColor.white.withAlphaComponent(dark)
                              : NSColor.black.withAlphaComponent(light)
            })
        }

        // MARK: Backgrounds (layered graphite ⇄ light greys)
        static let bgBase = adaptive(dark: "#0B0C0F", light: "#F0F1F4")      // deepest — sidebar / chrome
        static let bgPrimary = adaptive(dark: "#0E0E11", light: "#FAFBFC")   // content canvas
        static let bgSecondary = adaptive(dark: "#18181C", light: "#FFFFFF") // raised card / panel
        static let bgElevated = adaptive(dark: "#1B1C21", light: "#FFFFFF")  // popover / menu
        static let bgHover = adaptive(dark: "#1E1F23", light: "#EAECEF")     // hover surface
        static let bgSelected = adaptive(dark: "#2A2416", light: "#FBF1DB")  // selected (amber-tinted)

        // MARK: Primary accent (amber / industrial) — shared across themes
        static let accentPrimary = Color(hex: "#F0A02A")
        static let accentBright = Color(hex: "#FFBF57")
        static let accentDeep = Color(hex: "#CF7D1C")
        static let accentHover = Color(hex: "#FFBF57")
        static let accentPressed = Color(hex: "#CF7D1C")
        static let accentMuted = Color(hex: "#C99A5F")

        // MARK: Energy accent (warm amber — ratings, hot signals)
        static let energy = Color(hex: "#EFA831")
        static let energyBright = Color(hex: "#FFC24D")

        // MARK: Semantic
        static let destructive = Color(hex: "#FF6467")

        // MARK: Text (near-white ⇄ near-black)
        static let textPrimary = adaptive(dark: "#FAFAFA", light: "#17181C")
        static let textSecondary = adaptive(dark: "#A3A4AB", light: "#5B5D66")
        static let textMuted = adaptive(dark: "#6E7079", light: "#8A8C94")

        // MARK: Hairline borders (white-on-dark ⇄ black-on-light, by opacity)
        static let border = adaptiveHairline(dark: 0.10, light: 0.12)
        static let borderStrong = adaptiveHairline(dark: 0.16, light: 0.18)
        static let borderSubtle = adaptiveHairline(dark: 0.06, light: 0.08)

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
