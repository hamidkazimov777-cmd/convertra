import Foundation

/// Dedicated adapter that maps AudioAnalysisEngine2 results (AudioAnalysisResult2)
/// into Convertra's core production AudioAnalysis model.
struct AudioAnalysis2Adapter: Sendable {
    /// Adapts `AudioAnalysisResult2` and technical stream properties into `AudioAnalysis`.
    static func adapt(
        result: AudioAnalysisResult2,
        bitrate: Int? = nil,
        sampleRate: Double? = nil,
        channels: Int? = nil,
        codec: AudioCodec = .unknown
    ) -> AudioAnalysis {
        AudioAnalysis(
            bpm: result.bpm,
            musicalKey: result.musicalKey,
            camelotKey: result.camelotKey,
            bpmConfidence: result.bpmConfidence,
            keyConfidence: result.keyConfidence,
            duration: result.durationSeconds > 0 ? result.durationSeconds : 0,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            codec: codec
        )
    }
}
