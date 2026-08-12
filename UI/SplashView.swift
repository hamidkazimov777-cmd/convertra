import SwiftUI

/// Launch/welcome screen: app icon + wordmark on a black field with a gold
/// "shine" sweep, a soft accent glow, and a graceful fade-out. Shown once on
/// cold launch, then hands control to the main window via `onFinished`.
struct SplashView: View {
    var onFinished: () -> Void
    @EnvironmentObject private var loc: Localization

    // Animation state
    @State private var iconRevealed = false
    @State private var wordmarkRevealed = false
    @State private var shinePhase: CGFloat = -1.3
    @State private var glowPulse = false
    @State private var isDismissing = false

    // Timing
    private let iconRevealDelay = 0.15
    private let wordmarkRevealDelay = 0.55
    private let shineDelay = 0.7
    private let holdBeforeDismiss = 2.35

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Soft accent glow behind the icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.Colors.accentHover.opacity(0.28),
                            Theme.Colors.accentPrimary.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .blur(radius: 40)
                .scaleEffect(glowPulse ? 1.06 : 0.9)
                .opacity(iconRevealed ? 1 : 0)

            VStack(spacing: 30) {
                // Иконка приложения — фирменный градиентный квадрат со стрелками
                shineWrapped {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Theme.Colors.accentGradient)
                        .frame(width: 132, height: 132)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                                     startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 62, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .shadow(color: Theme.Colors.accentPrimary.opacity(0.45), radius: 30, y: 12)
                .scaleEffect(iconRevealed ? 1 : 0.86)
                .opacity(iconRevealed ? 1 : 0)

                // Wordmark
                Text("Convertra")
                    .font(.inter(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(wordmarkRevealed ? 1 : 0)
                    .offset(y: wordmarkRevealed ? 0 : 8)

                // Подпись
                Text(loc["БИБЛИОТЕКА · АНАЛИЗ · КОНВЕРТАЦИЯ"])
                    .font(.inter(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(wordmarkRevealed ? 0.9 : 0)
                    .offset(y: wordmarkRevealed ? 0 : 6)
            }
        }
        .opacity(isDismissing ? 0 : 1)
        .onAppear(perform: runSequence)
    }

    // MARK: - Shine

    /// Wraps arbitrary content and overlays a diagonal highlight band masked to
    /// the content's own shape, so the sweep only lights up the artwork.
    private func shineWrapped<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let view = content()
        return view
            .overlay(
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.55
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.75), .white.opacity(0.9), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .rotationEffect(.degrees(24))
                    .offset(x: shinePhase * (geo.size.width + bandWidth))
                    .blendMode(.screen)
                }
            )
            .mask(view)
    }

    // MARK: - Sequence

    private func runSequence() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(iconRevealDelay)) {
            iconRevealed = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(wordmarkRevealDelay)) {
            wordmarkRevealed = true
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            glowPulse = true
        }

        // Shine sweep — two passes across the artwork
        DispatchQueue.main.asyncAfter(deadline: .now() + shineDelay) {
            withAnimation(.easeInOut(duration: 1.15).repeatCount(2, autoreverses: false)) {
                shinePhase = 1.3
            }
        }

        // Fade out and hand off
        DispatchQueue.main.asyncAfter(deadline: .now() + holdBeforeDismiss) {
            withAnimation(.easeInOut(duration: 0.55)) {
                isDismissing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onFinished()
            }
        }
    }
}
