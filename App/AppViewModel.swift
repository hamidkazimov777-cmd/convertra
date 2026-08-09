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
    @Published private(set) var isRestoringLibrary = true
    @Published private(set) var isScanningLibrary = false
    @Published private(set) var isAnalyzingTechnicalMetadata = false
    @Published private(set) var isReadingMetadata = false
    @Published private(set) var libraryStatus: LibraryStatus?
    @Published var isLibraryErrorPresented = false
    @Published private(set) var libraryErrorMessage = ""

    private let libraryScanner = AudioLibraryScanner()
    private let technicalMetadataExtractor = AudioTechnicalMetadataExtractor()
    private let metadataExtractor = AudioMetadataExtractor()
    private let libraryPersistenceStore = LibraryPersistenceStore()
    private var sourceBookmarks: [Data] = []
    private var trackBookmarks: [AudioFile.ID: Data] = [:]

    init() {
        Task { [weak self] in
            await self?.restorePersistedLibrary()
        }
    }

    var isLibraryProcessing: Bool {
        isRestoringLibrary || isScanningLibrary || isAnalyzingTechnicalMetadata || isReadingMetadata
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
        guard !isLibraryProcessing else {
            setLibraryStatus("Library is busy. Please wait for the current operation to finish.", severity: .warning)
            return
        }

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

        isReadingMetadata = true
        setLibraryStatus(
            "Reading tags and artwork for \(addedCount) track\(addedCount == 1 ? "" : "s")…",
            severity: .information
        )
        let metadataResults = await metadataExtractor.read(files: newFiles)
        let metadataByAudioFileID = Dictionary(
            metadataResults.compactMap { result in
                result.metadata.map { (result.audioFileID, $0) }
            },
            uniquingKeysWith: { latest, _ in latest }
        )
        library = library.map { audioFile in
            guard let readMetadata = metadataByAudioFileID[audioFile.id] else { return audioFile }
            var updatedFile = audioFile
            updatedFile.metadata = audioFile.metadata.merged(with: readMetadata)
            return updatedFile
        }
        isReadingMetadata = false

        let newSourceBookmarks = await libraryPersistenceStore.bookmarkData(for: urls)
        for bookmark in newSourceBookmarks.values where !sourceBookmarks.contains(bookmark) {
            sourceBookmarks.append(bookmark)
        }
        let newTrackBookmarks = await libraryPersistenceStore.bookmarkData(for: newFiles.map(\.url))
        for audioFile in newFiles {
            if let bookmark = newTrackBookmarks[audioFile.url.standardizedFileURL] {
                trackBookmarks[audioFile.id] = bookmark
            }
        }

        let analyzedCount = analysesByURL.count
        let failedAnalysisCount = addedCount - analyzedCount
        let metadataReadCount = metadataByAudioFileID.count
        let failedMetadataReadCount = addedCount - metadataReadCount
        let skippedDescription = result.skippedItemCount > 0
            ? " Skipped \(result.skippedItemCount) unsupported or inaccessible item\(result.skippedItemCount == 1 ? "" : "s")."
            : ""
        let analysisDescription = failedAnalysisCount > 0
            ? " Technical metadata was unavailable for \(failedAnalysisCount) track\(failedAnalysisCount == 1 ? "" : "s")."
            : " Read technical metadata for all tracks."
        let metadataDescription = failedMetadataReadCount > 0
            ? " Metadata was unavailable for \(failedMetadataReadCount) track\(failedMetadataReadCount == 1 ? "" : "s")."
            : " Read tags for \(metadataReadCount) track\(metadataReadCount == 1 ? "" : "s")."
        let wasSaved = await persistLibrary()
        let persistenceDescription = wasSaved
            ? " Library saved locally."
            : " The library could not be saved locally."
        setLibraryStatus(
            "Added \(addedCount) track\(addedCount == 1 ? "" : "s").\(analysisDescription)\(metadataDescription)\(skippedDescription)\(persistenceDescription)",
            severity: failedAnalysisCount > 0 || failedMetadataReadCount > 0 || result.skippedItemCount > 0 || !wasSaved ? .warning : .information
        )
    }

    private func restorePersistedLibrary() async {
        setLibraryStatus("Restoring saved library…", severity: .information)

        do {
            guard let snapshot = try await libraryPersistenceStore.load() else {
                libraryStatus = nil
                isRestoringLibrary = false
                return
            }

            let restoration = await libraryPersistenceStore.restore(snapshot)
            library = restoration.tracks.map(\.audioFile)
            sourceBookmarks = snapshot.sourceBookmarks
            trackBookmarks = Dictionary(
                restoration.tracks.compactMap { track in
                    track.bookmarkData.map { (track.audioFile.id, $0) }
                },
                uniquingKeysWith: { latest, _ in latest }
            )
            selectedAudioFileIDs.removeAll()

            if restoration.unavailableTrackCount > 0 {
                setLibraryStatus(
                    "Restored \(library.count) track\(library.count == 1 ? "" : "s"). \(restoration.unavailableTrackCount) saved track\(restoration.unavailableTrackCount == 1 ? " was" : "s were") unavailable.",
                    severity: .warning
                )
            } else {
                setLibraryStatus(
                    "Restored \(library.count) track\(library.count == 1 ? "" : "s") from the saved library.",
                    severity: .information
                )
            }
        } catch {
            setLibraryStatus(
                "Saved library could not be restored: \(error.localizedDescription)",
                severity: .error
            )
        }

        isRestoringLibrary = false
    }

    private func persistLibrary() async -> Bool {
        let snapshot = LibraryPersistenceSnapshot(
            sourceBookmarks: sourceBookmarks,
            tracks: library.map { audioFile in
                PersistedLibraryTrack(
                    audioFile: audioFile,
                    bookmarkData: trackBookmarks[audioFile.id]
                )
            }
        )

        do {
            try await libraryPersistenceStore.save(snapshot)
            return true
        } catch {
            return false
        }
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
