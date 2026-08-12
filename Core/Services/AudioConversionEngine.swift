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

        // Embedded cover art rides along as a video stream. When the user opts
        // out we drop it with `-vn`; when they keep it we leave FFmpeg's default
        // stream selection to copy it wherever the target format supports it.
        if !job.settings.preserveArtwork {
            arguments.append("-vn")
        }

        arguments.append("-y")
        arguments.append(tempURL.path)
        
        let accessGranted = job.sourceURL.startAccessingSecurityScopedResource()
        defer { if accessGranted { job.sourceURL.stopAccessingSecurityScopedResource() } }
        
        _ = try await runner.run(arguments: arguments)
        
        do {
            // The destination may live in a recreated sub-folder tree (preserve
            // folder structure), so make sure the parent exists before moving.
            try FileManager.default.createDirectory(
                at: job.destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
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
