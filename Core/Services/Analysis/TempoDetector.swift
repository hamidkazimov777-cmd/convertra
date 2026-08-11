import ConvertraAudioCore
import Foundation

/// A candidate tempo with score and octave ratio.
struct TempoCandidate: Sendable {
    let bpm: Double // High precision (e.g. 127.84)
    let score: Double // Periodicity & prior weighted score
    let confidence: Double // Candidate dominance (0.0 ... 1.0)
}

/// Detailed result of tempo detection on a single segment or fused track.
struct TempoResult: Sendable {
    let bpm: Double // Primary detected BPM
    let confidence: Double // Multi-factor bpmConfidence (0.0 ... 1.0)
    let candidates: [TempoCandidate]
    let onsetEnvelope: [Float] // Not exposed by the AudioCore binary boundary; always empty here.
    let lowBandOnsetEnergy: Double
    let highBandOnsetEnergy: Double
}

/// Tempo detector for AudioAnalysisEngine 2.0.
///
/// This is a thin adapter over **Convertra AudioCore**, the proprietary DSP
/// engine shipped as a prebuilt binary (`Frameworks/ConvertraAudioCore.xcframework`).
/// The multi-band onset detection, autocorrelation periodicity search with
/// parabolic sub-BPM interpolation, and half/double-time disambiguation that
/// power this detector are Convertra's core IP and are not distributed as
/// source. See `Frameworks/README.md` for licensing details.
actor TempoDetector {
    private let engine = ConvertraTempoEngine()

    /// Detects tempo from a PCM signal at Convertra AudioCore's expected sample rate.
    func detectTempo(pcm: [Float]) async -> TempoResult {
        let result = await engine.detectTempo(pcm: pcm)
        return TempoResult(
            bpm: result.bpm,
            confidence: result.confidence,
            candidates: result.candidates.map { TempoCandidate(bpm: $0.bpm, score: $0.score, confidence: $0.confidence) },
            onsetEnvelope: [],
            lowBandOnsetEnergy: 0,
            highBandOnsetEnergy: 0
        )
    }
}
