import Foundation
import XCTest
@testable import Convertra

final class ArtworkCacheTests: XCTestCase {
    func testStoreWritesImageDataUsingDetectedExtension() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let cache = ArtworkCache(directoryURL: directoryURL)
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        let artworkURL = try await cache.store(imageData, for: UUID())

        XCTAssertEqual(artworkURL.pathExtension, "png")
        XCTAssertEqual(try Data(contentsOf: artworkURL), imageData)
    }
}
