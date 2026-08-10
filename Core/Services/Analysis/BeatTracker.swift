import Foundation

/// Represents a detected beat grid with frame timestamps and stability confidence.
struct BeatGrid: Sendable {
    let bpm: Double
    let firstBeatTime: Double // Phase offset in seconds
    let beatIntervalSeconds: Double // 60.0 / bpm
    let beatTimes: [Double] // Exact timestamp of each beat in seconds
    let confidence: Double // Grid stability confidence (0.0 ... 1.0)
}

/// Independent Beat Tracker for AudioAnalysisEngine 2.0.
actor BeatTracker {
    func trackBeats(pcm: [Float], bpm: Double, sampleRate: Double = 22050.0) -> BeatGrid {
        let beatIntervalSeconds = 60.0 / bpm
        let beatIntervalFrames = Int(round(beatIntervalSeconds * sampleRate))
        
        guard beatIntervalFrames > 0, pcm.count >= beatIntervalFrames else {
            return BeatGrid(
                bpm: bpm,
                firstBeatTime: 0.0,
                beatIntervalSeconds: beatIntervalSeconds,
                beatTimes: [],
                confidence: 0.0
            )
        }
        
        // Find best first beat phase by cross-correlating amplitude envelope
        var bestOffset = 0
        var maxEnergy: Float = -1.0
        
        let searchRange = min(beatIntervalFrames, pcm.count - beatIntervalFrames)
        for offset in 0..<searchRange {
            var energy: Float = 0.0
            var count = 0
            var pos = offset
            while pos < pcm.count {
                let amp = abs(pcm[pos])
                energy += amp * amp
                count += 1
                pos += beatIntervalFrames
            }
            if count > 0 {
                energy /= Float(count)
                if energy > maxEnergy {
                    maxEnergy = energy
                    bestOffset = offset
                }
            }
        }
        
        let firstBeatTime = Double(bestOffset) / sampleRate
        var beatTimes: [Double] = []
        var currentTime = firstBeatTime
        let totalDuration = Double(pcm.count) / sampleRate
        
        while currentTime < totalDuration {
            beatTimes.append(currentTime)
            currentTime += beatIntervalSeconds
        }
        
        let gridConfidence = beatTimes.count > 4 ? 0.90 : 0.50
        
        return BeatGrid(
            bpm: bpm,
            firstBeatTime: firstBeatTime,
            beatIntervalSeconds: beatIntervalSeconds,
            beatTimes: beatTimes,
            confidence: gridConfidence
        )
    }
}
