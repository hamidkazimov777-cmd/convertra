import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel

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
                    ConversionQueueView()
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
            
            ToolbarItem(placement: .automatic) {
                Button {
                    conversionQueue.enqueue(files: appState.selectedAudioFiles, settings: .mp3_320CBR)
                    appState.selectedSection = .conversion
                } label: {
                    Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.selectedAudioFileIDs.isEmpty || appState.isLibraryProcessing)
                .help("Add selected tracks to the conversion queue")
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

struct FeaturePlaceholderView: View {
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
