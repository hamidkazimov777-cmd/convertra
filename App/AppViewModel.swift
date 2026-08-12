import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit

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

    enum NavigationSelection: Equatable, Hashable {
        case library
        case conversion
        case duplicates
        case settings
        case folder(URL)
    }

    enum InspectorTab: Equatable {
        case info
        case metadata
    }

    @Published var selectedSection: NavigationSelection = .library
    @Published var inspectorTab: InspectorTab = .info
    @Published private(set) var library: [AudioFile] = [] {
        didSet { rebuildSearchIndex() }
    }

    /// Lowercased searchable text per track, rebuilt only when `library` itself
    /// changes. Filtering used to call `AudioFile.searchableText` — which builds
    /// a fresh joined string — for every track on every keystroke *and* on every
    /// unrelated `body` re-eval (e.g. changing the selection). Prebuilding the
    /// strings once per library mutation turns filtering into cheap dictionary
    /// lookups. It can never go stale because every path that edits a track
    /// reassigns `library`, which re-triggers the `didSet`.
    private var searchIndex: [AudioFile.ID: String] = [:]
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published var selectedAudioFileIDs = Set<AudioFile.ID>()
    @Published var lastSelectedTrackID: AudioFile.ID?
    @Published var requestedPlaybackTrackID: AudioFile.ID?
    @Published var playbackToggleTrigger: UUID = UUID()
    @Published var metadataEditDraft = MetadataEditDraft()
    @Published var isImporterPresented = false
    @Published var isArtworkImporterPresented = false
    @Published private(set) var isRestoringLibrary = true
    @Published private(set) var isScanningLibrary = false
    @Published private(set) var isAnalyzingTechnicalMetadata = false
    @Published private(set) var isReadingMetadata = false
    @Published private(set) var isApplyingMetadataEdits = false
    
    // Folder management state
    @Published var folderToDelete: URL?
    @Published var showingDeleteAlert = false
    @Published var folderToRename: URL?
    @Published var showingRenameSheet = false
    @Published var newFolderName = ""
    @Published private(set) var libraryStatus: LibraryStatus?
    @Published var isLibraryErrorPresented = false
    @Published private(set) var libraryErrorMessage = ""
    @Published var isDeleteConfirmationPresented = false
    @Published var folderAliases: [URL: String] = [:]

    private let libraryScanner = AudioLibraryScanner()
    private let technicalMetadataExtractor = AudioTechnicalMetadataExtractor()
    private let metadataExtractor = AudioMetadataExtractor()
    private let artworkCache = ArtworkCache()
    private let libraryPersistenceStore = LibraryPersistenceStore()
    private let metadataWriter = AudioMetadataWriter()
    private let duplicateDetector = DuplicateDetector()
    private var sourceBookmarks: [Data] = []
    private var trackBookmarks: [AudioFile.ID: Data] = [:]

    /// Localized status/error strings share the UI language.
    private var loc: Localization { .shared }

    init() {
        Task { [weak self] in
            await self?.restorePersistedLibrary()
        }
    }

    var isLibraryProcessing: Bool {
        isRestoringLibrary || isScanningLibrary || isAnalyzingTechnicalMetadata || isReadingMetadata || isApplyingMetadataEdits
    }

    var supportedFileTypesDescription: String {
        "WAV, AIFF, FLAC, ALAC, MP3, AAC, and M4A"
    }

    var libraryFolders: [URL] {
        let urls = library.map { $0.url.deletingLastPathComponent().standardizedFileURL }
        return Array(Set(urls)).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    var selectedAudioFileCount: Int {
        selectedAudioFileIDs.count
    }

    var selectedAudioFiles: [AudioFile] {
        library.filter { selectedAudioFileIDs.contains($0.id) }
    }

    private func rebuildSearchIndex() {
        var index: [AudioFile.ID: String] = [:]
        index.reserveCapacity(library.count)
        for file in library {
            index[file.id] = file.searchableText.lowercased()
        }
        searchIndex = index
    }

    /// Derived, filtered view of the library for a list pane. Lives on the model
    /// (not recomputed inside a SwiftUI `body`) so that selecting a track — which
    /// republishes `AppViewModel` but leaves `library` untouched — no longer
    /// re-runs an `O(n)` filter that rebuilds a searchable string per track.
    /// The empty-search path (the common case) returns the folder slice without
    /// touching the index at all.
    func filteredLibrary(searchText: String, filterFolder: URL?) -> [AudioFile] {
        var items = library
        if let folder = filterFolder {
            let target = folder.standardizedFileURL
            items = items.filter { $0.url.deletingLastPathComponent().standardizedFileURL == target }
        }

        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return items }
        return items.filter { (searchIndex[$0.id] ?? "").contains(term) }
    }

    func presentImporter() {
        isImporterPresented = true
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        guard !isLibraryProcessing else {
            setLibraryStatus(loc["Библиотека занята. Дождитесь завершения текущей операции."], severity: .warning)
            return
        }

        switch result {
        case let .success(urls):
            Task { await scanAndAdd(urls: urls) }
        case let .failure(error):
            presentLibraryError(String(format: loc["Не удалось получить доступ к выбранным объектам: %@"], error.localizedDescription))
        }
    }

    func clearLibrarySelection() {
        selectedAudioFileIDs.removeAll()
        lastSelectedTrackID = nil
    }

    func selectNextTrack() {
        guard let currentId = selectedAudioFileIDs.first,
              let currentIndex = library.firstIndex(where: { $0.id == currentId }),
              currentIndex + 1 < library.count else { return }
        
        selectedAudioFileIDs = [library[currentIndex + 1].id]
    }
    
    func selectPreviousTrack() {
        guard let currentId = selectedAudioFileIDs.first,
              let currentIndex = library.firstIndex(where: { $0.id == currentId }) else { return }
        
        if currentIndex > 0 {
            selectedAudioFileIDs = [library[currentIndex - 1].id]
        } else {
            // If it's the first track, we could either do nothing or just keep it selected
            // BottomPlayerView's engine seek to 0 will be handled by the player view model if we trigger it
            // For now, we'll just re-select it
            selectedAudioFileIDs = [library[0].id]
        }
    }
    
    func removeSelectedTracks() {
        let selectedIDs = selectedAudioFileIDs
        library.removeAll { selectedIDs.contains($0.id) }
        
        for id in selectedIDs {
            trackBookmarks.removeValue(forKey: id)
        }
        
        selectedAudioFileIDs.removeAll()
        lastSelectedTrackID = nil
        analyzeForDuplicates()
        Task { await persistLibrary() }
    }

    func clearLibrary() {
        library.removeAll()
        selectedAudioFileIDs.removeAll()
        lastSelectedTrackID = nil
        sourceBookmarks.removeAll()
        trackBookmarks.removeAll()
        analyzeForDuplicates()
        Task { await persistLibrary() }
    }
    
    // MARK: - Multi-Selection Logic
    
    func toggleSelection(for id: AudioFile.ID) {
        if selectedAudioFileIDs.contains(id) {
            selectedAudioFileIDs.remove(id)
        } else {
            selectedAudioFileIDs.insert(id)
            lastSelectedTrackID = id
        }
    }
    
    func selectRange(from startID: AudioFile.ID?, to endID: AudioFile.ID, in filteredLibrary: [AudioFile]) {
        guard let start = startID,
              let startIndex = filteredLibrary.firstIndex(where: { $0.id == start }),
              let endIndex = filteredLibrary.firstIndex(where: { $0.id == endID }) else {
            // Fallback to normal selection if start ID is lost
            selectedAudioFileIDs = [endID]
            lastSelectedTrackID = endID
            return
        }
        
        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        let idsToSelect = filteredLibrary[range].map { $0.id }
        
        // Add range to existing selection to match Finder behavior
        for id in idsToSelect {
            selectedAudioFileIDs.insert(id)
        }
        lastSelectedTrackID = endID
    }
    
    func selectAll(in filteredLibrary: [AudioFile]) {
        let allIDs = filteredLibrary.map { $0.id }
        selectedAudioFileIDs = Set(allIDs)
    }
    
    func deselectAll() {
        selectedAudioFileIDs.removeAll()
        lastSelectedTrackID = nil
    }

    func prepareMetadataEditDraft() {
        metadataEditDraft = MetadataEditDraft(files: selectedAudioFiles)
    }

    func presentArtworkImporter() {
        isArtworkImporterPresented = true
    }

    /// Marks the draft to remove existing artwork on apply.
    func removeArtwork() {
        metadataEditDraft.artworkData = nil
        metadataEditDraft.artworkMode = .remove
    }

    /// Applies dropped/pasted image data as the replacement artwork.
    func setArtwork(data: Data) {
        metadataEditDraft.artworkData = data
        metadataEditDraft.artworkMode = .replace
    }

    func handleArtworkImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    metadataEditDraft.artworkData = try await artworkCache.loadImageData(from: url)
                    metadataEditDraft.artworkMode = .replace
                } catch {
                    presentLibraryError(String(format: loc["Не удалось прочитать выбранную обложку: %@"], error.localizedDescription))
                }
            }
        case let .failure(error):
            presentLibraryError(String(format: loc["Не удалось получить доступ к выбранной обложке: %@"], error.localizedDescription))
        }
    }

    func applyMetadataEditDraft() {
        guard !selectedAudioFiles.isEmpty else {
            presentLibraryError(loc["Выберите хотя бы один трек перед изменением метаданных."])
            return
        }
        guard metadataEditDraft.hasChanges else {
            setLibraryStatus(loc["Выберите хотя бы одно поле метаданных."], severity: .warning)
            return
        }

        Task { await applyMetadataEdits() }
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
            presentLibraryError(loc["Нет доступных файлов или папок."])
            return
        }

        let scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        isScanningLibrary = true
        setLibraryStatus(
            String(format: loc["Сканирование выбранного (%d)…"], urls.count),
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
                String(format: loc["Новых поддерживаемых аудиофайлов не найдено. Пропущено: %d."], result.skippedItemCount),
                severity: .warning
            )
            return
        }

        isAnalyzingTechnicalMetadata = true
        setLibraryStatus(
            String(format: loc["Чтение технических метаданных (%d)…"], addedCount),
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
            String(format: loc["Чтение тегов и обложек (%d)…"], addedCount),
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
            ? String(format: loc[" Пропущено: %d."], result.skippedItemCount)
            : ""
        let analysisDescription = failedAnalysisCount > 0
            ? String(format: loc[" Технические метаданные недоступны для %d."], failedAnalysisCount)
            : loc[" Технические метаданные прочитаны для всех треков."]
        let metadataDescription = failedMetadataReadCount > 0
            ? String(format: loc[" Теги недоступны для %d."], failedMetadataReadCount)
            : String(format: loc[" Теги прочитаны для %d."], metadataReadCount)
        let wasSaved = await persistLibrary()
        let persistenceDescription = wasSaved
            ? loc[" Библиотека сохранена."]
            : loc[" Не удалось сохранить библиотеку."]
        setLibraryStatus(
            String(format: loc["Добавлено треков: %d."], addedCount) + analysisDescription + metadataDescription + skippedDescription + persistenceDescription,
            severity: failedAnalysisCount > 0 || failedMetadataReadCount > 0 || result.skippedItemCount > 0 || !wasSaved ? .warning : .information
        )
        analyzeForDuplicates()
    }

    private func restorePersistedLibrary() async {
        setLibraryStatus(loc["Восстановление сохранённой библиотеки…"], severity: .information)

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
                    String(format: loc["Восстановлено треков: %d. Недоступно: %d."], library.count, restoration.unavailableTrackCount),
                    severity: .warning
                )
            } else {
                setLibraryStatus(
                    String(format: loc["Восстановлено треков из сохранённой библиотеки: %d."], library.count),
                    severity: .information
                )
            }
        } catch {
            setLibraryStatus(
                String(format: loc["Не удалось восстановить сохранённую библиотеку: %@"], error.localizedDescription),
                severity: .error
            )
        }
        
        analyzeForDuplicates()
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

    private func applyMetadataEdits() async {
        do {
            let selectedIDs = selectedAudioFileIDs
            let previousLibrary = library
            var artworkLocations: [AudioFile.ID: URL] = [:]

            isApplyingMetadataEdits = true
            setLibraryStatus(
                String(format: loc["Применение изменений метаданных (%d)…"], selectedIDs.count),
                severity: .information
            )

            if metadataEditDraft.artworkMode == .replace, let artworkData = metadataEditDraft.artworkData {
                for audioFile in selectedAudioFiles {
                    artworkLocations[audioFile.id] = try await artworkCache.store(artworkData, for: audioFile.id)
                }
            }

            var updatedLibrary = library
            for i in updatedLibrary.indices {
                let audioFile = updatedLibrary[i]
                guard selectedIDs.contains(audioFile.id) else { continue }
                var updatedAudioFile = audioFile
                updatedAudioFile.metadata = try metadataEditDraft.applying(to: audioFile.metadata)
                if let artworkLocation = artworkLocations[audioFile.id] {
                    updatedAudioFile.metadata.artworkLocation = artworkLocation
                }
                
                try await metadataWriter.write(metadata: updatedAudioFile.metadata, to: updatedAudioFile.url)
                updatedLibrary[i] = updatedAudioFile
            }
            library = updatedLibrary

            let wasSaved = await persistLibrary()
            isApplyingMetadataEdits = false

            guard wasSaved else {
                library = previousLibrary
                presentLibraryError(loc["Изменения метаданных не удалось сохранить. Изменения не применены."])
                return
            }

            setLibraryStatus(
                String(format: loc["Изменения метаданных применены (%d), библиотека сохранена."], selectedIDs.count),
                severity: .information
            )
            prepareMetadataEditDraft()
        } catch {
            isApplyingMetadataEdits = false
            presentLibraryError(error.localizedDescription)
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
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Duplicates
    private func analyzeForDuplicates() {
        duplicateGroups = duplicateDetector.findDuplicates(in: library)
    }

    func moveTrackToTrash(_ id: AudioFile.ID) {
        guard let index = library.firstIndex(where: { $0.id == id }) else { return }
        let track = library[index]
        
        do {
            try FileManager.default.trashItem(at: track.url, resultingItemURL: nil)
        } catch {
            print("Failed to move track to trash: \(error)")
            // We'll still remove it from library even if trashing fails, 
            // or perhaps not? Standard behavior: if trash fails, show error.
            // But we will try to remove from library anyway.
        }
        
        library.remove(at: index)
        trackBookmarks.removeValue(forKey: id)
        
        if selectedAudioFileIDs.contains(id) {
            selectedAudioFileIDs.remove(id)
            if lastSelectedTrackID == id {
                lastSelectedTrackID = nil
            }
        }
        
        analyzeForDuplicates()
        Task { await persistLibrary() }
    }

    // MARK: - Folders
    
    func deleteFolder(url: URL, moveToTrash: Bool) {
        if moveToTrash {
            NSWorkspace.shared.recycle([url]) { [weak self] newURLs, error in
                DispatchQueue.main.async {
                    if error == nil {
                        self?.removeFolderFromLibrary(url: url)
                    } else {
                        self?.presentLibraryError(String(format: Localization.shared["Не удалось переместить папку в Корзину: %@"], error!.localizedDescription))
                    }
                }
            }
        } else {
            removeFolderFromLibrary(url: url)
        }
    }
    
    private func removeFolderFromLibrary(url: URL) {
        library.removeAll { $0.url.deletingLastPathComponent().standardizedFileURL == url.standardizedFileURL }
        if selectedSection == .folder(url) {
            selectedSection = .library
        }
        analyzeForDuplicates()
        Task { await persistLibrary() }
    }
    
    func renameFolder(url: URL, newName: String, onMac: Bool) {
        if onMac {
            let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                
                library = library.map { track in
                    if track.url.deletingLastPathComponent().standardizedFileURL == url.standardizedFileURL {
                        var updatedTrack = track
                        updatedTrack.url = newURL.appendingPathComponent(track.url.lastPathComponent)
                        return updatedTrack
                    }
                    return track
                }
                
                folderAliases.removeValue(forKey: url)
                
                if selectedSection == .folder(url) {
                    selectedSection = .folder(newURL)
                }
                
                analyzeForDuplicates()
                Task { await persistLibrary() }
                
            } catch {
                presentLibraryError(String(format: loc["Не удалось переименовать папку на Mac: %@"], error.localizedDescription))
            }
        } else {
            folderAliases[url] = newName
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
