import XCTest
@testable import Convertra

final class AudioLibraryScannerTests: XCTestCase {
    func testScannerRecursivelyFindsOnlySupportedAudioFiles() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nestedURL = rootURL.appendingPathComponent("Nested", isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        try fileManager.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        fileManager.createFile(atPath: rootURL.appendingPathComponent("first.WAV").path, contents: Data())
        fileManager.createFile(atPath: nestedURL.appendingPathComponent("second.flac").path, contents: Data())
        fileManager.createFile(atPath: nestedURL.appendingPathComponent("notes.txt").path, contents: Data())

        let result = await AudioLibraryScanner().scan(urls: [rootURL])

        XCTAssertEqual(result.audioURLs.count, 2)
        XCTAssertEqual(Set(result.audioURLs.map { $0.pathExtension.lowercased() }), ["wav", "flac"])
        XCTAssertEqual(result.skippedItemCount, 1)
    }
}
