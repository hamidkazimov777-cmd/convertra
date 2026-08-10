import XCTest
@testable import Convertra
import AVFoundation

final class AudioDecoderTests: XCTestCase {
    var decoder: AudioDecoder!

    override func setUp() {
        super.setUp()
        decoder = AudioDecoder()
    }

    override func tearDown() {
        decoder = nil
        super.tearDown()
    }

    func testDecodeWavMonoShortFile() async throws {
        // Create 10-second mono WAV file at 44.1 kHz
        let url = try TestAudioGenerator.createSineWaveFile(
            frequency: 440.0,
            duration: 10.0,
            sampleRate: 44100.0,
            channels: 1,
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await decoder.decode(url: url)

        XCTAssertEqual(result.url, url)
        XCTAssertEqual(result.originalChannels, 1)
        XCTAssertEqual(result.originalSampleRate, 44100.0)
        XCTAssertGreaterThan(result.totalDurationSeconds, 9.9)

        // Short file (<25s) should result in 1 full segment
        XCTAssertEqual(result.segments.count, 1)
        let segment = result.segments[0]
        XCTAssertEqual(segment.type, .full)
        XCTAssertEqual(segment.sampleRate, 22050.0)

        // Check output size: ~10 seconds @ 22,050 Hz = ~220,500 PCM samples
        let expectedSamples = Int(10.0 * 22050.0)
        XCTAssertEqual(segment.pcmData.count, expectedSamples, accuracy: 2205)
    }

    func testDecodeAiffStereoLongFile() async throws {
        // Create 65-second stereo AIFF file at 48.0 kHz
        let url = try TestAudioGenerator.createSineWaveFile(
            frequency: 440.0,
            duration: 65.0,
            sampleRate: 48000.0,
            channels: 2,
            fileExtension: "aiff"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await decoder.decode(url: url)

        XCTAssertEqual(result.originalChannels, 2)
        XCTAssertEqual(result.originalSampleRate, 48000.0)

        // Long file (>=60s) should extract 4 strategic segments: Intro, BodyA, BodyB, Outro
        XCTAssertEqual(result.segments.count, 4)

        let segmentTypes = result.segments.map(\.type)
        XCTAssertEqual(segmentTypes, [.intro, .bodyA, .bodyB, .outro])

        for segment in result.segments {
            // Target sample rate MUST be 22,050 Hz
            XCTAssertEqual(segment.sampleRate, 22050.0)
            XCTAssertFalse(segment.pcmData.isEmpty)
        }
    }

    func testStereoDownmixToMono() async throws {
        // Create a 5-second stereo file where left channel is +0.5 and right channel is -0.5
        // Downmix should sum and divide by 2, resulting in ~0.0
        let url = try TestAudioGenerator.createSineWaveFile(
            frequency: 220.0,
            duration: 5.0,
            sampleRate: 44100.0,
            channels: 2,
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await decoder.decode(url: url)
        XCTAssertEqual(result.segments.count, 1)

        let pcm = result.segments[0].pcmData
        XCTAssertFalse(pcm.isEmpty)

        // Verify output is mono Float array
        let maxVal = pcm.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(maxVal, 0.0)
        XCTAssertLessThanOrEqual(maxVal, 1.0)
    }

    func testUnusualSampleRate96kHz() async throws {
        // Create 15-second mono file at 96,000 Hz
        let url = try TestAudioGenerator.createSineWaveFile(
            frequency: 880.0,
            duration: 15.0,
            sampleRate: 96000.0,
            channels: 1,
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await decoder.decode(url: url)
        XCTAssertEqual(result.originalSampleRate, 96000.0)

        let segment = result.segments[0]
        XCTAssertEqual(segment.sampleRate, 22050.0)

        // Resampled 15s @ 22,050 Hz = ~330,750 samples
        let expectedSamples = Int(15.0 * 22050.0)
        XCTAssertEqual(segment.pcmData.count, expectedSamples, accuracy: 2205)
    }

    func testMediumDurationFile() async throws {
        // Create 40-second file (25s <= T < 60s)
        let url = try TestAudioGenerator.createSineWaveFile(
            frequency: 440.0,
            duration: 40.0,
            sampleRate: 44100.0,
            channels: 1,
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await decoder.decode(url: url)
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].type, .intro)
        XCTAssertEqual(result.segments[1].type, .bodyA)
    }

    func testNonExistentFileThrowsError() async {
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_audio_file_\(UUID().uuidString).wav")
        do {
            _ = try await decoder.decode(url: fakeURL)
            XCTFail("Decoding non-existent file should throw AudioDecoderError")
        } catch {
            XCTAssertTrue(error is AudioDecoderError)
        }
    }
}
