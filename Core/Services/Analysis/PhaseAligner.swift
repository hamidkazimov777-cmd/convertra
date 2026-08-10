import Foundation

/// Independent Phase Aligner for AudioAnalysisEngine 2.0.
actor PhaseAligner {
    func alignPhase(pcm: [Float], bpm: Double, sampleRate: Double = 22050.0) -> Double {
        let beatIntervalFrames = Int(round((60.0 / bpm) * sampleRate))
        guard beatIntervalFrames > 0, pcm.count >= beatIntervalFrames else { return 0.0 }
        
        var bestOffset = 0
        var maxEnergy: Float = -1.0
        
        for offset in 0..<min(beatIntervalFrames, pcm.count - beatIntervalFrames) {
            let amp = abs(pcm[offset])
            if amp > maxEnergy {
                maxEnergy = amp
                bestOffset = offset
            }
        }
        return Double(bestOffset) / sampleRate
    }
}
