import Foundation
import AVFoundation

/// Full analysis output from AudioAnalysisEngine 2.0.
struct AudioAnalysisResult2: Sendable {
    let url: URL
    let durationSeconds: Double
    let bpm: Double // High precision (e.g. 124.00)
    let bpmConfidence: Double // 0.0 ... 1.0
    let musicalKey: MusicalKey
    let camelotKey: CamelotKey
    let keyConfidence: Double // 0.0 ... 1.0
    let overallConfidence: Double // Combined BPM & Key confidence
    let beatGrid: BeatGrid
    let downbeatResult: DownbeatResult
    let segmentFusionResult: FusedTempoResult
}

/// Unified Facade Actor for AudioAnalysisEngine 2.0.
/// Orchestrates chunked decoding, sliding-context HPSS, multi-band tempo detection,
/// beat tracking, downbeat alignment, CQT log-filterbank key detection, Camelot mapping,
/// and weighted segment fusion across strategic segments (.intro, .bodyA, .bodyB, .outro).
actor AudioAnalysisEngine2 {
    private let decoder = AudioDecoder()
    private let preprocessor = SignalPreprocessor()
    private let tempoDetector = TempoDetector()
    private let beatTracker = BeatTracker()

    private let downbeatDetector = DownbeatDetector()
    private let keyDetector = KeyDetector()
    private let segmentFusion = SegmentFusion()

    /// Performs complete professional audio analysis on an audio file at `url`.
    func analyze(url: URL) async throws -> AudioAnalysisResult2 {
        // 1. Chunked streaming decode into strategic segments
        let decoded = try await decoder.decode(url: url)

        var segmentTempoResults: [(type: AudioSegment.SegmentType, result: TempoResult)] = []
        var bestHarmonicPCM: [Float] = []
        var bestPercussivePCM: [Float] = []
        var bestSegmentDuration: Double = 0.0

        // Process strategic segments (.intro, .bodyA, .bodyB, .outro)
        for segment in decoded.segments {
            let preprocessed = await preprocessor.process(segment: segment)
            let tempoResult = await tempoDetector.detectTempo(pcm: preprocessed.percussivePCM)
            segmentTempoResults.append((type: segment.type, result: tempoResult))

            // Keep primary Body B / Drop segment for beat grid and key detection
            if segment.type == .bodyB || bestHarmonicPCM.isEmpty {
                bestHarmonicPCM = preprocessed.harmonicPCM
                bestPercussivePCM = preprocessed.percussivePCM
                bestSegmentDuration = segment.durationSeconds
            }
        }

        // 2. Weighted Segment Fusion across Intro, Body A, Body B, Outro
        let fusedTempo = await segmentFusion.fuseTempoResults(segmentResults: segmentTempoResults)
        let primaryBPM = fusedTempo.bpm

        // 3. Beat Tracking & Downbeat Alignment over primary segment
        let beatGrid = await beatTracker.trackBeats(pcm: bestPercussivePCM, bpm: primaryBPM)
        let downbeatRes = await downbeatDetector.detectDownbeat(pcm: bestPercussivePCM, beatGrid: beatGrid)

        // 4. Key Detection & Camelot Mapping over Harmonic PCM
        let keyResult = await keyDetector.detectKey(pcm: bestHarmonicPCM)

        // 5. Compute combined overall confidence
        let overallConf = (0.50 * fusedTempo.bpmConfidence) + (0.50 * keyResult.confidence)

        return AudioAnalysisResult2(
            url: url,
            durationSeconds: decoded.durationSeconds,
            bpm: primaryBPM,
            bpmConfidence: fusedTempo.bpmConfidence,
            musicalKey: keyResult.musicalKey,
            camelotKey: keyResult.camelotKey,
            keyConfidence: keyResult.confidence,
            overallConfidence: overallConf,
            beatGrid: beatGrid,
            downbeatResult: downbeatRes,
            segmentFusionResult: fusedTempo
        )
    }
}
