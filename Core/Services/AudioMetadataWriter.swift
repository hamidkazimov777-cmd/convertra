import Foundation

actor AudioMetadataWriter {
    private let runner = FFmpegCommandRunner()
    
    enum MetadataWriterError: Error, LocalizedError {
        case fileReplaceFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case let .fileReplaceFailed(error):
                return "Failed to replace the original file with the updated one: \(error.localizedDescription)"
            }
        }
    }
    
    func write(metadata: AudioMetadata, to url: URL) async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let tempURL = temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
        
        var arguments = [
            "-i", url.path,
            "-codec", "copy",
            "-map_metadata", "0"
        ]
        
        let fields: [(String, String?)] = [
            ("title", metadata.title),
            ("artist", metadata.artist),
            ("album", metadata.album),
            ("genre", metadata.genre),
            ("date", metadata.year.map(String.init)),
            ("track", metadata.trackNumber.map(String.init)),
            ("comment", metadata.comments),
            ("isrc", metadata.isrc),
            ("composer", metadata.composer)
        ]
        
        for (key, value) in fields {
            arguments.append("-metadata")
            arguments.append("\(key)=\(value ?? "")")
        }
        
        arguments.append("-y")
        arguments.append(tempURL.path)
        
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
        
        _ = try await runner.run(arguments: arguments)
        
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            throw MetadataWriterError.fileReplaceFailed(error)
        }
    }
}
