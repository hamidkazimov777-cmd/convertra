import Foundation

struct PersistedLibraryTrack: Codable, Hashable, Sendable {
    var audioFile: AudioFile
    var bookmarkData: Data?
}

struct LibraryPersistenceSnapshot: Codable, Hashable, Sendable {
    var sourceBookmarks: [Data]
    var tracks: [PersistedLibraryTrack]
}

struct LibraryRestorationResult: Sendable {
    var tracks: [PersistedLibraryTrack]
    var unavailableTrackCount: Int
}

/// Stores the library snapshot in Application Support. Security-scoped bookmarks
/// retain user-granted access across relaunches without storing media copies.
actor LibraryPersistenceStore {
    private let fileManager = FileManager.default
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
    }

    func load() throws -> LibraryPersistenceSnapshot? {
        guard fileManager.fileExists(atPath: storageURL.path) else { return nil }
        let data = try Data(contentsOf: storageURL)
        return try JSONDecoder().decode(LibraryPersistenceSnapshot.self, from: data)
    }

    func save(_ snapshot: LibraryPersistenceSnapshot) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: storageURL, options: .atomic)
    }

    func bookmarkData(for urls: [URL]) -> [URL: Data] {
        var bookmarks: [URL: Data] = [:]

        for url in urls {
            do {
                let normalizedURL = url.standardizedFileURL
                bookmarks[normalizedURL] = try normalizedURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                continue
            }
        }

        return bookmarks
    }

    func restore(_ snapshot: LibraryPersistenceSnapshot) -> LibraryRestorationResult {
        var restoredTracks: [PersistedLibraryTrack] = []
        var unavailableTrackCount = 0

        for persistedTrack in snapshot.tracks {
            guard let restoredTrack = restoreTrack(persistedTrack) else {
                unavailableTrackCount += 1
                continue
            }
            restoredTracks.append(restoredTrack)
        }

        return LibraryRestorationResult(
            tracks: restoredTracks,
            unavailableTrackCount: unavailableTrackCount
        )
    }

    private func restoreTrack(_ persistedTrack: PersistedLibraryTrack) -> PersistedLibraryTrack? {
        guard let bookmarkData = persistedTrack.bookmarkData else {
            return fileManager.fileExists(atPath: persistedTrack.audioFile.url.path) ? persistedTrack : nil
        }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL
            let accessedSecurityScope = resolvedURL.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScope {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            }

            guard fileManager.fileExists(atPath: resolvedURL.path) else { return nil }

            let refreshedBookmark = isStale
                ? self.bookmarkData(for: [resolvedURL])[resolvedURL] ?? bookmarkData
                : bookmarkData
            return PersistedLibraryTrack(
                audioFile: AudioFile(
                    id: persistedTrack.audioFile.id,
                    url: resolvedURL,
                    metadata: persistedTrack.audioFile.metadata,
                    analysis: persistedTrack.audioFile.analysis
                ),
                bookmarkData: refreshedBookmark
            )
        } catch {
            return fileManager.fileExists(atPath: persistedTrack.audioFile.url.path) ? persistedTrack : nil
        }
    }

    private static func defaultStorageURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent("Convertra", isDirectory: true)
            .appendingPathComponent("library.json", isDirectory: false)
    }
}
