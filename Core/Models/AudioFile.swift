import Foundation

/// A library item and its file-system identity. Audio analysis and metadata are
/// deliberately separate values so they can be loaded independently in the future.
struct AudioFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    var metadata: AudioMetadata
    var analysis: AudioAnalysis?

    init(
        id: UUID = UUID(),
        url: URL,
        metadata: AudioMetadata = .empty,
        analysis: AudioAnalysis? = nil
    ) {
        self.id = id
        self.url = url
        self.metadata = metadata
        self.analysis = analysis
    }

    var fileName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var displayTitle: String {
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? fileName : title
    }

    var displayArtist: String {
        let artist = metadata.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return artist.isEmpty ? "—" : artist
    }

    var displayDuration: String {
        guard let duration = analysis?.duration, duration > 0 else { return "—" }
        let roundedDuration = Int(duration.rounded())
        return String(format: "%d:%02d", roundedDuration / 60, roundedDuration % 60)
    }

    var displaySampleRate: String {
        guard let sampleRate = analysis?.sampleRate, sampleRate > 0 else { return "—" }
        return String(format: "%.1f kHz", sampleRate / 1_000)
    }

    var displayBitrate: String {
        guard let bitrate = analysis?.bitrate, bitrate > 0 else { return "—" }
        return "\(Int((Double(bitrate) / 1_000).rounded())) kbps"
    }

    var displayCodec: String {
        guard let codec = analysis?.codec, codec != .unknown else {
            return url.pathExtension.uppercased()
        }
        return codec.rawValue.uppercased()
    }

    var searchableText: String {
        [displayTitle, displayArtist, fileName, url.path, displayCodec]
            .joined(separator: " ")
    }
}
