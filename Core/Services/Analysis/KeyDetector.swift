import AVFoundation
import Accelerate

/// A candidate key with correlation score and Camelot code.
struct KeyCandidate: Codable, Hashable, Sendable {
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
    let chromagram: [Float] // 12-element pitch class profile [C, C#, D, D#, E, F, F#, G, G#, A, A#, B]
}

/// Independent Key Detector for AudioAnalysisEngine 2.0.
/// Uses Log-Warped FFT Filterbank (CQT equivalent), 12-bin Pitch Class Profile (PCP) Chroma extraction,
/// Multi-profile correlation (Sha'ath & Temperley), Camelot mapping, and multi-factor confidence scoring.
actor KeyDetector {
    static let sampleRate: Double = 22050.0
    static let fftSize: Int = 4096
    static let hopSize: Int = 2048
    static let halfFFT: Int = fftSize / 2 // 2048 bins

    // Precomputed bin-to-chroma mapping table
    private let binToChroma: [Int] // Size: 2048, maps FFT bin -> chroma index (0...11) or -1 if ignored
    private let binWeights: [Float] // Weight factor for bin

    init() {
        var map = [Int](repeating: -1, count: Self.halfFFT)
        var weights = [Float](repeating: 0.0, count: Self.halfFFT)

        let binWidth = (Self.sampleRate / 2.0) / Double(Self.halfFFT) // ~5.3833 Hz per bin

        for bin in 1..<Self.halfFFT {
            let freq = Double(bin) * binWidth
            // Ignore frequencies outside 30 Hz - 4200 Hz (C1 to C8 range)
            if freq >= 30.0 && freq <= 4200.0 {
                let note = 12.0 * log2(freq / 440.0) + 69.0
                let roundedNote = Int(round(note))
                let chromaClass = ((roundedNote % 12) + 12) % 12
                map[bin] = chromaClass

                // A440 tuning weight: boost fundamental bass & mid frequencies
                let weight: Float = (freq < 500.0) ? 1.5 : 1.0
                weights[bin] = weight
            }
        }
        self.binToChroma = map
        self.binWeights = weights
    }

    /// Detects key from a PCM signal (preferably the Harmonic component from SignalPreprocessor).
    func detectKey(pcm: [Float]) async -> KeyResult {
        guard pcm.count >= Self.fftSize else {
            let fallbackKey = MusicalKey.cMajor
            return KeyResult(
                musicalKey: fallbackKey,
                camelotKey: fallbackKey.camelotKey,
                confidence: 0.0,
                candidates: [],
                chromagram: [Float](repeating: 0, count: 12)
            )
        }

        // 1. Extract 12-element Pitch Class Profile (Chromagram)
        let (chroma, frameStability) = extractChromagram(pcm: pcm)

        // 2. Correlate Chromagram against EDM Major & Minor Key Profiles
        let rawCandidates = correlateProfiles(chroma: chroma)

        guard let topCandidate = rawCandidates.first else {
            let fallbackKey = MusicalKey.cMajor
            return KeyResult(
                musicalKey: fallbackKey,
                camelotKey: fallbackKey.camelotKey,
                confidence: 0.0,
                candidates: [],
                chromagram: chroma
            )
        }

        // 3. Compute Multi-Factor keyConfidence
        let confidence = computeKeyConfidence(
            primary: topCandidate,
            candidates: rawCandidates,
            frameStability: frameStability
        )

        // 4. Confidence-based Top-2 fallback (if confidence < 0.70 -> select Top-2 candidate)
        let selectedCandidate: KeyCandidate
        if confidence < 0.70 && rawCandidates.count >= 2 {
            selectedCandidate = rawCandidates[1]
        } else {
            selectedCandidate = topCandidate
        }

        return KeyResult(
            musicalKey: selectedCandidate.musicalKey,
            camelotKey: selectedCandidate.camelotKey,
            confidence: confidence,
            candidates: rawCandidates,
            chromagram: chroma
        )
    }

    // MARK: - Chromagram Extraction via Log-Warped FFT

    private func extractChromagram(pcm: [Float]) -> ([Float], Double) {
        let log2n = vDSP_Length(log2(Float(Self.fftSize)).rounded(.up))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ([Float](repeating: 0, count: 12), 0.0)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HALF_WINDOW))

        let numFrames = (pcm.count - Self.fftSize) / Self.hopSize + 1
        guard numFrames > 0 else {
            return ([Float](repeating: 0, count: 12), 0.0)
        }

        var globalChroma = [Float](repeating: 0.0, count: 12)
        var frameChromaVectors = [[Float]]()
        frameChromaVectors.reserveCapacity(numFrames)

        var windowedFrame = [Float](repeating: 0, count: Self.fftSize)
        var realP = [Float](repeating: 0, count: Self.halfFFT)
        var imagP = [Float](repeating: 0, count: Self.halfFFT)
        var magnitudes = [Float](repeating: 0, count: Self.halfFFT)

        realP.withUnsafeMutableBufferPointer { realBP in
            imagP.withUnsafeMutableBufferPointer { imagBP in
                var splitComplex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)

                for frameIdx in 0..<numFrames {
                    let start = frameIdx * Self.hopSize

                    // Apply window
                    vDSP_vmul(Array(pcm[start..<start + Self.fftSize]), 1, window, 1, &windowedFrame, 1, vDSP_Length(Self.fftSize))

                    // Pack for FFT
                    windowedFrame.withUnsafeBufferPointer { wf in
                        let ptr = UnsafeRawPointer(wf.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(Self.halfFFT))
                    }

                    // Forward FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                    // Calculate Magnitudes
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(Self.halfFFT))
                    var count = Int32(Self.halfFFT)
                    vvsqrtf(&magnitudes, magnitudes, &count)

                    var frameChroma = [Float](repeating: 0.0, count: 12)

                    // Map FFT bins to 12 chroma classes
                    for bin in 1..<Self.halfFFT {
                        let chromaClass = binToChroma[bin]
                        if chromaClass >= 0 {
                            let mag = magnitudes[bin] * binWeights[bin]
                            frameChroma[chromaClass] += mag
                            globalChroma[chromaClass] += mag
                        }
                    }

                    // Normalize frame chroma
                    var sum: Float = 0
                    vDSP_sve(frameChroma, 1, &sum, vDSP_Length(12))
                    if sum > 0 {
                        vDSP_vsdiv(frameChroma, 1, &sum, &frameChroma, 1, vDSP_Length(12))
                    }
                    frameChromaVectors.append(frameChroma)
                }
            }
        }

        // Normalize global chroma
        var globalSum: Float = 0
        vDSP_sve(globalChroma, 1, &globalSum, vDSP_Length(12))
        if globalSum > 0 {
            vDSP_vsdiv(globalChroma, 1, &globalSum, &globalChroma, 1, vDSP_Length(12))
        }

        // Calculate Temporal Chroma Stability across frames
        var stabilitySum: Float = 0.0
        if numFrames > 1 {
            for i in 1..<numFrames {
                let corr = pearsonCorrelation(frameChromaVectors[i - 1], frameChromaVectors[i])
                stabilitySum += max(0, corr)
            }
            stabilitySum /= Float(numFrames - 1)
        }

        return (globalChroma, Double(stabilitySum))
    }

    // MARK: - Multi-Profile Correlation (Sha'ath & Temperley)

    private func correlateProfiles(chroma: [Float]) -> [KeyCandidate] {
        // Sha'ath EDM Key Profiles
        let shaathMajor: [Float] = [24.0, 2.5, 11.5, 3.0, 15.5, 12.0, 3.0, 18.0, 3.5, 9.5, 3.0, 8.5]
        let shaathMinor: [Float] = [24.0, 4.0, 13.5, 14.5, 6.0, 10.5, 4.5, 18.0, 8.5, 7.5, 4.0, 6.0]

        // Temperley Classical Key Profiles
        let temperleyMajor: [Float] = [5.0, 2.0, 3.5, 2.0, 4.5, 4.0, 2.0, 4.5, 2.0, 3.5, 1.5, 4.0]
        let temperleyMinor: [Float] = [5.0, 2.0, 3.5, 4.5, 2.0, 4.0, 2.0, 4.5, 3.5, 2.0, 1.5, 4.0]

        let pitchClasses: [MusicalKey] = [
            .cMajor, .cSharpMajor, .dMajor, .dSharpMajor, .eMajor, .fMajor,
            .fSharpMajor, .gMajor, .gSharpMajor, .aMajor, .aSharpMajor, .bMajor
        ]

        let minorClasses: [MusicalKey] = [
            .cMinor, .cSharpMinor, .dMinor, .dSharpMinor, .eMinor, .fMinor,
            .fSharpMinor, .gMinor, .gSharpMinor, .aMinor, .aSharpMinor, .bMinor
        ]

        var candidates: [KeyCandidate] = []

        for i in 0..<12 {
            var shiftShaathMajor = [Float](repeating: 0, count: 12)
            var shiftShaathMinor = [Float](repeating: 0, count: 12)
            var shiftTempMajor = [Float](repeating: 0, count: 12)
            var shiftTempMinor = [Float](repeating: 0, count: 12)

            for j in 0..<12 {
                let idx = (j - i + 12) % 12
                shiftShaathMajor[j] = shaathMajor[idx]
                shiftShaathMinor[j] = shaathMinor[idx]
                shiftTempMajor[j] = temperleyMajor[idx]
                shiftTempMinor[j] = temperleyMinor[idx]
            }

            // Calculate Pearson correlations
            let corrShaathMaj = Double(pearsonCorrelation(chroma, shiftShaathMajor))
            let corrShaathMin = Double(pearsonCorrelation(chroma, shiftShaathMinor))
            let corrTempMaj = Double(pearsonCorrelation(chroma, shiftTempMajor))
            let corrTempMin = Double(pearsonCorrelation(chroma, shiftTempMinor))

            // Weighted average of Sha'ath (70%) and Temperley (30%)
            let majScore = 0.70 * corrShaathMaj + 0.30 * corrTempMaj
            let minScore = 0.70 * corrShaathMin + 0.30 * corrTempMin

            let majKey = pitchClasses[i]
            let minKey = minorClasses[i]

            candidates.append(KeyCandidate(musicalKey: majKey, camelotKey: majKey.camelotKey, correlation: majScore))
            candidates.append(KeyCandidate(musicalKey: minKey, camelotKey: minKey.camelotKey, correlation: minScore))
        }

        // Sort by correlation score descending
        return candidates.sorted { $0.correlation > $1.correlation }
    }

    private func pearsonCorrelation(_ x: [Float], _ y: [Float]) -> Float {
        let n = Float(x.count)
        var sumX: Float = 0, sumY: Float = 0, sumSqX: Float = 0, sumSqY: Float = 0, sumXY: Float = 0

        vDSP_sve(x, 1, &sumX, vDSP_Length(x.count))
        vDSP_sve(y, 1, &sumY, vDSP_Length(y.count))
        vDSP_svesq(x, 1, &sumSqX, vDSP_Length(x.count))
        vDSP_svesq(y, 1, &sumSqY, vDSP_Length(y.count))
        vDSP_dotpr(x, 1, y, 1, &sumXY, vDSP_Length(x.count))

        let num = (n * sumXY) - (sumX * sumY)
        let den = sqrt((n * sumSqX - sumX * sumX) * (n * sumSqY - sumY * sumY))

        return den == 0 ? 0 : num / den
    }

    // MARK: - Multi-Factor Confidence Scoring

    private func computeKeyConfidence(
        primary: KeyCandidate,
        candidates: [KeyCandidate],
        frameStability: Double
    ) -> Double {
        // 1. Peak Correlation Score (0.0 ... 1.0)
        let peakScore = min(1.0, max(0.0, (primary.correlation - 0.20) / 0.60))

        // 2. Candidate Margin (Top 1 minus Top 2)
        var marginScore: Double = 0.50
        if candidates.count >= 2 {
            let second = candidates[1]
            let margin = primary.correlation - second.correlation
            marginScore = min(1.0, max(0.0, margin / 0.20))
        }

        // 3. Combine Peak Score, Candidate Margin, and Frame Stability
        let confidence = 0.50 * peakScore + 0.30 * marginScore + 0.20 * frameStability
        return min(1.0, max(0.0, confidence))
    }
}
