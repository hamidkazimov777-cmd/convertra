import Foundation

struct AudioAnalysis: Hashable, Sendable {
    var bpm: Double?
    var musicalKey: MusicalKey?
    var duration: TimeInterval
    var bitrate: Int?
    var sampleRate: Double?
    var channels: Int?
    var codec: AudioCodec

    init(
        bpm: Double? = nil,
        musicalKey: MusicalKey? = nil,
        duration: TimeInterval = 0,
        bitrate: Int? = nil,
        sampleRate: Double? = nil,
        channels: Int? = nil,
        codec: AudioCodec = .unknown
    ) {
        self.bpm = bpm
        self.musicalKey = musicalKey
        self.duration = duration
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
        self.codec = codec
    }

    var technicalSummary: String {
        var components: [String] = []

        if duration > 0 {
            let roundedDuration = Int(duration.rounded())
            components.append(String(format: "%d:%02d", roundedDuration / 60, roundedDuration % 60))
        }
        if let sampleRate {
            components.append(String(format: "%.1f kHz", sampleRate / 1_000))
        }
        if let channels {
            components.append("\(channels) ch")
        }
        if let bitrate {
            components.append("\(Int((Double(bitrate) / 1_000).rounded())) kbps")
        }
        if codec != .unknown {
            components.append(codec.rawValue.uppercased())
        }

        return components.joined(separator: " • ")
    }
}

enum MusicalKey: String, CaseIterable, Codable, Hashable, Sendable {
    case cMajor = "C Major", cMinor = "C Minor"
    case cSharpMajor = "C♯ Major", cSharpMinor = "C♯ Minor"
    case dMajor = "D Major", dMinor = "D Minor"
    case dSharpMajor = "D♯ Major", dSharpMinor = "D♯ Minor"
    case eMajor = "E Major", eMinor = "E Minor"
    case fMajor = "F Major", fMinor = "F Minor"
    case fSharpMajor = "F♯ Major", fSharpMinor = "F♯ Minor"
    case gMajor = "G Major", gMinor = "G Minor"
    case gSharpMajor = "G♯ Major", gSharpMinor = "G♯ Minor"
    case aMajor = "A Major", aMinor = "A Minor"
    case aSharpMajor = "A♯ Major", aSharpMinor = "A♯ Minor"
    case bMajor = "B Major", bMinor = "B Minor"
}

enum AudioCodec: String, CaseIterable, Codable, Hashable, Sendable {
    case wav, aiff, flac, alac, mp3, aac, m4a, unknown
}
