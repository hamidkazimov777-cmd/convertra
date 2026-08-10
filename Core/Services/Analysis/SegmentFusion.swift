import Foundation

/// Fused multi-segment tempo analysis result.
struct FusedTempoResult: Sendable {
    let bpm: Double // High precision (e.g. 124.00)
    let bpmConfidence: Double // Aggregated multi-segment confidence (0.0 ... 1.0)
    let tempoCandidates: [TempoCandidate]
}

/// Independent Segment Fusion module implementing the Weighted Segment Fusion Strategy.
/// Rejects low-confidence/silent segments and weights Main Drop (1.0), Early Body (0.8), Intro/Outro (0.3).
actor SegmentFusion {
    func fuseTempoResults(segmentResults: [(type: AudioSegment.SegmentType, result: TempoResult)]) -> FusedTempoResult {
        guard !segmentResults.isEmpty else {
            return FusedTempoResult(bpm: 120.0, bpmConfidence: 0.0, tempoCandidates: [])
        }

        var candidateVotes: [Double: Double] = [:] // BPM -> Weighted Score
        var totalWeight: Double = 0.0

        for (type, result) in segmentResults {
            // Rejection: Skip silent / low-confidence segments
            guard result.confidence >= 0.15 else { continue }

            let weight: Double
            switch type {
            case .bodyB: weight = 1.0 // Main Drop gets highest weight
            case .bodyA: weight = 0.8 // Early Body gets high weight
            case .intro: weight = 0.3 // Intro DJ tools get low weight
            case .outro: weight = 0.3 // Outro DJ tools get low weight
            case .full: weight = 1.0  // Short file full segment
            }

            totalWeight += weight

            for cand in result.candidates {
                let roundedBPM = (cand.bpm * 100).rounded() / 100 // Round to 2 decimal places
                let weightedScore = cand.score * weight * result.confidence
                candidateVotes[roundedBPM, default: 0.0] += weightedScore
            }
        }

        guard !candidateVotes.isEmpty else {
            // Fallback if all segments were rejected
            let fallback = segmentResults.first?.result.bpm ?? 120.0
            return FusedTempoResult(
                bpm: fallback,
                bpmConfidence: 0.30,
                tempoCandidates: [TempoCandidate(bpm: fallback, score: 1.0, confidence: 0.30)]
            )
        }

        // Sort candidates by total accumulated score
        let sortedCandidates = candidateVotes
            .map { (bpm: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }

        let topScore = max(1e-6, sortedCandidates.first?.score ?? 1.0)
        let fusedCandidates = sortedCandidates.prefix(5).map { item in
            TempoCandidate(
                bpm: item.bpm,
                score: item.score,
                confidence: min(1.0, item.score / topScore)
            )
        }

        let primaryBPM = fusedCandidates.first?.bpm ?? 120.0
        let avgConfidence = totalWeight > 0 ? min(1.0, topScore / totalWeight) : 0.50

        return FusedTempoResult(
            bpm: primaryBPM,
            bpmConfidence: avgConfidence,
            tempoCandidates: fusedCandidates
        )
    }
}
