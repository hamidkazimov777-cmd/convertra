import Foundation
import UniformTypeIdentifiers

enum SupportedAudioFormat: String, CaseIterable, Sendable {
    case wav
    case aiff
    case flac
    case alac
    case mp3
    case aac
    case m4a

    static let importableContentTypes: [UTType] = [.audio, .folder]

    static func supports(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static let supportedExtensions: Set<String> = [
        "wav", "wave",
        "aif", "aiff",
        "flac",
        "alac",
        "mp3",
        "aac",
        "m4a"
    ]
}
