import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var appState: AppViewModel
    @State private var isDropTargeted = false

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

            if let status = appState.libraryStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
    }

    private var trackList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(appState.library.count) track\(appState.library.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
                if appState.isLibraryProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.isAnalyzingTechnicalMetadata ? "Analyzing…" : "Scanning…")
                        .foregroundStyle(.secondary)
                }
                Button("Add Audio") {
                    appState.presentImporter()
                }
                    .disabled(appState.isLibraryProcessing)
            }
            .padding()

            if let status = appState.libraryStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            List(appState.library) { audioFile in
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioFile.fileName)
                        Text(audioFile.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let analysis = audioFile.analysis, !analysis.technicalSummary.isEmpty {
                            Text(analysis.technicalSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Technical metadata unavailable")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Text(audioFile.url.pathExtension.uppercased())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
