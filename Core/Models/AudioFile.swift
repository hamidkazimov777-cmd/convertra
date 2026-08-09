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
}
