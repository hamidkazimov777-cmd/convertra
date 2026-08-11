import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc["Дубликаты"])
                        .font(.inter(size: 20, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(loc["Найдены возможные дубликаты. Отметьте треки для перемещения в Корзину."])
                        .font(.inter(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.Colors.bgPrimary)

            Divider()
                .background(Theme.Colors.border)

            if appState.duplicateGroups.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.Colors.accentPrimary.opacity(0.12)).frame(width: 76, height: 76)
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(Theme.Colors.accentBright)
                    }
                    Text(loc["Дубликатов не найдено"])
                        .font(.inter(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(loc["Библиотека выглядит чистой."])
                        .font(.inter(size: 13))
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
                                Text("\(group.tracks.first?.displayArtist ?? "") — \(group.tracks.first?.displayTitle ?? "")")
                                    .font(.inter(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.Colors.bgHover.opacity(0.4))
                                
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
    @EnvironmentObject private var loc: Localization
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.fileName)
                    .font(.inter(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label(track.displayDuration, systemImage: "clock")
                    Label(track.displayCodec, systemImage: "waveform")
                    Label(track.displayBitrate, systemImage: "speedometer")
                    Label(track.displaySampleRate, systemImage: "metronome")
                }
                .font(.inter(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Button(role: .destructive, action: {
                appState.moveTrackToTrash(track.id)
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.Colors.destructive)
                    .padding(8)
                    .background(isHovered ? Theme.Colors.destructive.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(loc["Переместить в Корзину Mac"])
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(isHovered ? Theme.Colors.bgHover.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
