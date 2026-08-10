import Foundation

/// Independent Downbeat Result with isolated confidence score.
struct DownbeatResult: Sendable {
    let downbeatTime: Double // Timestamp of 1st downbeat in seconds
    let downbeatConfidence: Double // Independent confidence (0.0 ... 1.0)
    let measureIntervalSeconds: Double // 4 * beatInterval
}

/// Independent Downbeat Detector for AudioAnalysisEngine 2.0.
/// Identifies Bar 1 / Beat 1 measure start. If downbeat detection is uncertain,
/// its lower confidence DOES NOT invalidate the BPM or BeatGrid!
actor DownbeatDetector {
    func detectDownbeat(pcm: [Float], beatGrid: BeatGrid, sampleRate: Double = 22050.0) -> DownbeatResult {
        let beatTimes = beatGrid.beatTimes
        guard beatTimes.count >= 4 else {
            return DownbeatResult(
                downbeatTime: beatGrid.firstBeatTime,
                downbeatConfidence: 0.30,
                measureIntervalSeconds: beatGrid.beatIntervalSeconds * 4.0
            )
        }

        // Measure energy at 4 beat positions per bar
        var bestBarStartIdx = 0
        var maxBarEnergy: Float = -1.0

        for barOffset in 0..<min(4, beatTimes.count) {
            var energy: Float = 0.0
            var count = 0
            var i = barOffset
            while i < beatTimes.count {
                let sampleIdx = Int(round(beatTimes[i] * sampleRate))
                if sampleIdx < pcm.count {
                    let amp = abs(pcm[sampleIdx])
                    energy += amp * amp
                    count += 1
                }
                i += 4
            }
            if count > 0 && energy > maxBarEnergy {
                maxBarEnergy = energy
                bestBarStartIdx = barOffset
            }
        }

        let downbeatTime = beatTimes[bestBarStartIdx]
        let confidence = beatTimes.count >= 8 ? 0.85 : 0.50

        return DownbeatResult(
            downbeatTime: downbeatTime,
            downbeatConfidence: confidence,
            measureIntervalSeconds: beatGrid.beatIntervalSeconds * 4.0
        )
    }
}
