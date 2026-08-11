import SwiftUI

// MARK: - Сигнатурная энергетическая волна (ForzaDJ)
// Вертикальные бары, окрашенные по амплитуде: спокойный зелёный →
// лаймовый → жёлтый → янтарный → горячий оранжевый. Сыгранная часть
// светится в полную силу, несыгранная — приглушена. Рисуется через Canvas
// (transform-дёшево для GPU, без десятков SwiftUI-слоёв).
struct EnergyWaveformView: View {
    let samples: [Float]
    var progress: CGFloat = 0          // 0…1 — доля воспроизведения
    var barSpacing: CGFloat = 1.5
    var minBarHeight: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let count = samples.count
            let slot = size.width / CGFloat(count)
            let barWidth = max(1, slot - barSpacing)
            let midY = size.height / 2
            let playedX = size.width * progress

            for (i, sample) in samples.enumerated() {
                let amp = CGFloat(max(0, min(1, sample)))
                let x = CGFloat(i) * slot
                let h = max(minBarHeight, amp * size.height)
                let rect = CGRect(x: x, y: midY - h / 2, width: barWidth, height: h)
                let path = Path(roundedRect: rect, cornerRadius: min(barWidth / 2, 1.5))

                let base = Self.rampColor(for: amp)
                let played = x + barWidth <= playedX
                context.fill(path, with: .color(played ? base : base.opacity(0.26)))
            }
        }
        .drawingGroup() // растеризация — плавный скраббинг длинных волн
    }

    /// Интерполяция цвета по энергетической рампе.
    static func rampColor(for amp: CGFloat) -> Color {
        let ramp = Theme.Colors.waveformRamp
        guard ramp.count > 1 else { return ramp.first ?? .green }
        // Лёгкая гамма — приподнимаем середину, чтобы «тёплые» тона были заметнее.
        let t = pow(max(0, min(1, amp)), 0.8) * CGFloat(ramp.count - 1)
        let lo = Int(t)
        let hi = min(lo + 1, ramp.count - 1)
        return ramp[hi] // ступенчатая рампа читается чётче полутонов на тонких барах
    }
}

// MARK: - Legacy Shape (оставлен для совместимости / статичных превью)
struct WaveformShape: Shape {
    let samples: [Float]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }

        let width = rect.width / CGFloat(samples.count)
        let midY = rect.midY
        let height = rect.height

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * width
            let sampleHeight = CGFloat(sample) * height
            let barRect = CGRect(
                x: x,
                y: midY - sampleHeight / 2,
                width: max(1, width - 1),
                height: max(2, sampleHeight)
            )
            path.addRoundedRect(in: barRect, cornerSize: CGSize(width: 2, height: 2))
        }
        return path
    }
}
