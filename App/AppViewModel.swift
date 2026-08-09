import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case library = "Library"
        case conversion = "Conversion"
        case metadata = "Metadata"
        case player = "Player"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .library: return "music.note.list"
            case .conversion: return "arrow.triangle.2.circlepath"
            case .metadata: return "tag"
            case .player: return "play.circle"
            }
        }
    }

    @Published var selectedSection: Section? = .library
    @Published private(set) var library: [AudioFile] = []
    @Published var isImporterPresented = false
    @Published private(set) var isScanningLibrary = false
    @Published private(set) var libraryStatusMessage: String?

    private let libraryScanner = AudioLibraryScanner()

    var supportedFileTypesDescription: String {
        "WAV, AIFF, FLAC, ALAC, MP3, AAC, and M4A"
    }

    func presentImporter() {
        isImporterPresented = true
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            Task { await scanAndAdd(urls: urls) }
        case let .failure(error):
            libraryStatusMessage = "Could not access the selected items: \(error.localizedDescription)"
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileURLProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !fileURLProviders.isEmpty, !isScanningLibrary else { return false }

        Task { [weak self] in
            let urls = await fileURLProviders.asyncCompactMap { provider in
                await Self.url(from: provider)
            }
            await self?.scanAndAdd(urls: urls)
        }
        return true
    }

    private func scanAndAdd(urls: [URL]) async {
        guard !urls.isEmpty else {
            libraryStatusMessage = "No accessible files or folders were provided."
            return
        }

        isScanningLibrary = true
        libraryStatusMessage = "Scanning \(urls.count) selected item\(urls.count == 1 ? "" : "s")…"

        let result = await libraryScanner.scan(urls: urls)
        let existingURLs = Set(library.map { $0.url.standardizedFileURL })
        let newFiles = result.audioURLs
            .filter { !existingURLs.contains($0.standardizedFileURL) }
            .map { AudioFile(url: $0) }

        library.append(contentsOf: newFiles)
        isScanningLibrary = false

        let addedCount = newFiles.count
        if addedCount == 0 {
            libraryStatusMessage = "No new supported audio files found."
        } else {
            libraryStatusMessage = "Added \(addedCount) track\(addedCount == 1 ? "" : "s")."
        }
    }

    private static func url(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }
}

private extension Array {
    func asyncCompactMap<T>(_ transform: (Element) async -> T?) async -> [T] {
        var results: [T] = []
        for element in self {
            if let value = await transform(element) {
                results.append(value)
            }
        }
        return results
    }
}
