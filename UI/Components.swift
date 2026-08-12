import SwiftUI

// MARK: - Стили кнопок

/// Основная кнопка — фирменный violet-градиент со свечением и верхним бликом.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                        .fill(Theme.Colors.accentGradient)
                    // Верхний световой блик — ощущение выпуклой поверхности.
                    RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.20), .clear],
                                             startPoint: .top, endPoint: .bottom))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous))
            .brightness(configuration.isPressed ? -0.05 : 0)
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Вторичная кнопка — «стеклянная» hairline-поверхность.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                    .fill(configuration.isPressed ? Theme.Colors.bgHover : Theme.Colors.bgSecondary.opacity(0.6))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous))
            .hairline(Theme.Layout.buttonRadius, color: configuration.isPressed ? Theme.Colors.borderStrong : Theme.Colors.border)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Деструктивная кнопка — приглушённый красный на hairline-стекле.
struct DestructiveGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.destructive)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                    .fill(configuration.isPressed ? Theme.Colors.destructive.opacity(0.16) : Theme.Colors.destructive.opacity(0.06))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous))
            .hairline(Theme.Layout.buttonRadius, color: Theme.Colors.destructive.opacity(0.45))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Лейбл, который в компактном режиме прячет текст и оставляет только иконку
/// (текст сохраняется как accessibility-подпись). Один тип стиля — чтобы можно
/// было переключать режим по `Bool` без стирания типов.
struct AdaptiveLabelStyle: LabelStyle {
    let iconOnly: Bool
    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            HStack(spacing: 6) {
                configuration.icon
                configuration.title
            }
        }
    }
}

// MARK: - Поле поиска

struct SearchTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textSecondary)
                .font(.system(size: 12, weight: .medium))

            configuration
                .textFieldStyle(.plain)
                .font(.inter(size: 13))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.pillRadius, style: .continuous)
                .fill(Theme.Colors.bgBase.opacity(0.8))
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.pillRadius, style: .continuous))
        .hairline(Theme.Layout.pillRadius, color: Theme.Colors.border)
    }
}

// MARK: - Панели / поверхности

/// Приподнятая панель: карточный фон, мягкое скругление, hairline-рамка.
struct DJPanelBackground: ViewModifier {
    var radius: CGFloat = Theme.Layout.cardRadius
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Colors.bgSecondary)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .hairline(radius, color: Theme.Colors.border)
    }
}

extension View {
    func djPanel(radius: CGFloat = Theme.Layout.cardRadius) -> some View {
        modifier(DJPanelBackground(radius: radius))
    }
}

// MARK: - Секционный заголовок (uppercase, приглушённый трекинг)

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.inter(size: 10, weight: .semibold))
            .foregroundStyle(Theme.Colors.textMuted)
    }
}

// MARK: - Пилюля-бейдж (версия трека, статус и т.п.)

struct TagBadge: View {
    let text: String
    var tint: Color = Theme.Colors.textSecondary
    var body: some View {
        Text(text.uppercased())
            .font(.inter(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous).fill(tint.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous).strokeBorder(tint.opacity(0.30), lineWidth: 1)
            )
    }
}
