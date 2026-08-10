import XCTest
@testable import Convertra
import AVFoundation

final class WaveformAnalyzerTests: XCTestCase {
    var analyzer: WaveformAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = WaveformAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    func testGenerateWaveform() async throws {
        // Generate a 1-second 440 Hz sine wave
        let url = try TestAudioGenerator.createSineWaveFile(frequency: 440.0, duration: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let waveformData = try await analyzer.generateWaveform(for: url, targetSampleCount: 50)
        let waveform = waveformData.samples
        
        XCTAssertEqual(waveform.count, 50)
        
        // Ensure values are normalized between 0.0 and 1.0
        for sample in waveform {
            XCTAssertGreaterThanOrEqual(sample, 0.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }
}
