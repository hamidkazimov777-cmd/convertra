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
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Colors.bgHover)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.textMuted)
                            )
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
                
                // Audio Analysis Engine 2.0 Metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("AUDIO ANALYSIS 2.0")
                        .font(.inter(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                    
                    HStack(spacing: 16) {
                        // Camelot Key Badge
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CAMELOT KEY")
                                .font(.inter(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                            
                            CamelotBadgeView(
                                camelotKey: file.analysis?.camelotKey ?? file.analysis?.musicalKey?.camelotKey,
                                isCompact: false
                            )
                        }
                        
                        // Musical Key Text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MUSICAL KEY")
                                .font(.inter(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                            
                            Text(file.analysis?.musicalKey?.rawValue ?? "—")
                                .font(.inter(size: 13, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        
                        Spacer()
                        
                        // BPM
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("TEMPO")
                                .font(.inter(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                            
                            Text(file.analysis?.bpm.map { String(format: "%.2f BPM", $0) } ?? "—")
                                .font(.inter(size: 13, weight: .bold))
                                .foregroundStyle(Theme.Colors.accentPrimary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Colors.bgBase)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Theme.Colors.border.opacity(0.6), lineWidth: 1)
                            )
                    )
                    
                    // Confidence Scores
                    if let analysis = file.analysis {
                        HStack {
                            if analysis.keyConfidence > 0 {
                                HStack(spacing: 4) {
                                    Text("Key Conf:")
                                        .font(.inter(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(String(format: "%.0f%%", analysis.keyConfidence * 100.0))
                                        .font(.inter(size: 10, weight: .bold))
                                        .foregroundStyle(analysis.keyConfidence >= 0.70 ? Color.green : Color.orange)
                                }
                            }
                            Spacer()
                            if analysis.bpmConfidence > 0 {
                                HStack(spacing: 4) {
                                    Text("BPM Conf:")
                                        .font(.inter(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(String(format: "%.0f%%", analysis.bpmConfidence * 100.0))
                                        .font(.inter(size: 10, weight: .bold))
                                        .foregroundStyle(analysis.bpmConfidence >= 0.70 ? Color.green : Color.orange)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                Spacer()
            } else {
                Spacer()
                Text("Select a track to inspect metadata")
                    .font(.inter(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(16)
        .background(Theme.Colors.bgPrimary)
    }
}
