import XCTest
@testable import Convertra
import AVFoundation

final class SignalPreprocessorTests: XCTestCase {
    var preprocessor: SignalPreprocessor!

    override func setUp() {
        super.setUp()
        preprocessor = SignalPreprocessor()
    }

    override func tearDown() {
        preprocessor = nil
        super.tearDown()
    }

    func testHPSSTonalSineWaveIsolatesHarmonic() async throws {
        // Generate a 5-second 440 Hz pure sine wave at 22,050 Hz
        let sampleRate: Double = 22050.0
        let frameCount = Int(5.0 * sampleRate)
        var pcm = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Float(i) / Float(sampleRate)
            pcm[i] = sin(2.0 * Float.pi * 440.0 * t)
        }

        let segment = AudioSegment(
            type: .full,
            pcmData: pcm,
            sampleRate: sampleRate,
            startFrame: 0,
            durationSeconds: 5.0
        )

        let result = await preprocessor.process(segment: segment)

        XCTAssertEqual(result.harmonicPCM.count, pcm.count)
        XCTAssertEqual(result.percussivePCM.count, pcm.count)
        XCTAssertEqual(result.sampleRate, 22050.0)

        // For a pure sine wave, Harmonic energy ratio MUST dominate Percussive energy ratio
        XCTAssertGreaterThan(result.harmonicEnergyRatio, 0.70, "Pure sine tone should be classified as primarily Harmonic")
        XCTAssertLessThan(result.percussiveEnergyRatio, 0.30)
    }

    func testHPSSPercussiveBurstsIsolatesPercussive() async throws {
        // Generate 5 seconds of percussive impulses (short clicks every 0.5s)
        let sampleRate: Double = 22050.0
        let frameCount = Int(5.0 * sampleRate)
        var pcm = [Float](repeating: 0, count: frameCount)

        let interval = Int(0.5 * sampleRate)
        for i in stride(from: 0, to: frameCount, by: interval) {
            // Short 5-sample impulse
            for j in 0..<5 {
                if i + j < frameCount {
                    pcm[i + j] = (j % 2 == 0) ? 1.0 : -1.0
                }
            }
        }

        let segment = AudioSegment(
            type: .full,
            pcmData: pcm,
            sampleRate: sampleRate,
            startFrame: 0,
            durationSeconds: 5.0
        )

        let result = await preprocessor.process(segment: segment)

        // Percussive impulses should yield higher percussive energy ratio
        XCTAssertGreaterThan(result.percussiveEnergyRatio, result.harmonicEnergyRatio, "Percussive clicks should have higher Percussive energy ratio")
    }

    func testHPSSShortSegmentFallback() async {
        // Pass a very short PCM signal (< 2048 samples)
        let shortPCM = [Float](repeating: 0.5, count: 500)
        let segment = AudioSegment(
            type: .full,
            pcmData: shortPCM,
            sampleRate: 22050.0,
            startFrame: 0,
            durationSeconds: 0.02
        )

        let result = await preprocessor.process(segment: segment)

        XCTAssertEqual(result.harmonicPCM.count, 500)
        XCTAssertEqual(result.percussivePCM.count, 500)
        XCTAssertEqual(result.harmonicEnergyRatio, 0.5)
    }
}
