import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel

    var body: some View {
        MainLayoutView()
            // We use fileImporter here so it's attached to the main window
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
                .font(.inter(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
