import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel

    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainLayoutView()
                // We use fileImporter here so it's attached to the main window
                .fileImporter(
                    isPresented: $appState.isImporterPresented,
                    allowedContentTypes: SupportedAudioFormat.importableContentTypes,
                    allowsMultipleSelection: true
                ) { result in
                    appState.handleFileImport(result)
                }
                .fileImporter(
                    isPresented: $appState.isArtworkImporterPresented,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    appState.handleArtworkImport(result)
                }

            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
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
