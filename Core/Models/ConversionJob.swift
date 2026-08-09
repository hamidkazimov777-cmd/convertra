import Foundation

struct ConversionJob: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case queued
        case preparing
        case converting
        case completed
        case failed
        case cancelled
    }

    let id: UUID
    let sourceURL: URL
    let destinationURL: URL
    var settings: ConversionSettings
    var status: Status
    var progress: Double
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        destinationURL: URL,
        settings: ConversionSettings = .mp3_320CBR,
        status: Status = .queued,
        progress: Double = 0,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.settings = settings
        self.status = status
        self.progress = progress
        self.errorDescription = errorDescription
    }
}

struct ConversionSettings: Hashable, Sendable {
    enum OutputFormat: String, Hashable, Sendable {
        case mp3
    }

    enum BitrateMode: Hashable, Sendable {
        case constant(kilobitsPerSecond: Int)
    }

    var outputFormat: OutputFormat
    var bitrate: BitrateMode
    var preserveMetadata: Bool
    var preserveArtwork: Bool
    var preserveFolderStructure: Bool

    static let mp3_320CBR = ConversionSettings(
        outputFormat: .mp3,
        bitrate: .constant(kilobitsPerSecond: 320),
        preserveMetadata: true,
        preserveArtwork: true,
        preserveFolderStructure: true
    )
}
