import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    var filterFolder: URL? = nil
    @EnvironmentObject private var appState: AppViewModel
    @State private var isDropTargeted = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            TopHeaderView()
            
            Divider().background(Theme.Colors.border)
            
            GeometryReader { geo in
                VStack(spacing: 0) {
                    DropZoneView()
                        .frame(height: geo.size.height * 0.45)
                    
                    Divider().background(Theme.Colors.border)
                    
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
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .strokeBorder(Theme.Colors.accentPrimary, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(Theme.Colors.accentPrimary.opacity(0.1))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            appState.handleDrop(providers: providers)
        }
        .alert("Library Error", isPresented: $appState.isLibraryErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.libraryErrorMessage)
        }
    }
}

// MARK: - Top Header View

struct TopHeaderView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            
            // Buttons
            Button("Import") {
                appState.presentImporter()
            }
            .buttonStyle(GhostButtonStyle())
            .frame(height: 36)
            
            Button("Convert to MP3 320") {
                guard let folder = selectDestinationFolder() else { return }
                conversionQueue.enqueue(files: appState.selectedAudioFiles, settings: .mp3_320CBR, outputFolder: folder)
                conversionQueue.startAll()
            }
            .buttonStyle(AccentButtonStyle())
            .frame(height: 36)
            .disabled(appState.selectedAudioFileIDs.isEmpty)
            .opacity(appState.selectedAudioFileIDs.isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.Colors.bgPrimary)
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    var body: some View {
        ZStack {
            Theme.Colors.bgBase
            
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Theme.Colors.accentPrimary)
                
                Text("Drop Audio Files or Folders Here")
                    .font(.inter(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                
                Text("FLAC • WAV • AIFF • ALAC • MP3")
                    .font(.inter(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Library Toolbar View

struct LibraryToolbarView: View {
    @Binding var searchText: String
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            
            if appState.isSelectionModeActive || appState.selectedAudioFileCount > 1 {
                // Multi-Selection Toolbar
                Text("\(appState.selectedAudioFileCount) selected")
                    .font(.inter(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.accentPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                
                HStack(spacing: 8) {
                    Text("Format:")
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
                
                Button("Convert Selected") {
                    guard let folder = selectDestinationFolder() else { return }
                    let settings = ConversionSettings(
                        outputFormat: conversionQueue.selectedTargetFormat,
                        bitrate: .constant(kilobitsPerSecond: 320),
                        preserveMetadata: true,
                        preserveArtwork: true,
                        preserveFolderStructure: true
                    )
                    conversionQueue.enqueue(files: appState.selectedAudioFiles, settings: settings, outputFolder: folder)
                    appState.selectedSection = .conversion
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(appState.selectedAudioFileIDs.isEmpty)
                
                Button("Reveal Selected") {
                    let urls = appState.selectedAudioFiles.map { $0.url }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(appState.selectedAudioFileIDs.isEmpty)
                
                Button("Delete Selected") {
                    if !appState.selectedAudioFileIDs.isEmpty {
                        appState.isDeleteConfirmationPresented = true
                    }
                }
                .buttonStyle(DestructiveGhostButtonStyle())
                .disabled(appState.selectedAudioFileIDs.isEmpty)
                
                Button("Cancel") {
                    appState.deselectAll()
                }
                .buttonStyle(GhostButtonStyle())
                
            } else {
                // Single/Empty Toolbar
                HStack(spacing: 8) {
                    Text("Format:")
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
                
                Button("Convert Selected") {
                    guard let folder = selectDestinationFolder() else { return }
                    let settings = ConversionSettings(
                        outputFormat: conversionQueue.selectedTargetFormat,
                        bitrate: .constant(kilobitsPerSecond: 320),
                        preserveMetadata: true,
                        preserveArtwork: true,
                        preserveFolderStructure: true
                    )
                    conversionQueue.enqueue(files: appState.selectedAudioFiles, settings: settings, outputFolder: folder)
                    appState.selectedSection = .conversion
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(appState.selectedAudioFileIDs.isEmpty)
            }
            
            Spacer()
            
            // Search
            TextField("Search tracks", text: $searchText)
                .textFieldStyle(SearchTextFieldStyle())
                .frame(width: 200)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.Colors.bgBase)
    }
}

// MARK: - Track List View

struct TrackListView: View {
    let searchText: String
    var filterFolder: URL? = nil
    @EnvironmentObject private var appState: AppViewModel
    
    private var filteredLibrary: [AudioFile] {
        var items = appState.library
        if let folder = filterFolder {
            items = items.filter { $0.url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL }
        }
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return items }
        return items.filter { $0.searchableText.localizedCaseInsensitiveContains(term) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                if appState.isSelectionModeActive {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundStyle(Color.clear)
                        .frame(width: 16)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                Text("#").frame(width: 30, alignment: .leading)
                Text("Artwork").frame(width: 50, alignment: .center)
                Text("Title").frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                Text("Artist").frame(width: 120, alignment: .leading)
                Text("Key").frame(width: 50, alignment: .leading)
                Text("BPM").frame(width: 50, alignment: .trailing)
                Text("Time").frame(width: 60, alignment: .trailing)
                Text("Format").frame(width: 60, alignment: .trailing)
                Text("Size").frame(width: 60, alignment: .trailing)
            }
            .font(.inter(size: 11, weight: .bold))
            .foregroundStyle(Theme.Colors.textMuted)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Theme.Colors.bgBase)
            
            Divider().background(Theme.Colors.border)
            
            if filteredLibrary.isEmpty {
                Spacer()
                Text(appState.isLibraryProcessing ? "Preparing library..." : "No tracks found")
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredLibrary.enumerated()), id: \.element.id) { index, file in
                            TrackRowView(
                                index: index + 1,
                                file: file,
                                isSelected: appState.selectedAudioFileIDs.contains(file.id)
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
                                    appState.selectRange(from: appState.lastSelectedTrackID, to: file.id, in: filteredLibrary)
                                } else {
                                    if appState.isSelectionModeActive {
                                        appState.toggleSelection(for: file.id)
                                    } else {
                                        appState.selectedAudioFileIDs = [file.id]
                                        appState.lastSelectedTrackID = file.id
                                    }
                                }
                            })
                            .contextMenu {
                                Button("Play") {
                                    appState.selectedAudioFileIDs = [file.id]
                                    appState.requestedPlaybackTrackID = file.id
                                }
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                }
                                Divider()
                                Button("Select") {
                                    appState.isSelectionModeActive = true
                                    appState.selectedAudioFileIDs = [file.id]
                                    appState.lastSelectedTrackID = file.id
                                }
                                Button("Select All") {
                                    appState.selectAll(in: filteredLibrary)
                                }
                                Button("Deselect All") {
                                    appState.deselectAll()
                                }
                                Divider()
                                Button("Remove from Library") {
                                    if !appState.selectedAudioFileIDs.contains(file.id) {
                                        appState.selectedAudioFileIDs = [file.id]
                                    }
                                    appState.isDeleteConfirmationPresented = true
                                }
                            }
                            Divider().background(Theme.Colors.border.opacity(0.5))
                        }
                    }
                }
            }
            
            // Bottom Status Bar
            HStack {
                Text("\(filteredLibrary.count) tracks")
                Spacer()
                if appState.isLibraryProcessing {
                    ProgressView().controlSize(.small)
                        .padding(.trailing, 8)
                }
            }
            .font(.inter(size: 11))
            .foregroundStyle(Theme.Colors.textMuted)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Theme.Colors.bgBase)
        }
        .alert("Remove Tracks", isPresented: $appState.isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                appState.removeSelectedTracks()
            }
        } message: {
            Text("Are you sure you want to remove the selected \(appState.selectedAudioFileCount) tracks from the library?")
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
    
    @State private var isHovered = false
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            if appState.isSelectionModeActive {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : Theme.Colors.textMuted)
                    .frame(width: 16)
                    .onTapGesture {
                        appState.toggleSelection(for: file.id)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Text("\(index)")
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(Theme.Colors.textMuted)
            
            // Artwork
            if let artworkURL = file.metadata.artworkLocation, let nsImage = NSImage(contentsOf: artworkURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .frame(width: 50, alignment: .center)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.bgHover)
                    .frame(width: 32, height: 32)
                    .frame(width: 50, alignment: .center)
            }
            
            HStack(spacing: 6) {
                Text(file.displayTitle)
                    .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                if let job = conversionQueue.jobs.first(where: { $0.sourceURL == file.url && $0.status == .completed }) {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([job.destinationURL])
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
                .foregroundStyle(isSelected ? Theme.Colors.accentPrimary.opacity(0.8) : Theme.Colors.textSecondary)
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
            
            Text(formatSize(getFileSize(file.url)))
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .font(.inter(size: 13))
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.Colors.bgSelected : (isHovered ? Theme.Colors.bgHover : Color.clear))
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
    
    private func getFileSize(_ url: URL) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return 0 }
        return size
    }
}

// MARK: - Helpers

func selectDestinationFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Destination"
    
    if panel.runModal() == .OK {
        return panel.url
    }
    return nil
}
