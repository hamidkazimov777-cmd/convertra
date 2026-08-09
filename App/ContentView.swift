import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppViewModel

    var body: some View {
        HSplitView {
            List(AppViewModel.Section.allCases, selection: $appState.selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, idealWidth: 210, maxWidth: 260)

            Group {
                switch appState.selectedSection ?? .library {
                case .library:
                    LibraryView()
                case .conversion:
                    FeaturePlaceholderView(
                        title: "Conversion Queue",
                        message: "Lossless-to-MP3 conversion jobs will appear here.",
                        image: "arrow.triangle.2.circlepath"
                    )
                case .metadata:
                    MetadataEditorView()
                case .player:
                    PlayerView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.presentImporter()
                } label: {
                    Label("Add Audio", systemImage: "plus")
                }
                .disabled(appState.isLibraryProcessing)
                .help("Add supported audio files or folders")
            }
        }
        .fileImporter(
            isPresented: $appState.isImporterPresented,
            allowedContentTypes: SupportedAudioFormat.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            appState.handleFileImport(result)
        }
    }
}

private struct FeaturePlaceholderView: View {
    let title: String
    let message: String
    let image: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: image)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
