import SwiftUI
import AppKit

/// Guarantees the host window keeps the standard macOS traffic-light controls
/// (close / minimize / zoom) and stays resizable, while the title bar itself
/// remains transparent so the dark UI runs edge to edge.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
}

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
        .background(WindowConfigurator())
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
