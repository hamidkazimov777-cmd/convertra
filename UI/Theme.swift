import SwiftUI

enum Theme {
    enum Colors {
        // Backgrounds
        static let bgBase = Color(hex: "#050505")
        static let bgPrimary = Color(hex: "#080808")
        static let bgSecondary = Color(hex: "#0D0D0D")
        static let bgHover = Color(hex: "#111111")
        static let bgSelected = Color(hex: "#1A1A1A")
        
        // Accents (Olive/Khaki)
        static let accentPrimary = Color(hex: "#6B705C")
        static let accentHover = Color(hex: "#939B7F")
        static let accentPressed = Color(hex: "#7A8068")
        static let accentMuted = Color(hex: "#8A9075")
        
        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#A0A0A0")
        static let textMuted = Color(hex: "#8E8E8E")
        
        // Borders
        static let border = Color(hex: "#222222")
    }
    
    enum Layout {
        static let sidebarWidth: CGFloat = 220
        static let inspectorWidth: CGFloat = 300
        static let playerHeight: CGFloat = 85
        
        static let cornerRadius: CGFloat = 6
        static let buttonRadius: CGFloat = 4
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
