import AVFoundation
import Accelerate

actor AudioAnalyzerEngine {
    struct AnalysisResult {
        let bpm: Int?
        let key: String?
    }
    
    func analyze(url: URL) async throws -> AnalysisResult {
        // Read file into memory
        let file = try AVAudioFile(forReading: url)
        
        // For performance, only analyze the first 30 seconds
        let sampleRate = file.processingFormat.sampleRate
        let maxDuration: TimeInterval = 30.0
        let framesToRead = AVAudioFrameCount(min(Double(file.length), maxDuration * sampleRate))
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesToRead) else {
            return AnalysisResult(bpm: nil, key: nil)
        }
        
        try file.read(into: buffer, frameCount: framesToRead)
        
        // Calculate BPM and Key natively
        async let bpmTask = Task.detached(priority: .userInitiated) {
            self.detectBPM(buffer: buffer)
        }.value
        
        async let keyTask = Task.detached(priority: .userInitiated) {
            self.detectKey(buffer: buffer)
        }.value
        
        let bpm = await bpmTask
        let key = await keyTask
        
        return AnalysisResult(bpm: bpm, key: key)
    }
    
    // A simplified native BPM detector using amplitude envelope and peak detection
    private nonisolated func detectBPM(buffer: AVAudioPCMBuffer) -> Int? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate
        
        // 1. Mono downmix
        var mono = [Float](repeating: 0.0, count: frameLength)
        for c in 0..<channels {
            let channelBuffer = UnsafeBufferPointer(start: channelData[c], count: frameLength)
            vDSP_vadd(mono, 1, channelBuffer.baseAddress!, 1, &mono, 1, vDSP_Length(frameLength))
        }
        var div = Float(channels)
        vDSP_vsdiv(mono, 1, &div, &mono, 1, vDSP_Length(frameLength))
        
        // 2. Full-wave rectification (absolute value)
        vDSP_vabs(mono, 1, &mono, 1, vDSP_Length(frameLength))
        
        // 3. Envelope extraction (Low pass filter / Decimation)
        // We downsample to ~100 Hz for onset detection
        let targetRate: Float = 100.0
        let windowSize = Int(Float(sampleRate) / targetRate)
        let numWindows = frameLength / windowSize
        
        var envelope = [Float](repeating: 0.0, count: numWindows)
        for i in 0..<numWindows {
            let start = i * windowSize
            var sum: Float = 0
            vDSP_sve(Array(mono[start..<start+windowSize]), 1, &sum, vDSP_Length(windowSize))
            envelope[i] = sum / Float(windowSize)
        }
        
        // 4. First-order difference (onset detection function)
        var diff = [Float](repeating: 0.0, count: numWindows)
        for i in 1..<numWindows {
            let d = envelope[i] - envelope[i - 1]
            diff[i] = max(0, d) // Half-wave rectification
        }
        
        // 5. Peak picking
        var peaks: [Int] = []
        let threshold: Float = 0.05 // Adjust based on dynamic range
        for i in 1..<(numWindows - 1) {
            if diff[i] > diff[i - 1] && diff[i] > diff[i + 1] && diff[i] > threshold {
                peaks.append(i)
            }
        }
        
        guard peaks.count > 2 else { return nil }
        
        // 6. Inter-onset intervals (IOI) in seconds
        var iois: [Float] = []
        for i in 1..<peaks.count {
            let interval = Float(peaks[i] - peaks[i - 1]) / targetRate
            if interval > 0.3 && interval < 1.5 { // ~40 to 200 BPM
                iois.append(interval)
            }
        }
        
        guard !iois.isEmpty else { return nil }
        
        // 7. Find median IOI to estimate BPM
        iois.sort()
        let medianIOI = iois[iois.count / 2]
        
        let estimatedBPM = Int(round(60.0 / medianIOI))
        
        // Clamp to typical music BPM ranges
        if estimatedBPM >= 60 && estimatedBPM <= 200 {
            return estimatedBPM
        }
        return nil
    }
    
    // Natively extract Chromagram via vDSP FFT and compare against Krumhansl-Schmuckler profiles
    private nonisolated func detectKey(buffer: AVAudioPCMBuffer) -> String? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // 1. Mono downmix
        var mono = [Float](repeating: 0.0, count: frameLength)
        for c in 0..<channels {
            let channelBuffer = UnsafeBufferPointer(start: channelData[c], count: frameLength)
            vDSP_vadd(mono, 1, channelBuffer.baseAddress!, 1, &mono, 1, vDSP_Length(frameLength))
        }
        var div = Float(channels)
        vDSP_vsdiv(mono, 1, &div, &mono, 1, vDSP_Length(frameLength))
        
        // 2. Setup FFT
        let fftSize = 4096
        let log2n = vDSP_Length(log2(Float(fftSize)).rounded(.up))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Prepare window (Hann)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HALF_WINDOW))
        
        let halfSize = fftSize / 2
        var globalChroma = [Float](repeating: 0.0, count: 12)
        let numFrames = frameLength / fftSize
        
        // To avoid reallocation inside loop
        var windowedFrame = [Float](repeating: 0.0, count: fftSize)
        var realP = [Float](repeating: 0.0, count: halfSize)
        var imagP = [Float](repeating: 0.0, count: halfSize)
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        
        realP.withUnsafeMutableBufferPointer { realBP in
            imagP.withUnsafeMutableBufferPointer { imagBP in
                var splitComplex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                
                for i in 0..<numFrames {
                    let start = i * fftSize
                    
                    // Apply Window
                    vDSP_vmul(Array(mono[start..<start+fftSize]), 1, window, 1, &windowedFrame, 1, vDSP_Length(fftSize))
                    
                    // Pack data for FFT
                    windowedFrame.withUnsafeBufferPointer { wf in
                        let ptr = UnsafeRawPointer(wf.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }
                    
                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Calculate Magnitudes
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
                    
                    // Map to Chroma
                    for bin in 1..<halfSize {
                        let freq = Float(bin) * sampleRate / Float(fftSize)
                        if freq < 20 || freq > 8000 { continue }
                        
                        // MIDI note: 69 is A4 (440Hz)
                        let note = 12.0 * log2(freq / 440.0) + 69.0
                        let roundedNote = Int(round(note))
                        let chromaClass = ((roundedNote % 12) + 12) % 12
                        
                        // Accumulate magnitude
                        globalChroma[chromaClass] += magnitudes[bin]
                    }
                }
            }
        }
        
        // Normalize global chroma
        var sum: Float = 0
        vDSP_sve(globalChroma, 1, &sum, vDSP_Length(12))
        guard sum > 0 else { return nil }
        vDSP_vsdiv(globalChroma, 1, &sum, &globalChroma, 1, vDSP_Length(12))
        
        // 3. Profile Correlation (Krumhansl-Schmuckler)
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
        
        let pitchClasses = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        
        var bestCorrelation: Float = -1.0
        var bestKey: String? = nil
        
        for i in 0..<12 {
            // Shift profiles
            var shiftedMajor = [Float](repeating: 0, count: 12)
            var shiftedMinor = [Float](repeating: 0, count: 12)
            for j in 0..<12 {
                shiftedMajor[j] = majorProfile[(j - i + 12) % 12]
                shiftedMinor[j] = minorProfile[(j - i + 12) % 12]
            }
            
            // Correlate Major
            let corrMajor = pearsonCorrelation(globalChroma, shiftedMajor)
            if corrMajor > bestCorrelation {
                bestCorrelation = corrMajor
                bestKey = "\(pitchClasses[i]) Major"
            }
            
            // Correlate Minor
            let corrMinor = pearsonCorrelation(globalChroma, shiftedMinor)
            if corrMinor > bestCorrelation {
                bestCorrelation = corrMinor
                bestKey = "\(pitchClasses[i]) Minor"
            }
        }
        
        return bestCorrelation > 0.4 ? bestKey : nil
    }
    
    private nonisolated func pearsonCorrelation(_ x: [Float], _ y: [Float]) -> Float {
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
}
