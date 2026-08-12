import Foundation
import SwiftUI

/// Interface appearance choice. `.system` follows macOS; the others force a
/// specific theme via `.preferredColorScheme`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` means "follow the system" for `.preferredColorScheme`.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// User-facing preferences, persisted in `UserDefaults`. Mirrors the
/// `Localization.shared` pattern: a single shared, observable store so both the
/// Settings screen and the plain `startConversion(...)` free function can read
/// the same values without threading them through every call site.
///
/// Scope is deliberately narrow: it exposes **only** the conversion parameters
/// the engine actually honours today (`AudioConversionEngine.convert`) — output
/// format, MP3 bitrate and metadata preservation. Artwork / folder-structure
/// flags exist on `ConversionSettings` but are ignored by the engine, so they
/// are not surfaced here as if they worked. Language lives in `Localization`.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// Seeds the conversion toolbar's format at launch; the toolbar picker can
    /// still override it per session.
    @Published var defaultOutputFormat: ConversionSettings.OutputFormat {
        didSet { UserDefaults.standard.set(defaultOutputFormat.rawValue, forKey: Keys.defaultOutputFormat) }
    }

    /// Constant MP3 bitrate. Only meaningful for MP3 output — the lossless
    /// codecs (WAV/FLAC/AIFF) ignore `-b:a`.
    @Published var mp3BitrateKbps: Int {
        didSet { UserDefaults.standard.set(mp3BitrateKbps, forKey: Keys.mp3Bitrate) }
    }

    /// Copies source tags into the converted file (`-map_metadata 0`).
    @Published var preserveMetadata: Bool {
        didSet { UserDefaults.standard.set(preserveMetadata, forKey: Keys.preserveMetadata) }
    }

    /// Keeps embedded cover art; when off the engine strips it (`-vn`).
    @Published var preserveArtwork: Bool {
        didSet { UserDefaults.standard.set(preserveArtwork, forKey: Keys.preserveArtwork) }
    }

    /// Recreates the source folder tree under the output folder instead of
    /// flattening every converted file into one directory.
    @Published var preserveFolderStructure: Bool {
        didSet { UserDefaults.standard.set(preserveFolderStructure, forKey: Keys.preserveFolderStructure) }
    }

    /// Target sample rate for conversions (`.original` keeps the source rate).
    @Published var defaultSampleRate: ConversionSettings.SampleRate {
        didSet { UserDefaults.standard.set(defaultSampleRate.rawValue, forKey: Keys.sampleRate) }
    }

    /// Target channel layout for conversions (`.original` keeps the source).
    @Published var defaultChannels: ConversionSettings.ChannelLayout {
        didSet { UserDefaults.standard.set(defaultChannels.rawValue, forKey: Keys.channels) }
    }

    /// Interface theme (System / Light / Dark).
    @Published var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    /// Maximum number of conversions the queue runs at once. Previously the
    /// queue launched an ffmpeg process for *every* job simultaneously, which on
    /// a large batch spawned dozens of processes and thrashed the machine. A
    /// bounded limit keeps big batches stable.
    @Published var maxParallelConversions: Int {
        didSet { UserDefaults.standard.set(maxParallelConversions, forKey: Keys.maxParallel) }
    }

    static let bitrateOptions = [320, 256, 192, 128]
    static let parallelismOptions = [1, 2, 3, 4, 6, 8]

    /// Throughput-oriented default: use almost every core (leave one for the UI
    /// so the app stays responsive), capped at 6 to avoid diminishing returns
    /// and disk contention on big batches.
    static var defaultParallelism: Int {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        return min(max(2, cores - 1), 6)
    }

    private enum Keys {
        static let defaultOutputFormat = "defaultOutputFormat"
        static let mp3Bitrate = "mp3BitrateKbps"
        static let preserveMetadata = "preserveMetadata"
        static let preserveArtwork = "preserveArtwork"
        static let preserveFolderStructure = "preserveFolderStructure"
        static let sampleRate = "defaultSampleRate"
        static let channels = "defaultChannels"
        static let appearance = "appearanceMode"
        static let maxParallel = "maxParallelConversions"
    }

    private init() {
        let defaults = UserDefaults.standard
        defaultOutputFormat = ConversionSettings.OutputFormat(
            rawValue: defaults.string(forKey: Keys.defaultOutputFormat) ?? ""
        ) ?? .mp3
        let savedBitrate = defaults.integer(forKey: Keys.mp3Bitrate)
        mp3BitrateKbps = savedBitrate == 0 ? 320 : savedBitrate
        preserveMetadata = defaults.object(forKey: Keys.preserveMetadata) as? Bool ?? true
        preserveArtwork = defaults.object(forKey: Keys.preserveArtwork) as? Bool ?? true
        preserveFolderStructure = defaults.object(forKey: Keys.preserveFolderStructure) as? Bool ?? true
        defaultSampleRate = ConversionSettings.SampleRate(
            rawValue: defaults.string(forKey: Keys.sampleRate) ?? ""
        ) ?? .original
        defaultChannels = ConversionSettings.ChannelLayout(
            rawValue: defaults.string(forKey: Keys.channels) ?? ""
        ) ?? .original
        // Default to dark to preserve the existing look for current users.
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .dark
        let savedParallel = defaults.integer(forKey: Keys.maxParallel)
        maxParallelConversions = savedParallel == 0 ? Self.defaultParallelism : savedParallel
    }

    /// Builds the settings for a conversion using the current preferences.
    func conversionSettings(format: ConversionSettings.OutputFormat) -> ConversionSettings {
        ConversionSettings(
            outputFormat: format,
            bitrate: .constant(kilobitsPerSecond: mp3BitrateKbps),
            preserveMetadata: preserveMetadata,
            preserveArtwork: preserveArtwork,
            preserveFolderStructure: preserveFolderStructure,
            sampleRate: defaultSampleRate,
            channels: defaultChannels
        )
    }
}
