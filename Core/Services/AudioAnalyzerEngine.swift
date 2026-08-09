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
        
        // Calculate BPM using a native Accelerate vDSP onset detector
        let bpm = await Task.detached(priority: .userInitiated) {
            self.detectBPM(buffer: buffer)
        }.value
        
        // Key detection requires chromagram/FFT. 
        // For now, we leave it nil or placeholder as native accurate key detection is a large endeavor.
        let key: String? = nil
        
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
}
