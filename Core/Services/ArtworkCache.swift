import Foundation

/// Keeps extracted cover images out of the library model's in-memory payload.
actor ArtworkCache {
    private let fileManager = FileManager.default
    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL()
    }

    func store(_ imageData: Data, for audioFileID: UUID) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let artworkURL = directoryURL
            .appendingPathComponent(audioFileID.uuidString, isDirectory: false)
            .appendingPathExtension(fileExtension(for: imageData))
        try imageData.write(to: artworkURL, options: .atomic)
        return artworkURL
    }

    private func fileExtension(for imageData: Data) -> String {
        let bytes = [UInt8](imageData.prefix(8))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "gif" }
        return "img"
    }

    private static func defaultDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent("Convertra", isDirectory: true)
            .appendingPathComponent("Artwork", isDirectory: true)
    }
}
