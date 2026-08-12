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
    enum OutputFormat: String, Hashable, Sendable, CaseIterable, Identifiable {
        case mp3
        case wav
        case flac
        case aiff
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .mp3: return "MP3"
            case .wav: return "WAV"
            case .flac: return "FLAC"
            case .aiff: return "AIFF"
            }
        }
    }

    enum BitrateMode: Hashable, Sendable {
        case constant(kilobitsPerSecond: Int)
    }

    /// Target sample rate, or `.original` to keep the source rate untouched.
    enum SampleRate: String, Hashable, Sendable, CaseIterable, Identifiable {
        case original
        case hz44100
        case hz48000
        case hz96000

        var id: String { rawValue }

        /// Rate in Hz to pass to `-ar`, or `nil` to leave the source rate.
        var hertz: Int? {
            switch self {
            case .original: return nil
            case .hz44100: return 44_100
            case .hz48000: return 48_000
            case .hz96000: return 96_000
            }
        }
    }

    /// Target channel layout, or `.original` to keep the source channels.
    enum ChannelLayout: String, Hashable, Sendable, CaseIterable, Identifiable {
        case original
        case stereo
        case mono

        var id: String { rawValue }

        /// Channel count to pass to `-ac`, or `nil` to leave the source layout.
        var count: Int? {
            switch self {
            case .original: return nil
            case .stereo: return 2
            case .mono: return 1
            }
        }
    }

    var outputFormat: OutputFormat
    var bitrate: BitrateMode
    var preserveMetadata: Bool
    var preserveArtwork: Bool
    var preserveFolderStructure: Bool
    var sampleRate: SampleRate
    var channels: ChannelLayout

    static let mp3_320CBR = ConversionSettings(
        outputFormat: .mp3,
        bitrate: .constant(kilobitsPerSecond: 320),
        preserveMetadata: true,
        preserveArtwork: true,
        preserveFolderStructure: true,
        sampleRate: .original,
        channels: .original
    )
}
