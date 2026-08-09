import Foundation
import AVFoundation

actor WaveformAnalyzer {
    struct WaveformData: Sendable {
        let samples: [Float] // Normalized 0...1
    }
    
    func generateWaveform(for url: URL, targetSampleCount: Int = 100) async throws -> WaveformData {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return WaveformData(samples: [])
        }
        
        try file.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData else {
            return WaveformData(samples: [])
        }
        
        let frames = Int(buffer.frameLength)
        let channels = Int(format.channelCount)
        let samplesPerPixel = max(1, frames / targetSampleCount)
        
        var downsampled = [Float]()
        downsampled.reserveCapacity(targetSampleCount)
        
        var globalMax: Float = 0.0
        
        for i in 0..<targetSampleCount {
            let start = i * samplesPerPixel
            let end = min(start + samplesPerPixel, frames)
            
            var maxAmplitude: Float = 0.0
            if start < end {
                for c in 0..<channels {
                    let channelBuffer = UnsafeBufferPointer(start: channelData[c], count: frames)
                    for j in start..<end {
                        let amplitude = abs(channelBuffer[j])
                        if amplitude > maxAmplitude {
                            maxAmplitude = amplitude
                        }
                    }
                }
            }
            downsampled.append(maxAmplitude)
            if maxAmplitude > globalMax {
                globalMax = maxAmplitude
            }
        }
        
        // Normalize
        if globalMax > 0 {
            for i in 0..<downsampled.count {
                downsampled[i] /= globalMax
            }
        }
        
        return WaveformData(samples: downsampled)
    }
}
