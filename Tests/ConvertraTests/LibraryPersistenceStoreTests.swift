import Foundation
import XCTest
@testable import Convertra

final class LibraryPersistenceStoreTests: XCTestCase {
    func testStoreRoundTripsLibrarySnapshot() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("library.json")
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let audioFile = AudioFile(
            url: URL(fileURLWithPath: "/Music/Set.mp3"),
            metadata: AudioMetadata(title: "Set", artist: "DJ"),
            analysis: AudioAnalysis(duration: 60, bitrate: 320_000, sampleRate: 44_100, channels: 2, codec: .mp3)
        )
        let snapshot = LibraryPersistenceSnapshot(
            sourceBookmarks: [Data([1, 2, 3])],
            tracks: [PersistedLibraryTrack(audioFile: audioFile, bookmarkData: Data([4, 5, 6]))]
        )
        let store = LibraryPersistenceStore(storageURL: storageURL)

        try await store.save(snapshot)
        let loadedLibrary = try await store.load()
        let loadedSnapshot = try XCTUnwrap(loadedLibrary)

        XCTAssertEqual(loadedSnapshot, snapshot)
    }

    func testRestoreUsesExistingPathWhenTrackHasNoBookmark() async throws {
        let fileManager = FileManager.default
        let fileURL = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? fileManager.removeItem(at: fileURL) }
        try Data().write(to: fileURL)

        let track = PersistedLibraryTrack(audioFile: AudioFile(url: fileURL), bookmarkData: nil)
        let result = await LibraryPersistenceStore().restore(
            LibraryPersistenceSnapshot(sourceBookmarks: [], tracks: [track])
        )

        XCTAssertEqual(result.tracks.map(\.audioFile), [track.audioFile])
        XCTAssertEqual(result.unavailableTrackCount, 0)
    }
}
