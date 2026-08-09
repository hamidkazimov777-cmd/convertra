import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    struct LibraryStatus: Equatable {
        enum Severity: Equatable {
            case information
            case warning
            case error
        }

        let message: String
        let severity: Severity
    }

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
    @Published var selectedAudioFileIDs = Set<AudioFile.ID>()
    @Published var isImporterPresented = false
    @Published private(set) var isScanningLibrary = false
    @Published private(set) var isAnalyzingTechnicalMetadata = false
    @Published private(set) var libraryStatus: LibraryStatus?
    @Published var isLibraryErrorPresented = false
    @Published private(set) var libraryErrorMessage = ""

    private let libraryScanner = AudioLibraryScanner()
    private let technicalMetadataExtractor = AudioTechnicalMetadataExtractor()

    var isLibraryProcessing: Bool {
        isScanningLibrary || isAnalyzingTechnicalMetadata
    }

    var supportedFileTypesDescription: String {
        "WAV, AIFF, FLAC, ALAC, MP3, AAC, and M4A"
    }

    var selectedAudioFileCount: Int {
        selectedAudioFileIDs.count
    }

    func presentImporter() {
        isImporterPresented = true
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            Task { await scanAndAdd(urls: urls) }
        case let .failure(error):
            presentLibraryError("Could not access the selected items: \(error.localizedDescription)")
        }
    }

    func clearLibrarySelection() {
        selectedAudioFileIDs.removeAll()
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileURLProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !fileURLProviders.isEmpty, !isLibraryProcessing else { return false }

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
            presentLibraryError("No accessible files or folders were provided.")
            return
        }

        let scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        isScanningLibrary = true
        setLibraryStatus(
            "Scanning \(urls.count) selected item\(urls.count == 1 ? "" : "s")…",
            severity: .information
        )

        let result = await libraryScanner.scan(urls: urls)
        let existingURLs = Set(library.map { $0.url.standardizedFileURL })
        let newFiles = result.audioURLs
            .filter { !existingURLs.contains($0.standardizedFileURL) }
            .map { AudioFile(url: $0) }

        library.append(contentsOf: newFiles)
        isScanningLibrary = false

        let addedCount = newFiles.count
        if addedCount == 0 {
            setLibraryStatus(
                "No new supported audio files found. Skipped \(result.skippedItemCount) unsupported or inaccessible item\(result.skippedItemCount == 1 ? "" : "s").",
                severity: .warning
            )
            return
        }

        isAnalyzingTechnicalMetadata = true
        setLibraryStatus(
            "Reading technical metadata for \(addedCount) track\(addedCount == 1 ? "" : "s")…",
            severity: .information
        )
        let analysisResults = await technicalMetadataExtractor.analyze(urls: newFiles.map(\.url))
        let analysesByURL = Dictionary(
            analysisResults.compactMap { result in
                result.analysis.map { (result.url.standardizedFileURL, $0) }
            },
            uniquingKeysWith: { latest, _ in latest }
        )

        library = library.map { audioFile in
            var updatedFile = audioFile
            updatedFile.analysis = analysesByURL[audioFile.url.standardizedFileURL] ?? audioFile.analysis
            return updatedFile
        }
        isAnalyzingTechnicalMetadata = false

        let analyzedCount = analysesByURL.count
        let failedAnalysisCount = addedCount - analyzedCount
        let skippedDescription = result.skippedItemCount > 0
            ? " Skipped \(result.skippedItemCount) unsupported or inaccessible item\(result.skippedItemCount == 1 ? "" : "s")."
            : ""
        let analysisDescription = failedAnalysisCount > 0
            ? " Technical metadata was unavailable for \(failedAnalysisCount) track\(failedAnalysisCount == 1 ? "" : "s")."
            : " Read technical metadata for all tracks."
        setLibraryStatus(
            "Added \(addedCount) track\(addedCount == 1 ? "" : "s").\(analysisDescription)\(skippedDescription)",
            severity: failedAnalysisCount > 0 || result.skippedItemCount > 0 ? .warning : .information
        )
    }

    private func setLibraryStatus(_ message: String, severity: LibraryStatus.Severity) {
        libraryStatus = LibraryStatus(message: message, severity: severity)
    }

    private func presentLibraryError(_ message: String) {
        libraryErrorMessage = message
        setLibraryStatus(message, severity: .error)
        isLibraryErrorPresented = true
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
