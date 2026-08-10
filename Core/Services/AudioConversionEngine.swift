import Foundation

actor AudioConversionEngine {
    private let runner = FFmpegCommandRunner()
    
    enum ConversionError: Error, LocalizedError {
        case fileSaveFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case let .fileSaveFailed(error):
                return "Failed to save the converted file to the destination: \(error.localizedDescription)"
            }
        }
    }
    
    func convert(job: ConversionJob) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(job.settings.outputFormat.rawValue)
        
        var arguments = [
            "-i", job.sourceURL.path
        ]
        
        switch job.settings.outputFormat {
        case .mp3:
            arguments.append(contentsOf: ["-codec:a", "libmp3lame"])
        case .wav:
            arguments.append(contentsOf: ["-codec:a", "pcm_s16le"])
        case .flac:
            arguments.append(contentsOf: ["-codec:a", "flac"])
        case .aiff:
            arguments.append(contentsOf: ["-codec:a", "pcm_s16be"])
        }
        
        switch job.settings.bitrate {
        case let .constant(kbps):
            arguments.append(contentsOf: ["-b:a", "\(kbps)k"])
        }
        
        if job.settings.preserveMetadata {
            arguments.append(contentsOf: ["-map_metadata", "0"])
        }
        
        // Artwork is typically handled automatically by FFmpeg's default stream selection
        // when converting audio formats that support embedded pictures.
        
        arguments.append("-y")
        arguments.append(tempURL.path)
        
        let accessGranted = job.sourceURL.startAccessingSecurityScopedResource()
        defer { if accessGranted { job.sourceURL.stopAccessingSecurityScopedResource() } }
        
        _ = try await runner.run(arguments: arguments)
        
        do {
            if FileManager.default.fileExists(atPath: job.destinationURL.path) {
                _ = try FileManager.default.replaceItemAt(job.destinationURL, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: job.destinationURL)
            }
        } catch {
            throw ConversionError.fileSaveFailed(error)
        }
    }
}
