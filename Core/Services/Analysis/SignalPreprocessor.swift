import AVFoundation
import Accelerate

/// Result of Harmonic-Percussive Source Separation (HPSS) on an audio segment.
struct PreprocessedSignal: Sendable {
    let segmentType: AudioSegment.SegmentType
    let sampleRate: Double // Always 22050.0
    let harmonicPCM: [Float] // Isolated tonal/harmonic signal (synths, bass notes, vocals)
    let percussivePCM: [Float] // Isolated transient/percussive signal (kick, snare, hats)
    let harmonicEnergyRatio: Double // Ratio of harmonic to total energy (0.0 ... 1.0)
    let percussiveEnergyRatio: Double // Ratio of percussive to total energy (0.0 ... 1.0)
}

/// Independent Signal Preprocessor for AudioAnalysisEngine 2.0.
/// Performs Sliding-Context HPSS (Harmonic-Percussive Source Separation) using Accelerate vDSP.
/// Memory footprint per worker thread <= 5 MB (target <= 25 MB).
actor SignalPreprocessor {
    static let sampleRate: Double = 22050.0
    static let fftSize: Int = 2048
    static let hopSize: Int = 512
    static let halfFFT: Int = fftSize / 2 // 1024 bins
    static let harmonicMedianLength: Int = 15 // Time frames (~0.35s)
    static let percussiveMedianLength: Int = 9 // Frequency bins (~96.9Hz)

    /// Processes an AudioSegment through HPSS, returning isolated Harmonic and Percussive signals.
    func process(segment: AudioSegment) async -> PreprocessedSignal {
        let inputPCM = segment.pcmData
        guard inputPCM.count >= Self.fftSize else {
            // Fallback for extremely short PCM: return original for both
            let totalEnergy = computeEnergy(inputPCM)
            return PreprocessedSignal(
                segmentType: segment.type,
                sampleRate: segment.sampleRate,
                harmonicPCM: inputPCM,
                percussivePCM: inputPCM,
                harmonicEnergyRatio: 0.5,
                percussiveEnergyRatio: 0.5
            )
        }

        // 1. Compute STFT magnitude spectrogram and phase complex frames
        let (spectrogram, complexFrames) = computeSTFT(pcm: inputPCM)
        let numFrames = spectrogram.count
        guard numFrames > 0 else {
            return PreprocessedSignal(
                segmentType: segment.type,
                sampleRate: segment.sampleRate,
                harmonicPCM: inputPCM,
                percussivePCM: inputPCM,
                harmonicEnergyRatio: 0.5,
                percussiveEnergyRatio: 0.5
            )
        }

        // 2. Perform Sliding 2D Median Filtering (HPSS)
        let (harmonicSpec, percussiveSpec) = separateHarmonicPercussive(spectrogram: spectrogram)

        // 3. Apply Soft Wiener Masking to Complex STFT Frames & Resynthesize (ISTFT)
        let (harmonicPCM, percussivePCM) = resynthesize(
            complexFrames: complexFrames,
            spectrogram: spectrogram,
            harmonicSpec: harmonicSpec,
            percussiveSpec: percussiveSpec,
            targetLength: inputPCM.count
        )

        // 4. Calculate Energy Ratios
        let harmonicEnergy = computeEnergy(harmonicPCM)
        let percussiveEnergy = computeEnergy(percussivePCM)
        let totalEnergy = harmonicEnergy + percussiveEnergy
        let hRatio = totalEnergy > 0 ? Double(harmonicEnergy / totalEnergy) : 0.5
        let pRatio = totalEnergy > 0 ? Double(percussiveEnergy / totalEnergy) : 0.5

        return PreprocessedSignal(
            segmentType: segment.type,
            sampleRate: segment.sampleRate,
            harmonicPCM: harmonicPCM,
            percussivePCM: percussivePCM,
            harmonicEnergyRatio: hRatio,
            percussiveEnergyRatio: pRatio
        )
    }

    // MARK: - STFT Computation via vDSP

    private struct STFTFrame {
        var real: [Float]
        var imag: [Float]
    }

    private func computeSTFT(pcm: [Float]) -> ([[Float]], [STFTFrame]) {
        let log2n = vDSP_Length(log2(Float(Self.fftSize)).rounded(.up))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HALF_WINDOW))

        let numFrames = (pcm.count - Self.fftSize) / Self.hopSize + 1
        var spectrogram = [[Float]]()
        spectrogram.reserveCapacity(numFrames)

        var complexFrames = [STFTFrame]()
        complexFrames.reserveCapacity(numFrames)

        var windowedFrame = [Float](repeating: 0, count: Self.fftSize)
        var realP = [Float](repeating: 0, count: Self.halfFFT)
        var imagP = [Float](repeating: 0, count: Self.halfFFT)
        var magnitudes = [Float](repeating: 0, count: Self.halfFFT)

        realP.withUnsafeMutableBufferPointer { realBP in
            imagP.withUnsafeMutableBufferPointer { imagBP in
                var splitComplex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)

                for frameIdx in 0..<numFrames {
                    let start = frameIdx * Self.hopSize

                    // Apply Hann window
                    vDSP_vmul(Array(pcm[start..<start + Self.fftSize]), 1, window, 1, &windowedFrame, 1, vDSP_Length(Self.fftSize))

                    // Pack into split complex for FFT
                    windowedFrame.withUnsafeBufferPointer { wf in
                        let ptr = UnsafeRawPointer(wf.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(Self.halfFFT))
                    }

                    // Forward FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                    // Store complex values for ISTFT
                    complexFrames.append(STFTFrame(real: Array(realBP), imag: Array(imagBP)))

                    // Calculate magnitudes: sqrt(real^2 + imag^2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(Self.halfFFT))
                    var count = Int32(Self.halfFFT)
                    vvsqrtf(&magnitudes, magnitudes, &count)

                    spectrogram.append(magnitudes)
                }
            }
        }

        return (spectrogram, complexFrames)
    }

    // MARK: - Sliding 2D Median Filtering (HPSS Core)

    private func separateHarmonicPercussive(spectrogram: [[Float]]) -> ([[Float]], [[Float]]) {
        let numFrames = spectrogram.count
        let numBins = Self.halfFFT

        var harmonicSpec = [[Float]](repeating: [Float](repeating: 0, count: numBins), count: numFrames)
        var percussiveSpec = [[Float]](repeating: [Float](repeating: 0, count: numBins), count: numFrames)

        let hHalf = Self.harmonicMedianLength / 2
        let pHalf = Self.percussiveMedianLength / 2

        var hBuffer = [Float](repeating: 0, count: Self.harmonicMedianLength)
        var pBuffer = [Float](repeating: 0, count: Self.percussiveMedianLength)

        // 1. Harmonic Filter: 1D Median along Time Axis (for each frequency bin)
        for bin in 0..<numBins {
            for t in 0..<numFrames {
                for i in 0..<Self.harmonicMedianLength {
                    let frameIdx = min(max(0, t - hHalf + i), numFrames - 1)
                    hBuffer[i] = spectrogram[frameIdx][bin]
                }
                harmonicSpec[t][bin] = quickMedian15(&hBuffer)
            }
        }

        // 2. Percussive Filter: 1D Median along Frequency Axis (for each time frame)
        for t in 0..<numFrames {
            let frame = spectrogram[t]
            for bin in 0..<numBins {
                for i in 0..<Self.percussiveMedianLength {
                    let binIdx = min(max(0, bin - pHalf + i), numBins - 1)
                    pBuffer[i] = frame[binIdx]
                }
                percussiveSpec[t][bin] = quickMedian9(&pBuffer)
            }
        }

        return (harmonicSpec, percussiveSpec)
    }

    // MARK: - Resynthesis via Wiener Masking & ISTFT

    private func resynthesize(
        complexFrames: [STFTFrame],
        spectrogram: [[Float]],
        harmonicSpec: [[Float]],
        percussiveSpec: [[Float]],
        targetLength: Int
    ) -> ([Float], [Float]) {
        let log2n = vDSP_Length(log2(Float(Self.fftSize)).rounded(.up))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let numFrames = complexFrames.count
        var harmonicPCM = [Float](repeating: 0, count: targetLength)
        var percussivePCM = [Float](repeating: 0, count: targetLength)

        var synthWindow = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&synthWindow, vDSP_Length(Self.fftSize), Int32(vDSP_HALF_WINDOW))

        // Normalization factor for overlap-add (OLA) with 75% overlap Hann window
        let olaScale: Float = 2.0 / Float(Self.fftSize)

        var hReal = [Float](repeating: 0, count: Self.halfFFT)
        var hImag = [Float](repeating: 0, count: Self.halfFFT)
        var pReal = [Float](repeating: 0, count: Self.halfFFT)
        var pImag = [Float](repeating: 0, count: Self.halfFFT)
        var timeFrame = [Float](repeating: 0, count: Self.fftSize)

        for frameIdx in 0..<numFrames {
            let start = frameIdx * Self.hopSize
            guard start + Self.fftSize <= targetLength else { break }

            let frame = complexFrames[frameIdx]
            let hMag = harmonicSpec[frameIdx]
            let pMag = percussiveSpec[frameIdx]

            // Calculate Wiener Soft Masks:
            // M_h = H^2 / (H^2 + P^2 + eps)
            // M_p = P^2 / (H^2 + P^2 + eps)
            for bin in 0..<Self.halfFFT {
                let hSq = hMag[bin] * hMag[bin]
                let pSq = pMag[bin] * pMag[bin]
                let totalSq = hSq + pSq + 1e-9

                let mH = hSq / totalSq
                let mP = pSq / totalSq

                hReal[bin] = frame.real[bin] * mH
                hImag[bin] = frame.imag[bin] * mH
                pReal[bin] = frame.real[bin] * mP
                pImag[bin] = frame.imag[bin] * mP
            }

            // ISTFT for Harmonic Frame
            hReal.withUnsafeMutableBufferPointer { hrBP in
                hImag.withUnsafeMutableBufferPointer { hiBP in
                    var splitH = DSPSplitComplex(realp: hrBP.baseAddress!, imagp: hiBP.baseAddress!)
                    vDSP_fft_zrip(fftSetup, &splitH, 1, log2n, FFTDirection(FFT_INVERSE))
                    timeFrame.withUnsafeMutableBufferPointer { tfBP in
                        let ptr = UnsafeMutableRawPointer(tfBP.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ztoc(&splitH, 1, ptr, 2, vDSP_Length(Self.halfFFT))
                    }
                }
            }

            // Apply synthesis window & overlap-add to harmonicPCM
            vDSP_vmul(timeFrame, 1, synthWindow, 1, &timeFrame, 1, vDSP_Length(Self.fftSize))
            var scale = olaScale
            vDSP_vsmul(timeFrame, 1, &scale, &timeFrame, 1, vDSP_Length(Self.fftSize))
            vDSP_vadd(Array(harmonicPCM[start..<start + Self.fftSize]), 1, timeFrame, 1, &harmonicPCM[start], 1, vDSP_Length(Self.fftSize))

            // ISTFT for Percussive Frame
            pReal.withUnsafeMutableBufferPointer { prBP in
                pImag.withUnsafeMutableBufferPointer { piBP in
                    var splitP = DSPSplitComplex(realp: prBP.baseAddress!, imagp: piBP.baseAddress!)
                    vDSP_fft_zrip(fftSetup, &splitP, 1, log2n, FFTDirection(FFT_INVERSE))
                    timeFrame.withUnsafeMutableBufferPointer { tfBP in
                        let ptr = UnsafeMutableRawPointer(tfBP.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ztoc(&splitP, 1, ptr, 2, vDSP_Length(Self.halfFFT))
                    }
                }
            }

            // Apply synthesis window & overlap-add to percussivePCM
            vDSP_vmul(timeFrame, 1, synthWindow, 1, &timeFrame, 1, vDSP_Length(Self.fftSize))
            vDSP_vsmul(timeFrame, 1, &scale, &timeFrame, 1, vDSP_Length(Self.fftSize))
            vDSP_vadd(Array(percussivePCM[start..<start + Self.fftSize]), 1, timeFrame, 1, &percussivePCM[start], 1, vDSP_Length(Self.fftSize))
        }

        return (harmonicPCM, percussivePCM)
    }

    // MARK: - Fast Median Helpers

    @inline(__always)
    private func quickMedian15(_ buf: inout [Float]) -> Float {
        // Insertion sort for 15 elements
        for i in 1..<15 {
            let key = buf[i]
            var j = i - 1
            while j >= 0 && buf[j] > key {
                buf[j + 1] = buf[j]
                j -= 1
            }
            buf[j + 1] = key
        }
        return buf[7]
    }

    @inline(__always)
    private func quickMedian9(_ buf: inout [Float]) -> Float {
        // Insertion sort for 9 elements
        for i in 1..<9 {
            let key = buf[i]
            var j = i - 1
            while j >= 0 && buf[j] > key {
                buf[j + 1] = buf[j]
                j -= 1
            }
            buf[j + 1] = key
        }
        return buf[4]
    }

    private func computeEnergy(_ pcm: [Float]) -> Float {
        guard !pcm.isEmpty else { return 0 }
        var energy: Float = 0
        vDSP_svesq(pcm, 1, &energy, vDSP_Length(pcm.count))
        return energy
    }
}
