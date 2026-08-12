import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    var filterFolder: URL? = nil
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization
    @State private var isDropTargeted = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            TopHeaderView()
            
            Divider().background(Theme.Colors.border)
            
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Крупная drop-зона нужна только пока библиотека пуста —
                    // это первый экран новичка. Как только треки есть, отдаём
                    // всё место списку (drag&drop продолжает работать на всём вью,
                    // плюс кнопка «Импорт» в шапке).
                    if appState.library.isEmpty {
                        DropZoneView()
                            .frame(height: geo.size.height * 0.45)

                        Divider().background(Theme.Colors.border)
                    }

                    VStack(spacing: 0) {
                        LibraryToolbarView(searchText: $searchText)
                        Divider().background(Theme.Colors.border)
                        TrackListView(searchText: searchText, filterFolder: filterFolder)
                    }
                }
            }
        }
        .background(Theme.Colors.bgPrimary)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Theme.Layout.cardRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.accentBright, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardRadius, style: .continuous)
                            .fill(Theme.Colors.accentPrimary.opacity(0.12))
                    )
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            appState.handleDrop(providers: providers)
        }
        .alert(loc["Ошибка библиотеки"], isPresented: $appState.isLibraryErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.libraryErrorMessage)
        }
    }
}

// MARK: - Top Header View

struct TopHeaderView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 16) {
            Spacer()

            // Единственная точка импорта. Конвертация живёт в тулбаре списка,
            // где выбирается формат — чтобы не было двух конкурирующих кнопок.
            Button {
                appState.presentImporter()
            } label: { Label(loc["Импорт"], systemImage: "plus") }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Theme.Colors.bgPrimary)
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    @EnvironmentObject private var loc: Localization
    var body: some View {
        ZStack {
            Theme.Colors.bgBase
            // Мягкий violet-ореол сверху — фирменная глубина фона.
            RadialGradient(colors: [Theme.Colors.accentPrimary.opacity(0.10), .clear],
                           center: .top, startRadius: 0, endRadius: 380)
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentPrimary.opacity(0.12))
                        .frame(width: 76, height: 76)
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Theme.Colors.accentBright)
                }

                Text(loc["Перетащите аудиофайлы или папки"])
                    .font(.inter(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("FLAC • WAV • AIFF • ALAC • MP3")
                    .font(.inter(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
    }
}

// MARK: - Library Toolbar View

struct LibraryToolbarView: View {
    @Binding var searchText: String
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 16) {

            if appState.selectedAudioFileCount > 1 {
                // Multi-Selection Toolbar
                Text("\(appState.selectedAudioFileCount) \(loc["выбрано"])")
                    .font(.inter(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accentBright)
                    .fixedSize(horizontal: true, vertical: false)

                conversionControls(compact: true)

                Button {
                    let urls = appState.selectedAudioFiles.map { $0.url }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } label: { Label("Finder", systemImage: "folder") }
                .labelStyle(.iconOnly)
                .buttonStyle(GhostButtonStyle())
                .disabled(appState.selectedAudioFileIDs.isEmpty)
                .help(loc["Показать в Finder"])

                Button {
                    if !appState.selectedAudioFileIDs.isEmpty {
                        appState.isDeleteConfirmationPresented = true
                    }
                } label: { Label(loc["Удалить"], systemImage: "trash") }
                .labelStyle(.iconOnly)
                .buttonStyle(DestructiveGhostButtonStyle())
                .disabled(appState.selectedAudioFileIDs.isEmpty)
                .help(loc["Удалить"])

                Button {
                    appState.deselectAll()
                } label: { Image(systemName: "xmark") }
                .buttonStyle(GhostButtonStyle())
                .help(loc["Отмена"])

            } else {
                // Single/Empty Toolbar
                conversionControls()
            }

            Spacer()

            // Поиск
            TextField(loc["Поиск треков"], text: $searchText)
                .textFieldStyle(SearchTextFieldStyle())
                .frame(width: 220)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.Colors.bgBase)
    }

    // Единые контролы конвертации: формат + «Конвертировать» + чип папки назначения.
    // В compact-режиме (панель массового выбора) кнопка «Конвертировать» сжимается
    // до иконки с tooltip, чтобы плотная панель не обрезалась.
    @ViewBuilder private func conversionControls(compact: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(loc["Формат:"])
                .font(.inter(size: 12))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: true, vertical: false)

            Picker("", selection: $conversionQueue.selectedTargetFormat) {
                ForEach(ConversionSettings.OutputFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .labelsHidden()
            .frame(width: 80)
        }

        Button {
            convertSelected()
        } label: { Label(loc["Конвертировать"], systemImage: "arrow.triangle.2.circlepath") }
        .labelStyle(AdaptiveLabelStyle(iconOnly: compact))
        .buttonStyle(AccentButtonStyle())
        .disabled(appState.selectedAudioFileIDs.isEmpty)
        .help(compact ? loc["Конвертировать"] : "")

        // Куда сохраняем: показываем запомненную папку и даём сменить одним кликом.
        if let folder = conversionQueue.lastOutputFolder {
            Button {
                changeDestination()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                    Text(folder.lastPathComponent).lineLimit(1)
                }
            }
            .buttonStyle(GhostButtonStyle())
            .help("\(loc["Папка назначения"]): \(folder.path)")
        }
    }

    private func convertSelected() {
        startConversion(files: appState.selectedAudioFiles, conversionQueue: conversionQueue, appState: appState)
    }

    private func changeDestination() {
        if let picked = selectDestinationFolder(startingAt: conversionQueue.lastOutputFolder) {
            conversionQueue.lastOutputFolder = picked
        }
    }
}

// MARK: - Track List View

struct TrackListView: View {
    let searchText: String
    var filterFolder: URL? = nil
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    @EnvironmentObject private var loc: Localization
    
    /// Source→destination for every finished conversion, computed once per queue
    /// change instead of scanning `jobs` inside every visible row's body.
    private var completedDestinations: [URL: URL] {
        var map: [URL: URL] = [:]
        for job in conversionQueue.jobs where job.status == .completed {
            map[job.sourceURL] = job.destinationURL
        }
        return map
    }
    
    private func statusColor(_ severity: AppViewModel.LibraryStatus.Severity) -> Color {
        switch severity {
        case .information: return Theme.Colors.textSecondary
        case .warning: return Theme.Colors.accentBright
        case .error: return Theme.Colors.destructive
        }
    }

    var body: some View {
        // Computed once per body evaluation via the model's derived helper —
        // no per-track string building, and referenced everywhere below instead
        // of recomputing the filter multiple times.
        let visibleLibrary = appState.filteredLibrary(searchText: searchText, filterFolder: filterFolder)
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("#").frame(width: 30, alignment: .leading)
                Text("").frame(width: 50, alignment: .center)
                Text(loc["НАЗВАНИЕ"]).frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                Text(loc["АРТИСТ"]).frame(width: 120, alignment: .leading)
                Text("KEY").frame(width: 50, alignment: .leading)
                Text("BPM").frame(width: 50, alignment: .trailing)
                Text(loc["ВРЕМЯ"]).frame(width: 60, alignment: .trailing)
                Text(loc["ФОРМАТ"]).frame(width: 60, alignment: .trailing)
                Text(loc["РАЗМЕР"]).frame(width: 60, alignment: .trailing)
            }
            .font(.inter(size: 10, weight: .semibold))
            .foregroundStyle(Theme.Colors.textMuted)
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .background(Theme.Colors.bgBase)
            
            Divider().background(Theme.Colors.border)
            
            if visibleLibrary.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text(appState.isLibraryProcessing ? loc["Готовим библиотеку…"] : loc["Треков не найдено"])
                        .font(.inter(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            } else {
                let destinations = completedDestinations
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visibleLibrary.enumerated()), id: \.element.id) { index, file in
                            TrackRowView(
                                index: index + 1,
                                file: file,
                                isSelected: appState.selectedAudioFileIDs.contains(file.id),
                                convertedDestination: destinations[file.url]
                            )
                            .contentShape(Rectangle())
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
                                appState.selectedAudioFileIDs = [file.id]
                                appState.requestedPlaybackTrackID = file.id
                            })
                            .simultaneousGesture(TapGesture(count: 1).onEnded {
                                let flags = NSEvent.modifierFlags
                                if flags.contains(.command) {
                                    appState.toggleSelection(for: file.id)
                                } else if flags.contains(.shift) {
                                    appState.selectRange(from: appState.lastSelectedTrackID, to: file.id, in: visibleLibrary)
                                } else {
                                    appState.selectedAudioFileIDs = [file.id]
                                    appState.lastSelectedTrackID = file.id
                                }
                            })
                            .contextMenu {
                                Button {
                                    appState.selectedAudioFileIDs = [file.id]
                                    appState.requestedPlaybackTrackID = file.id
                                } label: { Label(loc["Играть"], systemImage: "play.fill") }
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                } label: { Label(loc["Показать в Finder"], systemImage: "folder") }
                                Divider()
                                Button {
                                    let files = appState.selectedAudioFileIDs.contains(file.id)
                                        ? appState.selectedAudioFiles
                                        : [file]
                                    startConversion(files: files, conversionQueue: conversionQueue, appState: appState)
                                } label: { Label(loc["Конвертировать"], systemImage: "arrow.triangle.2.circlepath") }
                                Button {
                                    appState.selectedAudioFileIDs = [file.id]
                                    appState.lastSelectedTrackID = file.id
                                    appState.inspectorTab = .metadata
                                } label: { Label(loc["Изменить метаданные"], systemImage: "tag") }
                                Divider()
                                Button {
                                    appState.selectAll(in: visibleLibrary)
                                } label: { Label(loc["Выбрать всё"], systemImage: "checkmark.circle.fill") }
                                Button {
                                    appState.deselectAll()
                                } label: { Label(loc["Снять выделение"], systemImage: "circle") }
                                .disabled(appState.selectedAudioFileIDs.isEmpty)
                                Divider()
                                Button(role: .destructive) {
                                    if !appState.selectedAudioFileIDs.contains(file.id) {
                                        appState.selectedAudioFileIDs = [file.id]
                                    }
                                    appState.isDeleteConfirmationPresented = true
                                } label: { Label(loc["Убрать из библиотеки"], systemImage: "trash") }
                            }
                            Divider().background(Theme.Colors.border.opacity(0.5))
                        }
                    }
                }
            }
            
            // Нижний статус-бар
            HStack(spacing: 10) {
                Text("\(visibleLibrary.count) \(loc["треков"])")
                    .foregroundStyle(Theme.Colors.textMuted)

                if let status = appState.libraryStatus {
                    Circle()
                        .fill(statusColor(status.severity))
                        .frame(width: 5, height: 5)
                    Text(status.message)
                        .foregroundStyle(statusColor(status.severity))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
                if appState.isLibraryProcessing {
                    ProgressView().controlSize(.small)
                        .padding(.trailing, 8)
                }
            }
            .font(.inter(size: 11))
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Theme.Colors.bgBase)
        }
        .alert(loc["Убрать треки"], isPresented: $appState.isDeleteConfirmationPresented) {
            Button(loc["Отмена"], role: .cancel) { }
            Button(loc["Убрать"], role: .destructive) {
                appState.removeSelectedTracks()
            }
        } message: {
            Text("\(loc["Убрать из библиотеки"]) — \(appState.selectedAudioFileCount)?")
        }
        .background(
            ZStack {
                // Hidden button to catch Delete key
                Button("") {
                    if !appState.selectedAudioFileIDs.isEmpty {
                        appState.isDeleteConfirmationPresented = true
                    }
                }
                .keyboardShortcut(.delete, modifiers: [])
                
                // Play/Pause on Space
                Button("") {
                    appState.playbackToggleTrigger = UUID()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                // Up Arrow
                Button("") {
                    appState.selectPreviousTrack()
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                
                // Down Arrow
                Button("") {
                    appState.selectNextTrack()
                }
                .keyboardShortcut(.downArrow, modifiers: [])
            }
            .opacity(0)
        )
    }
}

// MARK: - Track Row View

struct TrackRowView: View {
    let index: Int
    let file: AudioFile
    let isSelected: Bool
    /// Destination of this track's finished conversion, if any. Passed down as a
    /// plain value so the row no longer observes the whole conversion queue —
    /// previously every row re-rendered on each job's progress tick.
    let convertedDestination: URL?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(Theme.Colors.textMuted)
            
            // Артворк
            Group {
                if let artworkURL = file.metadata.artworkLocation, let nsImage = RowContentCache.artwork(at: artworkURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .hairline(6, color: Theme.Colors.borderSubtle)
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.Colors.bgHover)
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "music.note")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Colors.textMuted))
                        .hairline(6, color: Theme.Colors.borderSubtle)
                }
            }
            .frame(width: 50, alignment: .center)
            
            HStack(spacing: 6) {
                Text(file.displayTitle)
                    .font(.inter(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                if let destinationURL = convertedDestination {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                    }) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Theme.Colors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal Converted File in Finder")
                }
            }
            .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
            
            Text(file.displayArtist)
                .frame(width: 120, alignment: .leading)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
            
            // Key Badge
            CamelotBadgeView(
                camelotKey: file.analysis?.camelotKey ?? file.analysis?.musicalKey?.camelotKey,
                isCompact: true
            )
            .frame(width: 50, alignment: .leading)
            
            Text(file.analysis?.bpm.map { String(format: "%.0f", $0) } ?? "-")
                .frame(width: 50, alignment: .trailing)
                .foregroundStyle(Theme.Colors.textSecondary)
            
            Text(file.displayDuration)
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monospacedDigit()
            
            Text(file.displayCodec)
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(Theme.Colors.textSecondary)
            
            Text(formatSize(RowContentCache.fileSize(for: file.url)))
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .font(.inter(size: 13))
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            ZStack(alignment: .leading) {
                if isSelected {
                    Theme.Colors.accentPrimary.opacity(0.12)
                    Rectangle().fill(Theme.Colors.accentGradient).frame(width: 2.5)
                } else if isHovered {
                    Theme.Colors.bgHover
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "-" }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Helpers

/// Общий путь конвертации для тулбара и контекстного меню: берёт запомненную
/// папку (или спрашивает впервые), ставит задания в очередь и открывает её.
@MainActor
func startConversion(files: [AudioFile], conversionQueue: ConversionQueueViewModel, appState: AppViewModel) {
    guard !files.isEmpty else { return }
    let folder: URL
    if let last = conversionQueue.lastOutputFolder, FileManager.default.fileExists(atPath: last.path) {
        folder = last
    } else {
        guard let picked = selectDestinationFolder(startingAt: conversionQueue.lastOutputFolder) else { return }
        folder = picked
    }
    conversionQueue.lastOutputFolder = folder

    // Conversion parameters now come from user preferences instead of being
    // hardcoded — output format from the toolbar picker, bitrate/metadata from
    // Settings. See AppSettings.conversionSettings(format:).
    let settings = AppSettings.shared.conversionSettings(format: conversionQueue.selectedTargetFormat)
    conversionQueue.enqueue(files: files, settings: settings, outputFolder: folder)
    appState.selectedSection = .conversion
}

func selectDestinationFolder(startingAt: URL? = nil) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Destination"
    if let startingAt { panel.directoryURL = startingAt }

    if panel.runModal() == .OK {
        return panel.url
    }
    return nil
}
