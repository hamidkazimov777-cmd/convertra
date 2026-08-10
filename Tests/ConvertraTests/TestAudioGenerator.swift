import AVFoundation
import Foundation

class TestAudioGenerator {
    static func createSineWaveFile(frequency: Float, duration: TimeInterval, sampleRate: Double = 44100.0) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let channelData = buffer.floatChannelData![0]
        
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            // Sine wave formula: sin(2 * pi * f * t)
            channelData[i] = sin(2.0 * Float.pi * frequency * time)
        }
        
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        try file.write(from: buffer)
        
        return tempURL
    }
}
