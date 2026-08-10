import SwiftUI

// MARK: - Button Styles

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Colors.bgBase)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Theme.Colors.accentPressed : Theme.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius))
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(size: 14, weight: .medium))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Theme.Colors.bgSelected : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius)
                    .strokeBorder(Theme.Colors.border, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Field Styles

struct SearchTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textSecondary)
                .font(.inter(size: 12))
            
            configuration
                .textFieldStyle(.plain)
                .font(.inter(size: 13))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.bgBase)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius)
                .strokeBorder(Theme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - View Modifiers

struct DJPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .strokeBorder(Theme.Colors.border, lineWidth: 1)
            )
    }
}

extension View {
    func djPanel() -> some View {
        modifier(DJPanelBackground())
    }
}
