import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    private enum SortColumn {
        case title
        case artist
        case duration
        case bpm
        case key
        case sampleRate
        case bitrate
        case codec
    }

    @EnvironmentObject private var appState: AppViewModel
    @State private var isDropTargeted = false
    @State private var searchText = ""
    @State private var sortColumn: SortColumn = .title
    @State private var isAscending = true

    var body: some View {
        Group {
            if appState.library.isEmpty {
                emptyState
            } else {
                trackList
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(16)
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
        .navigationTitle("Library")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: appState.isLibraryProcessing ? "magnifyingglass" : "waveform")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)

            Text(appState.isLibraryProcessing ? "Preparing your audio…" : "Your audio library is ready")
                .font(.title2.weight(.semibold))

            Text("Drop audio files or folders here, or choose them from Finder.")
                .foregroundStyle(.secondary)

            Button("Add Audio Files or Folders…") {
                appState.presentImporter()
            }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isLibraryProcessing)

            Text("Supported formats: \(appState.supportedFileTypesDescription)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let status = appState.libraryStatus {
                statusBanner(status)
            }
        }
        .padding(40)
    }

    private var trackList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(appState.library.count) track\(appState.library.count == 1 ? "" : "s")")
                    .font(.headline)
                if appState.selectedAudioFileCount > 0 {
                    Text("\(appState.selectedAudioFileCount) selected")
                        .foregroundStyle(.secondary)
                    Button("Clear Selection") {
                        appState.clearLibrarySelection()
                    }
                    .buttonStyle(.link)
                }
                Spacer()
                if appState.isLibraryProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text(processingLabel)
                        .foregroundStyle(.secondary)
                }
                TextField("Search library", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                Button("Add Audio") {
                    appState.presentImporter()
                }
                    .disabled(appState.isLibraryProcessing)
            }
            .padding()

            if let status = appState.libraryStatus {
                statusBanner(status)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            columnHeader

            List(filteredAndSortedLibrary, selection: $appState.selectedAudioFileIDs) { audioFile in
                trackRow(audioFile)
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 20)
            sortButton("Title", column: .title)
                .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)
            sortButton("Artist", column: .artist)
                .frame(width: 150, alignment: .leading)
            sortButton("Duration", column: .duration)
                .frame(width: 70, alignment: .trailing)
            sortButton("BPM", column: .bpm)
                .frame(width: 45, alignment: .trailing)
            sortButton("Key", column: .key)
                .frame(width: 65, alignment: .leading)
            sortButton("Rate", column: .sampleRate)
                .frame(width: 70, alignment: .trailing)
            sortButton("Bitrate", column: .bitrate)
                .frame(width: 75, alignment: .trailing)
            sortButton("Codec", column: .codec)
                .frame(width: 65, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }

    private func trackRow(_ audioFile: AudioFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(audioFile.displayTitle)
                    .lineLimit(1)
                Text(audioFile.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)
            Text(audioFile.displayArtist)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Text(audioFile.displayDuration)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text(audioFile.analysis?.bpm.map { String(format: "%.0f", $0) } ?? "-")
                .monospacedDigit()
                .foregroundStyle(audioFile.analysis?.bpm == nil ? .secondary : .primary)
                .frame(width: 45, alignment: .trailing)
            Text(audioFile.analysis?.musicalKey?.rawValue ?? "-")
                .foregroundStyle(audioFile.analysis?.musicalKey == nil ? .secondary : .primary)
                .frame(width: 65, alignment: .leading)
            Text(audioFile.displaySampleRate)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text(audioFile.displayBitrate)
                .monospacedDigit()
                .frame(width: 75, alignment: .trailing)
            Text(audioFile.displayCodec)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var filteredAndSortedLibrary: [AudioFile] {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredLibrary = searchTerm.isEmpty
            ? appState.library
            : appState.library.filter { $0.searchableText.localizedCaseInsensitiveContains(searchTerm) }

        return filteredLibrary.sorted(by: isOrdered)
    }

    private func sortButton(_ title: String, column: SortColumn) -> some View {
        Button {
            if sortColumn == column {
                isAscending.toggle()
            } else {
                sortColumn = column
                isAscending = true
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if sortColumn == column {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func isOrdered(_ lhs: AudioFile, _ rhs: AudioFile) -> Bool {
        let result: ComparisonResult
        switch sortColumn {
        case .title:
            result = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)
        case .artist:
            result = lhs.displayArtist.localizedCaseInsensitiveCompare(rhs.displayArtist)
        case .duration:
            result = compare(lhs.analysis?.duration ?? 0, rhs.analysis?.duration ?? 0)
        case .bpm:
            result = compare(lhs.analysis?.bpm ?? 0, rhs.analysis?.bpm ?? 0)
        case .key:
            result = (lhs.analysis?.musicalKey?.rawValue ?? "").localizedCaseInsensitiveCompare(rhs.analysis?.musicalKey?.rawValue ?? "")
        case .sampleRate:
            result = compare(lhs.analysis?.sampleRate ?? 0, rhs.analysis?.sampleRate ?? 0)
        case .bitrate:
            result = compare(lhs.analysis?.bitrate ?? 0, rhs.analysis?.bitrate ?? 0)
        case .codec:
            result = lhs.displayCodec.localizedCaseInsensitiveCompare(rhs.displayCodec)
        }

        if result == .orderedSame {
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
        return isAscending ? result == .orderedAscending : result == .orderedDescending
    }

    private func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func statusBanner(_ status: AppViewModel.LibraryStatus) -> some View {
        HStack(spacing: 7) {
            Image(systemName: statusIcon(for: status.severity))
            Text(status.message)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(statusColor(for: status.severity))
    }

    private func statusIcon(for severity: AppViewModel.LibraryStatus.Severity) -> String {
        switch severity {
        case .information: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    private func statusColor(for severity: AppViewModel.LibraryStatus.Severity) -> Color {
        switch severity {
        case .information: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var processingLabel: String {
        if appState.isRestoringLibrary { return "Restoring…" }
        if appState.isAnalyzingTechnicalMetadata { return "Analyzing…" }
        if appState.isReadingMetadata { return "Reading Tags…" }
        return "Scanning…"
    }
}
