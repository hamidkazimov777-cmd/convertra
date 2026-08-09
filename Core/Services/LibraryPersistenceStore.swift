import Foundation
import CoreData

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

/// Stores the library snapshot in Application Support using programmatic Core Data.
/// Security-scoped bookmarks retain user-granted access across relaunches without storing media copies.
actor LibraryPersistenceStore {
    private let fileManager = FileManager.default
    private let container: NSPersistentContainer
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        
        let model = CoreDataModel.makeModel()
        container = NSPersistentContainer(name: "Convertra", managedObjectModel: model)
        
        let description = NSPersistentStoreDescription(url: self.storageURL)
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func load() throws -> LibraryPersistenceSnapshot? {
        guard fileManager.fileExists(atPath: storageURL.path) else { return nil }
        
        let context = container.viewContext
        let request = NSFetchRequest<TrackEntity>(entityName: "TrackEntity")
        let entities = try context.fetch(request)
        
        let tracks: [PersistedLibraryTrack] = entities.compactMap { entity in
            guard let url = URL(string: entity.urlPath) else { return nil }
            let metadata = AudioMetadata(
                title: entity.title,
                artist: entity.artist,
                album: entity.album,
                genre: entity.genre,
                year: entity.year?.intValue,
                trackNumber: entity.trackNumber?.intValue
            )
            var analysis: AudioAnalysis? = nil
            if entity.duration > 0 || entity.codec != AudioCodec.unknown.rawValue {
                analysis = AudioAnalysis(
                    bpm: entity.bpm?.doubleValue,
                    musicalKey: nil,
                    duration: entity.duration,
                    bitrate: entity.bitrate?.intValue,
                    sampleRate: entity.sampleRate?.doubleValue,
                    channels: entity.channels?.intValue,
                    codec: AudioCodec(rawValue: entity.codec) ?? .unknown
                )
            }
            
            let file = AudioFile(id: entity.id, url: url, metadata: metadata, analysis: analysis)
            return PersistedLibraryTrack(audioFile: file, bookmarkData: entity.bookmarkData)
        }
        
        let bookmarkRequest = NSFetchRequest<SourceBookmarkEntity>(entityName: "SourceBookmarkEntity")
        let bookmarkEntities = try context.fetch(bookmarkRequest)
        let sourceBookmarks = bookmarkEntities.map { $0.bookmarkData }
        
        return LibraryPersistenceSnapshot(sourceBookmarks: sourceBookmarks, tracks: tracks)
    }

    func save(_ snapshot: LibraryPersistenceSnapshot) throws {
        // Ensure directory exists for sqlite files
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        try context.performAndWait {
            let request = NSFetchRequest<TrackEntity>(entityName: "TrackEntity")
            let existingTracks = try context.fetch(request)
            let existingDict = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.id, $0) })
            
            var processedIDs = Set<UUID>()
            
            for track in snapshot.tracks {
                let id = track.audioFile.id
                processedIDs.insert(id)
                
                let entity = existingDict[id] ?? TrackEntity(context: context)
                
                entity.id = id
                entity.urlPath = track.audioFile.url.absoluteString
                entity.bookmarkData = track.bookmarkData
                
                let meta = track.audioFile.metadata
                entity.title = meta.title
                entity.artist = meta.artist
                entity.album = meta.album
                entity.trackNumber = meta.trackNumber.map { NSNumber(value: $0) }
                entity.year = meta.year.map { NSNumber(value: $0) }
                entity.genre = meta.genre
                
                if let analysis = track.audioFile.analysis {
                    entity.duration = analysis.duration
                    entity.bpm = analysis.bpm.map { NSNumber(value: $0) }
                    entity.bitrate = analysis.bitrate.map { NSNumber(value: $0) }
                    entity.sampleRate = analysis.sampleRate.map { NSNumber(value: $0) }
                    entity.channels = analysis.channels.map { NSNumber(value: $0) }
                    entity.codec = analysis.codec.rawValue
                } else {
                    entity.duration = 0
                    entity.codec = AudioCodec.unknown.rawValue
                }
            }
            
            for (id, entity) in existingDict {
                if !processedIDs.contains(id) {
                    context.delete(entity)
                }
            }
            
            // Sync Source Bookmarks
            let bRequest = NSFetchRequest<SourceBookmarkEntity>(entityName: "SourceBookmarkEntity")
            let existingB = try context.fetch(bRequest)
            for b in existingB { context.delete(b) } // Clear all
            
            for bData in snapshot.sourceBookmarks {
                let entity = SourceBookmarkEntity(context: context)
                entity.bookmarkData = bData
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
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
            .appendingPathComponent("library.sqlite", isDirectory: false)
    }
}
