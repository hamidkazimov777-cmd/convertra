import AVFoundation
import Foundation

class TestAudioGenerator {
    static func createSineWaveFile(
        frequency: Float = 440.0,
        duration: TimeInterval = 2.0,
        sampleRate: Double = 44100.0,
        channels: UInt32 = 1,
        fileExtension: String = "wav"
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: channels, interleaved: false)!
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        for c in 0..<Int(channels) {
            let channelData = buffer.floatChannelData![c]
            let freqOffset = Float(c * 100)
            for i in 0..<Int(frameCount) {
                let time = Float(i) / Float(sampleRate)
                channelData[i] = sin(2.0 * Float.pi * (frequency + freqOffset) * time)
            }
        }
        
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        try file.write(from: buffer)
        
        return tempURL
    }

    /// Generates a synthetic rhythm PCM Float array at an exact target BPM for TempoDetector testing.
    static func generateRhythmPCM(
        bpm: Double,
        durationSeconds: Double = 10.0,
        sampleRate: Double = 22050.0,
        addHiHats: Bool = true,
        addSnare: Bool = true
    ) -> [Float] {
        let totalFrames = Int(durationSeconds * sampleRate)
        var pcm = [Float](repeating: 0, count: totalFrames)

        let beatIntervalFrames = Int(round((60.0 / bpm) * sampleRate))
        guard beatIntervalFrames > 0 else { return pcm }

        var frameIdx = 0
        var beatCount = 0

        while frameIdx < totalFrames {
            // Kick Drum on beat (low frequency decaying pulse)
            let kickLength = min(Int(0.08 * sampleRate), totalFrames - frameIdx)
            for k in 0..<kickLength {
                let t = Float(k) / Float(sampleRate)
                let env = exp(-30.0 * t)
                let kickWave = sin(2.0 * Float.pi * (100.0 - 50.0 * t) * t)
                pcm[frameIdx + k] += 0.8 * env * kickWave
            }

            // Snare Drum on beat 3 (every 2 beats for 4/4)
            if addSnare && (beatCount % 2 == 1) {
                let snareLength = min(Int(0.06 * sampleRate), totalFrames - frameIdx)
                for s in 0..<snareLength {
                    let t = Float(s) / Float(sampleRate)
                    let noise = Float.random(in: -0.5...0.5)
                    pcm[frameIdx + s] += 0.4 * exp(-40.0 * t) * noise
                }
            }

            // Hi-Hats on 8th notes (half-beat offset)
            if addHiHats {
                let halfBeatOffset = beatIntervalFrames / 2
                let hatFrame = frameIdx + halfBeatOffset
                if hatFrame < totalFrames {
                    let hatLength = min(Int(0.02 * sampleRate), totalFrames - hatFrame)
                    for h in 0..<hatLength {
                        let t = Float(h) / Float(sampleRate)
                        let hatNoise = Float.random(in: -0.4...0.4)
                        pcm[hatFrame + h] += 0.3 * exp(-100.0 * t) * hatNoise
                    }
                }
            }

            frameIdx += beatIntervalFrames
            beatCount += 1
        }

        return pcm
    }
}
