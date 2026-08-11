import SwiftUI

/// Inspector side panel view displaying rich track metadata, Camelot Key badge,
/// Musical Key text, BPM, and AudioAnalysisEngine 2.0 confidence scores.
struct TrackInspectorView: View {
    let file: AudioFile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let file = file {
                // Header & Artwork
                HStack(spacing: 12) {
                    if let artworkURL = file.metadata.artworkLocation, let nsImage = NSImage(contentsOf: artworkURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .hairline(10, color: Theme.Colors.border)
                            .softShadow(0.6)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.Colors.bgHover)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.textMuted)
                            )
                            .hairline(10, color: Theme.Colors.border)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.displayTitle)
                            .font(.inter(size: 15, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        Text(file.displayArtist)
                            .font(.inter(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Divider().background(Theme.Colors.border)

                // Метрики AudioAnalysisEngine 2.0
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Анализ аудио 2.0")

                    HStack(spacing: 16) {
                        // Camelot
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(text: "Camelot")
                            CamelotBadgeView(
                                camelotKey: file.analysis?.camelotKey ?? file.analysis?.musicalKey?.camelotKey,
                                isCompact: false
                            )
                        }

                        // Тональность
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(text: "Тональность")
                            Text(file.analysis?.musicalKey?.rawValue ?? "—")
                                .font(.inter(size: 14, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }

                        Spacer()

                        // Темп
                        VStack(alignment: .trailing, spacing: 5) {
                            SectionLabel(text: "Темп")
                            Text(file.analysis?.bpm.map { String(format: "%.1f", $0) } ?? "—")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.energy)
                        }
                    }
                    .padding(14)
                    .djPanel(radius: 12)
                    
                    // Confidence Scores
                    if let analysis = file.analysis {
                        HStack {
                            if analysis.keyConfidence > 0 {
                                HStack(spacing: 5) {
                                    Text("Key")
                                        .font(.inter(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(String(format: "%.0f%%", analysis.keyConfidence * 100.0))
                                        .font(.inter(size: 10, weight: .bold))
                                        .foregroundStyle(analysis.keyConfidence >= 0.70 ? Color(hex: "#4ADE80") : Theme.Colors.energy)
                                }
                            }
                            Spacer()
                            if analysis.bpmConfidence > 0 {
                                HStack(spacing: 5) {
                                    Text("BPM")
                                        .font(.inter(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(String(format: "%.0f%%", analysis.bpmConfidence * 100.0))
                                        .font(.inter(size: 10, weight: .bold))
                                        .foregroundStyle(analysis.bpmConfidence >= 0.70 ? Color(hex: "#4ADE80") : Theme.Colors.energy)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text("Выберите трек,\nчтобы увидеть метаданные")
                        .multilineTextAlignment(.center)
                        .font(.inter(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(16)
        .background(Theme.Colors.bgPrimary)
    }
}
