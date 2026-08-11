import XCTest
@testable import Convertra
import AVFoundation

final class AudioAnalyzerEngineTests: XCTestCase {
    var analyzer: AudioAnalyzerEngine!

    override func setUp() {
        super.setUp()
        analyzer = AudioAnalyzerEngine()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    func testDetectKeyC4() async throws {
        // Generate a 440 Hz sine wave (A4)
        // A4 should correlate strongly with A Major / A Minor
        let url = try TestAudioGenerator.createSineWaveFile(frequency: 440.0, duration: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await analyzer.analyze(url: url)
        
        // Since it's a pure A4 sine wave, the dominant pitch class is A.
        XCTAssertNotNil(result.key)
        XCTAssertTrue(result.key!.contains("A "), "Expected key to contain A, got \(result.key ?? "nil")")
    }
    
    func testDetectBPMDoesNotCrash() async throws {
        // Generate a simple sine wave which has no clear transients
        // We just want to ensure the vDSP code doesn't crash or hang
        let url = try TestAudioGenerator.createSineWaveFile(frequency: 440.0, duration: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await analyzer.analyze(url: url)
        
        // The fallback legacy analyzer uses a Bayesian prior which defaults to 120 BPM when fed featureless noise/silence.
        // We simply assert that it returns a valid result and does not crash or hang.
        XCTAssertNotNil(result.bpm)
    }
}
