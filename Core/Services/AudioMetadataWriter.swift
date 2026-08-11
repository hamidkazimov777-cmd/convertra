import Foundation

/// Writes tag metadata (and cover art) back into the original audio file.
///
/// MP3 and AIFF are tagged natively via `NativeContainerTagger`, which is the
/// only reliable way to embed cover art into AIFF (FFmpeg drops it). Other
/// containers (FLAC, M4A, WAV) go through FFmpeg.
actor AudioMetadataWriter {
    private let runner = FFmpegCommandRunner()

    enum MetadataWriterError: Error, LocalizedError {
        case fileReplaceFailed(Error)
        case readFailed(Error)

        var errorDescription: String? {
            switch self {
            case let .fileReplaceFailed(error):
                return "Failed to replace the original file with the updated one: \(error.localizedDescription)"
            case let .readFailed(error):
                return "Failed to read the audio file for tagging: \(error.localizedDescription)"
            }
        }
    }

    func write(metadata: AudioMetadata, to url: URL) async throws {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

        let artwork = loadArtwork(from: metadata.artworkLocation)

        if NativeContainerTagger.supports(pathExtension: url.pathExtension) {
            try writeNative(metadata: metadata, artwork: artwork, to: url)
        } else {
            try await writeViaFFmpeg(metadata: metadata, artwork: artwork, to: url)
        }
    }

    // MARK: - Native (MP3 / AIFF)

    private func writeNative(metadata: AudioMetadata, artwork: Data?, to url: URL) throws {
        let original: Data
        do {
            original = try Data(contentsOf: url)
        } catch {
            throw MetadataWriterError.readFailed(error)
        }

        let tag = ID3v2TagBuilder.build(metadata: metadata, artwork: artwork)
        let updated = try NativeContainerTagger.apply(id3Tag: tag, to: original)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        do {
            try updated.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            throw MetadataWriterError.fileReplaceFailed(error)
        }
    }

    // MARK: - FFmpeg (FLAC / M4A / other)

    private func writeViaFFmpeg(metadata: AudioMetadata, artwork: Data?, to url: URL) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)

        var artworkURL: URL?
        if let artwork {
            let ext = artwork.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "png" : "jpg"
            let coverURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            try? artwork.write(to: coverURL, options: .atomic)
            artworkURL = coverURL
        }
        defer { if let artworkURL { try? FileManager.default.removeItem(at: artworkURL) } }

        var arguments = ["-i", url.path]
        if let artworkURL {
            arguments += ["-i", artworkURL.path, "-map", "0:a", "-map", "1:v",
                          "-c:a", "copy", "-c:v", "png", "-disposition:v", "attached_pic"]
        } else {
            arguments += ["-map", "0:a", "-c:a", "copy"]
        }

        let fields: [(String, String?)] = [
            ("title", metadata.title),
            ("artist", metadata.artist),
            ("album", metadata.album),
            ("album_artist", metadata.albumArtist),
            ("genre", metadata.genre),
            ("date", metadata.year.map(String.init)),
            ("track", metadata.trackNumber.map(String.init)),
            ("disc", metadata.discNumber.map(String.init)),
            ("comment", metadata.comments),
            ("composer", metadata.composer),
            ("grouping", metadata.grouping),
            ("publisher", metadata.publisher),
            ("copyright", metadata.copyright),
            ("TBPM", metadata.bpmTag.map(String.init)),
            ("TKEY", metadata.initialKey),
            ("isrc", metadata.isrc)
        ]
        for (key, value) in fields {
            arguments += ["-metadata", "\(key)=\(value ?? "")"]
        }

        arguments += ["-y", tempURL.path]

        _ = try await runner.run(arguments: arguments)

        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            throw MetadataWriterError.fileReplaceFailed(error)
        }
    }

    // MARK: - Helpers

    private func loadArtwork(from location: URL?) -> Data? {
        guard let location else { return nil }
        return try? Data(contentsOf: location)
    }
}
