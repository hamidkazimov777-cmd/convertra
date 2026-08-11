import AVFoundation
import Accelerate

/// A candidate tempo with score and octave ratio.
struct TempoCandidate: Codable, Hashable, Sendable {
    let bpm: Double // High precision (e.g. 127.84)
    let score: Double // Periodicity & prior weighted score
    let confidence: Double // Candidate dominance (0.0 ... 1.0)
}

/// Detailed result of tempo detection on a single segment or fused track.
struct TempoResult: Sendable {
    let bpm: Double // Primary detected BPM
    let confidence: Double // Multi-factor bpmConfidence (0.0 ... 1.0)
    let candidates: [TempoCandidate]
    let onsetEnvelope: [Float] // Combined multi-band onset detection function
    let lowBandOnsetEnergy: Double
    let highBandOnsetEnergy: Double
}

/// Independent Tempo Detector for AudioAnalysisEngine 2.0.
/// Performs Multi-band Onset Detection (Low/Mid/High), Comb Filter periodicity scoring,
/// Soft Bayesian Genre Priors, and Half-Time / Double-Time resolution (50.0 - 220.0 BPM).
actor TempoDetector {
    static let sampleRate: Double = 22050.0
    static let fftSize: Int = 1024
    static let hopSize: Int = 256
    static let frameRate: Double = sampleRate / Double(hopSize) // ~86.13 Hz

    static let minBPM: Double = 50.0
    static let maxBPM: Double = 220.0

    func detectTempo(pcm: [Float]) async -> TempoResult {
        guard pcm.count >= Self.fftSize * 4 else {
            return TempoResult(
                bpm: 120.0,
                confidence: 0.0,
                candidates: [TempoCandidate(bpm: 120.0, score: 0.0, confidence: 0.0)],
                onsetEnvelope: [],
                lowBandOnsetEnergy: 0,
                highBandOnsetEnergy: 0
            )
        }

        // 1. Multi-band Onset Detection (Low: 20-250Hz, Mid: 250-4000Hz, High: 4000-11000Hz)
        let (odfTotal, lowEnergy, highEnergy) = computeMultiBandODF(pcm: pcm)

        guard !odfTotal.isEmpty else {
            return TempoResult(
                bpm: 120.0,
                confidence: 0.0,
                candidates: [TempoCandidate(bpm: 120.0, score: 0.0, confidence: 0.0)],
                onsetEnvelope: [],
                lowBandOnsetEnergy: 0,
                highBandOnsetEnergy: 0
            )
        }

        // 2. Periodicity Analysis over 50.0 ... 220.0 BPM (step 0.5 BPM)
        let rawCandidates = evaluatePeriodicity(odf: odfTotal, lowEnergy: lowEnergy, highEnergy: highEnergy)

        guard let primaryCandidate = rawCandidates.first else {
            return TempoResult(
                bpm: 120.0,
                confidence: 0.0,
                candidates: [],
                onsetEnvelope: odfTotal,
                lowBandOnsetEnergy: Double(lowEnergy),
                highBandOnsetEnergy: Double(highEnergy)
            )
        }

        // 2.5. Silent/flat signal guard: no periodicity score means no confidence
        guard primaryCandidate.score > 1e-5 else {
            return TempoResult(
                bpm: 120.0,
                confidence: 0.0,
                candidates: rawCandidates,
                onsetEnvelope: odfTotal,
                lowBandOnsetEnergy: Double(lowEnergy),
                highBandOnsetEnergy: Double(highEnergy)
            )
        }

        // 3. Compute Multi-Factor bpmConfidence
        let confidence = computeMultiFactorConfidence(
            primary: primaryCandidate,
            candidates: rawCandidates,
            odf: odfTotal
        )

        // 4. DJ-range octave normalization layer: if detected BPM < 85.0 -> * 2.0; if > 170.0 -> / 2.0
        var finalBPM = primaryCandidate.bpm
        if finalBPM < 85.0 {
            finalBPM *= 2.0
        } else if finalBPM > 170.0 {
            finalBPM /= 2.0
        }

        return TempoResult(
            bpm: finalBPM,
            confidence: confidence,
            candidates: rawCandidates,
            onsetEnvelope: odfTotal,
            lowBandOnsetEnergy: Double(lowEnergy),
            highBandOnsetEnergy: Double(highEnergy)
        )
    }

    // MARK: - Multi-band Onset Detection Function (ODF)

    private func computeMultiBandODF(pcm: [Float]) -> ([Float], Float, Float) {
        let log2n = vDSP_Length(log2(Float(Self.fftSize)).rounded(.up))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], 0, 0)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HALF_WINDOW))

        let halfFFT = Self.fftSize / 2
        let binWidth = (Self.sampleRate / 2.0) / Double(halfFFT) // ~21.53 Hz per bin

        // Frequency Band Boundaries in Bins
        let lowRange = 1...max(1, Int(250.0 / binWidth)) // ~20-250 Hz (Kick/Sub-bass)
        let midRange = (lowRange.upperBound + 1)...min(halfFFT - 1, Int(4000.0 / binWidth)) // ~250-4000 Hz (Snare/Synths)
        let highRange = (midRange.upperBound + 1)..<halfFFT // ~4000-11000 Hz (Hi-hats)

        let numFrames = (pcm.count - Self.fftSize) / Self.hopSize + 1
        guard numFrames > 10 else { return ([], 0, 0) }

        var odfLow = [Float](repeating: 0, count: numFrames)
        var odfMid = [Float](repeating: 0, count: numFrames)
        var odfHigh = [Float](repeating: 0, count: numFrames)

        var prevLowMag = [Float](repeating: 0, count: lowRange.count)
        var prevMidMag = [Float](repeating: 0, count: midRange.count)
        var prevHighMag = [Float](repeating: 0, count: highRange.count)

        var windowedFrame = [Float](repeating: 0, count: Self.fftSize)
        var realP = [Float](repeating: 0, count: halfFFT)
        var imagP = [Float](repeating: 0, count: halfFFT)
        var magnitudes = [Float](repeating: 0, count: halfFFT)

        realP.withUnsafeMutableBufferPointer { realBP in
            imagP.withUnsafeMutableBufferPointer { imagBP in
                var splitComplex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)

                for t in 0..<numFrames {
                    let start = t * Self.hopSize

                    // Apply window
                    vDSP_vmul(Array(pcm[start..<start + Self.fftSize]), 1, window, 1, &windowedFrame, 1, vDSP_Length(Self.fftSize))

                    // Pack for FFT
                    windowedFrame.withUnsafeBufferPointer { wf in
                        let ptr = UnsafeRawPointer(wf.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(halfFFT))
                    }

                    // Forward FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                    // Magnitudes
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfFFT))
                    var count = Int32(halfFFT)
                    vvsqrtf(&magnitudes, magnitudes, &count)

                    // Low Band Spectral Difference
                    var lowDiff: Float = 0
                    for (idx, bin) in lowRange.enumerated() {
                        let diff = max(0, magnitudes[bin] - prevLowMag[idx])
                        lowDiff += diff
                        prevLowMag[idx] = magnitudes[bin]
                    }
                    odfLow[t] = lowDiff

                    // Mid Band Spectral Difference
                    var midDiff: Float = 0
                    for (idx, bin) in midRange.enumerated() {
                        let diff = max(0, magnitudes[bin] - prevMidMag[idx])
                        midDiff += diff
                        prevMidMag[idx] = magnitudes[bin]
                    }
                    odfMid[t] = midDiff

                    // High Band Spectral Difference
                    var highDiff: Float = 0
                    for (idx, bin) in highRange.enumerated() {
                        let diff = max(0, magnitudes[bin] - prevHighMag[idx])
                        highDiff += diff
                        prevHighMag[idx] = magnitudes[bin]
                    }
                    odfHigh[t] = highDiff
                }
            }
        }

        // Normalize each band ODF by its mean
        normalizeODF(&odfLow)
        normalizeODF(&odfMid)
        normalizeODF(&odfHigh)

        var totalLowEnergy: Float = 0
        var totalHighEnergy: Float = 0
        vDSP_sve(odfLow, 1, &totalLowEnergy, vDSP_Length(numFrames))
        vDSP_sve(odfHigh, 1, &totalHighEnergy, vDSP_Length(numFrames))

        // Combine bands: Low (0.5), Mid (0.3), High (0.2)
        var odfTotal = [Float](repeating: 0, count: numFrames)
        for t in 0..<numFrames {
            odfTotal[t] = 0.50 * odfLow[t] + 0.30 * odfMid[t] + 0.20 * odfHigh[t]
        }

        return (odfTotal, totalLowEnergy, totalHighEnergy)
    }

    private func normalizeODF(_ odf: inout [Float]) {
        var mean: Float = 0
        vDSP_meanv(odf, 1, &mean, vDSP_Length(odf.count))
        guard mean > 0 else { return }
        var div = mean
        vDSP_vsdiv(odf, 1, &div, &odf, 1, vDSP_Length(odf.count))
    }

    // MARK: - Periodicity & Half/Double-Time Disambiguation

    private func evaluatePeriodicity(odf: [Float], lowEnergy: Float, highEnergy: Float) -> [TempoCandidate] {
        let numFrames = odf.count
        guard numFrames > 20 else { return [] }

        var candidates: [TempoCandidate] = []
        let bpmStep: Double = 0.5

        // Search Grid: 50.0 to 220.0 BPM
        var bpmList: [Double] = []
        var scoreList: [Double] = []

        var currentBPM = Self.minBPM
        while currentBPM <= Self.maxBPM {
            let lagFrames = Self.frameRate * 60.0 / currentBPM
            let lag = Int(round(lagFrames))

            if lag > 0 && lag < numFrames / 2 {
                var sum: Float = 0
                let elementsToProcess = numFrames - lag
                odf.withUnsafeBufferPointer { ptr in
                    vDSP_dotpr(ptr.baseAddress!, 1, ptr.baseAddress! + lag, 1, &sum, vDSP_Length(elementsToProcess))
                }

                var periodicityScore = Double(sum / Float(elementsToProcess))

                // Correct integer-lag quantization bias: the dot product measures the true
                // periodicity at `lag` frames, whereas the nominal grid BPM may differ by up
                // to ~0.25 frames at high tempi. Attenuate with a Gaussian on the offset so
                // the grid reflects the analyzed periodicity instead of boosting neighbours
                // that alias onto the same integer lag.
                let lagOffset = abs(lagFrames - Double(lag)) // 0.0 ... 0.5 frames
                periodicityScore *= exp(-8.0 * lagOffset * lagOffset)

                // Apply Soft Bayesian Genre Prior (Wide distribution centered around 120, 140, 174)
                let prior = softGenrePrior(bpm: currentBPM)
                periodicityScore *= (1.0 + 0.15 * prior)

                bpmList.append(currentBPM)
                scoreList.append(periodicityScore)
            }
            currentBPM += bpmStep
        }

        guard !bpmList.isEmpty else { return [] }

        // Find top peak indices
        let sortedIndices = scoreList.indices.sorted { scoreList[$0] > scoreList[$1] }
        var topBPMs: [(bpm: Double, score: Double)] = []

        for idx in sortedIndices {
            let bpm = bpmList[idx]
            let score = scoreList[idx]

            // Ensure candidates are distinct (not within 3.0 BPM of each other)
            if !topBPMs.contains(where: { abs($0.bpm - bpm) < 3.0 }) {
                topBPMs.append((bpm, score))
            }
            if topBPMs.count >= 5 { break }
        }

        guard !topBPMs.isEmpty else { return [] }

        // Perform Half-Time / Double-Time Disambiguation (e.g., 174 vs 87, 75 vs 150)
        let resolvedPrimary = resolveOctaveAmbiguity(
            primary: topBPMs[0],
            candidates: topBPMs,
            lowEnergy: lowEnergy,
            highEnergy: highEnergy
        )

        // Build Candidate list
        let maxScore = max(1e-6, resolvedPrimary.score)
        for cand in topBPMs {
            let isPrimary = abs(cand.bpm - resolvedPrimary.bpm) < 1.5
            let bpmValue = isPrimary ? resolvedPrimary.bpm : cand.bpm
            let scoreValue = isPrimary ? resolvedPrimary.score : cand.score
            let conf = min(1.0, scoreValue / maxScore)

            if !candidates.contains(where: { abs($0.bpm - bpmValue) < 1.5 }) {
                candidates.append(TempoCandidate(bpm: bpmValue, score: scoreValue, confidence: conf))
            }
        }

        // Sort by score descending
        return candidates.sorted { $0.score > $1.score }
    }

    private func resolveOctaveAmbiguity(
        primary: (bpm: Double, score: Double),
        candidates: [(bpm: Double, score: Double)],
        lowEnergy: Float,
        highEnergy: Float
    ) -> (bpm: Double, score: Double) {
        let pBPM = primary.bpm

        // 1. DnB Check (160-180 BPM range):
        // If primary is ~87 BPM (Half-time of 174 BPM) and high energy (hi-hats) is strong
        if (75.0...95.0).contains(pBPM) {
            let doubleBPM = pBPM * 2.0
            if (150.0...190.0).contains(doubleBPM) {
                let highToLowRatio = lowEnergy > 0 ? (highEnergy / lowEnergy) : 0
                // High hat activity in DnB indicates full-time 174 BPM
                if highToLowRatio > 0.35 || candidates.contains(where: { abs($0.bpm - doubleBPM) < 4.0 }) {
                    return (bpm: doubleBPM, score: primary.score * 1.15)
                }
            }
        }

        // 2. Hip-Hop / Trap Check (70-105 BPM range):
        // If primary is ~150 BPM (Double-time of 75 BPM) and low sub-bass energy dominates
        if (140.0...190.0).contains(pBPM) {
            let halfBPM = pBPM / 0.5
            let halfBPMActual = pBPM * 0.5
            if (65.0...95.0).contains(halfBPMActual) {
                let lowToHighRatio = highEnergy > 0 ? (lowEnergy / highEnergy) : 0
                // Strong sub-bass kick with sparse snare favours half-time (75 BPM)
                if lowToHighRatio > 2.5 {
                    return (bpm: halfBPMActual, score: primary.score * 1.15)
                }
            }
        }

        return primary
    }

    private func softGenrePrior(bpm: Double) -> Double {
        // Gaussian mixture over common DJ tempos: 124 BPM (House/Techno), 140 BPM (Dubstep/Trance), 174 BPM (DnB), 90 BPM (Hip-Hop)
        let centers: [Double] = [124.0, 128.0, 140.0, 174.0, 90.0]
        var maxPrior: Double = 0.0

        for center in centers {
            let dist = (bpm - center) / 15.0
            let prior = exp(-0.5 * dist * dist)
            if prior > maxPrior {
                maxPrior = prior
            }
        }
        return maxPrior
    }

    // MARK: - Multi-Factor Confidence Scoring

    private func computeMultiFactorConfidence(
        primary: TempoCandidate,
        candidates: [TempoCandidate],
        odf: [Float]
    ) -> Double {
        guard !odf.isEmpty else { return 0.0 }

        // 1. Peak-to-Mean Ratio (PMR) of ODF
        var meanODF: Float = 0
        var maxODF: Float = 0
        vDSP_meanv(odf, 1, &meanODF, vDSP_Length(odf.count))
        vDSP_maxv(odf, 1, &maxODF, vDSP_Length(odf.count))

        let pmr = meanODF > 0 ? Double(maxODF / meanODF) : 1.0
        let pmrScore = min(1.0, max(0.0, (pmr - 2.0) / 8.0))

        // 2. Candidate Dominance (Ratio of 1st vs 2nd candidate)
        var dominanceScore: Double = 1.0
        if candidates.count >= 2 {
            let second = candidates[1]
            if second.score > 0 {
                let ratio = primary.score / second.score
                dominanceScore = min(1.0, max(0.0, (ratio - 1.0) / 1.5))
            }
        }

        // Combine into final bpmConfidence (0.0 ... 1.0)
        let totalConfidence = 0.60 * pmrScore + 0.40 * dominanceScore
        return min(1.0, max(0.0, totalConfidence))
    }
}
