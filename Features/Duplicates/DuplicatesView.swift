import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicates")
                        .font(.title2.weight(.bold))
                    Text("Potential duplicate tracks found in your library. Select tracks you want to move to trash.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.Colors.bgPrimary)
            
            Divider()
                .background(Theme.Colors.border)
            
            if appState.duplicateGroups.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("No Duplicates Found")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Your library looks clean.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.bgBase)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.duplicateGroups) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                // Header
                                Text("\(group.tracks.first?.displayArtist ?? "") - \(group.tracks.first?.displayTitle ?? "")")
                                    .font(.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.Colors.bgHover.opacity(0.3))
                                
                                Divider()
                                    .background(Theme.Colors.border)
                                
                                // Tracks
                                ForEach(group.tracks) { track in
                                    DuplicateTrackRow(track: track)
                                    Divider()
                                        .background(Theme.Colors.border)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Theme.Colors.bgBase)
            }
        }
    }
}

struct DuplicateTrackRow: View {
    let track: AudioFile
    @EnvironmentObject private var appState: AppViewModel
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.fileName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 12) {
                    Label(track.displayDuration, systemImage: "clock")
                    Label(track.displayCodec, systemImage: "waveform")
                    Label(track.displayBitrate, systemImage: "speedometer")
                    Label(track.displaySampleRate, systemImage: "metronome")
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Button(role: .destructive, action: {
                appState.moveTrackToTrash(track.id)
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(isHovered ? Color.red.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Move to Trash")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(isHovered ? Theme.Colors.bgHover.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
