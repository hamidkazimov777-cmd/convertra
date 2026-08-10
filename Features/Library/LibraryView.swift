import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
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
                        TrackListView(searchText: searchText)
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
                conversionQueue.enqueue(files: appState.selectedAudioFiles, settings: .mp3_320CBR)
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
    
    var body: some View {
        HStack(spacing: 16) {
            // View Toggles Placeholder
            HStack(spacing: 0) {
                Image(systemName: "list.bullet")
                    .padding(6)
                    .background(Theme.Colors.bgSelected)
                Image(systemName: "square.grid.2x2")
                    .padding(6)
            }
            .font(.inter(size: 12))
            .foregroundStyle(Theme.Colors.textPrimary)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.Colors.border, lineWidth: 1))
            
            Spacer()
            
            // Filters Placeholder
            HStack(spacing: 12) {
                Text("All Formats ▾")
                Text("All Keys ▾")
                Text("All BPM ▾")
            }
            .font(.inter(size: 12))
            .foregroundStyle(Theme.Colors.textSecondary)
            
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
    @EnvironmentObject private var appState: AppViewModel
    
    private var filteredLibrary: [AudioFile] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return appState.library }
        return appState.library.filter { $0.searchableText.localizedCaseInsensitiveContains(term) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("#").frame(width: 30, alignment: .leading)
                Text("Artwork").frame(width: 50, alignment: .center)
                Text("Title").frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                Text("Artist").frame(width: 120, alignment: .leading)
                Text("Key").frame(width: 50, alignment: .leading)
                Text("BPM").frame(width: 50, alignment: .trailing)
                Text("Time").frame(width: 60, alignment: .trailing)
                Text("Format").frame(width: 60, alignment: .trailing)
                Text("Size").frame(width: 60, alignment: .trailing)
                Text("").frame(width: 20)
            }
            .font(.inter(size: 11, weight: .bold))
            .foregroundStyle(Theme.Colors.textMuted)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Theme.Colors.bgBase)
            
            Divider().background(Theme.Colors.border)
            
            if appState.library.isEmpty {
                Spacer()
                Text(appState.isLibraryProcessing ? "Preparing library..." : "Library is empty")
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
                            .onTapGesture {
                                appState.selectedAudioFileIDs = [file.id]
                            }
                            Divider().background(Theme.Colors.border.opacity(0.5))
                        }
                    }
                }
            }
            
            // Bottom Status Bar
            HStack {
                Text("\(appState.library.count) tracks")
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
    }
}

// MARK: - Track Row View

struct TrackRowView: View {
    let index: Int
    let file: AudioFile
    let isSelected: Bool
    
    @State private var isHovered = false
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    
    var body: some View {
        HStack(spacing: 12) {
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
            Text(file.analysis?.musicalKey?.rawValue ?? "-")
                .font(.inter(size: 10, weight: .bold))
                .foregroundStyle(file.analysis?.musicalKey == nil ? Theme.Colors.textMuted : Theme.Colors.bgBase)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(file.analysis?.musicalKey == nil ? Color.clear : Theme.Colors.accentPrimary)
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
            
            Image(systemName: "ellipsis")
                .frame(width: 20)
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
