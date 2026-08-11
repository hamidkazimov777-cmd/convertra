import ConvertraAudioCore
import Foundation

/// A candidate key with correlation score and Camelot code.
struct KeyCandidate: Sendable {
    let musicalKey: MusicalKey
    let camelotKey: CamelotKey
    let correlation: Double // Pearson correlation (-1.0 ... 1.0)
}

/// Result of key detection containing primary key, Camelot key, confidence, and candidate list.
struct KeyResult: Sendable {
    let musicalKey: MusicalKey
    let camelotKey: CamelotKey
    let confidence: Double // Multi-factor keyConfidence (0.0 ... 1.0)
    let candidates: [KeyCandidate]
    let chromagram: [Float] // Not exposed by the AudioCore binary boundary; always empty here.
}

/// Key detector for AudioAnalysisEngine 2.0.
///
/// This is a thin adapter over **Convertra AudioCore**, the proprietary DSP
/// engine shipped as a prebuilt binary (`Frameworks/ConvertraAudioCore.xcframework`).
/// The peak-based HPCP chroma extraction, tuning correction, and key-profile
/// correlation that power this detector are Convertra's core IP and are not
/// distributed as source. See `Frameworks/README.md` for licensing details.
actor KeyDetector {
    private let engine = ConvertraKeyEngine()

    /// Detects key from a PCM signal at Convertra AudioCore's expected sample rate.
    func detectKey(pcm: [Float]) async -> KeyResult {
        let result = await engine.detectKey(pcm: pcm)
        let primaryKey = Self.camelotKey(number: result.camelotNumber, isMinor: result.isMinor)

        let candidates = result.candidates.map { candidate -> KeyCandidate in
            let camelot = Self.camelotKey(number: candidate.camelotNumber, isMinor: candidate.isMinor)
            return KeyCandidate(musicalKey: camelot.musicalKey, camelotKey: camelot, correlation: candidate.correlation)
        }

        return KeyResult(
            musicalKey: primaryKey.musicalKey,
            camelotKey: primaryKey,
            confidence: result.confidence,
            candidates: candidates,
            chromagram: []
        )
    }

    private static func camelotKey(number: Int, isMinor: Bool) -> CamelotKey {
        CamelotKey(number: number, mode: isMinor ? .a : .b) ?? CamelotKey(number: 8, mode: .b)!
    }
}
