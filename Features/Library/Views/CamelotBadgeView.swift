import SwiftUI

/// SwiftUI badge view for displaying Camelot Wheel key codes (e.g. 4A, 8B)
/// with professional color-coding for DJ track lists and inspectors.
struct CamelotBadgeView: View {
    let camelotKey: CamelotKey?
    let isCompact: Bool
    
    init(camelotKey: CamelotKey?, isCompact: Bool = true) {
        self.camelotKey = camelotKey
        self.isCompact = isCompact
    }
    
    init(code: String?, isCompact: Bool = true) {
        if let code = code, let key = CamelotKey(code: code) {
            self.camelotKey = key
        } else {
            self.camelotKey = nil
        }
        self.isCompact = isCompact
    }

    var body: some View {
        if let key = camelotKey {
            if isCompact {
                // Компактно (список) — чистый цветной моно-код, как в ForzaDJ.
                Text(key.code)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(borderColor(for: key))
            } else {
                // Крупно (инспектор) — цветная пилюля с мягкой заливкой.
                Text(key.code)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(borderColor(for: key))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(backgroundColor(for: key))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(borderColor(for: key).opacity(0.55), lineWidth: 1)
                            )
                    )
            }
        } else {
            Text("—")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.Colors.textMuted)
        }
    }

    // MARK: - Camelot Wheel Color Scheme

    private func backgroundColor(for key: CamelotKey) -> Color {
        let isMinor = key.isMinor
        let number = key.number

        switch number {
        case 1, 2:
            return isMinor ? Color.red.opacity(0.25) : Color.orange.opacity(0.25)
        case 3, 4:
            return isMinor ? Color.purple.opacity(0.25) : Color.pink.opacity(0.25)
        case 5, 6:
            return isMinor ? Color.blue.opacity(0.25) : Color.cyan.opacity(0.25)
        case 7, 8:
            return isMinor ? Color.teal.opacity(0.25) : Color.green.opacity(0.25)
        case 9, 10:
            return isMinor ? Color.mint.opacity(0.25) : Color.yellow.opacity(0.25)
        default:
            return isMinor ? Color.indigo.opacity(0.25) : Color.orange.opacity(0.25)
        }
    }

    private func borderColor(for key: CamelotKey) -> Color {
        let isMinor = key.isMinor
        let number = key.number

        switch number {
        case 1, 2: return isMinor ? Color.red : Color.orange
        case 3, 4: return isMinor ? Color.purple : Color.pink
        case 5, 6: return isMinor ? Color.blue : Color.cyan
        case 7, 8: return isMinor ? Color.teal : Color.green
        case 9, 10: return isMinor ? Color.mint : Color.yellow
        default: return isMinor ? Color.indigo : Color.orange
        }
    }

    private func textColor(for key: CamelotKey) -> Color {
        borderColor(for: key)
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack {
            CamelotBadgeView(code: "4A", isCompact: true)
            CamelotBadgeView(code: "8B", isCompact: true)
            CamelotBadgeView(code: "12A", isCompact: true)
            CamelotBadgeView(code: "1B", isCompact: true)
        }
        HStack {
            CamelotBadgeView(code: "4A", isCompact: false)
            CamelotBadgeView(code: "8B", isCompact: false)
        }
    }
    .padding()
}
