import XCTest
@testable import Convertra
import AVFoundation

final class AudioAnalysisEngine2Tests: XCTestCase {
    var engine: AudioAnalysisEngine2!

    override func setUp() {
        super.setUp()
        engine = AudioAnalysisEngine2()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    func testEngine2FacadeExecution() async throws {
        let tempURL = try TestAudioGenerator.createSineWaveFile(
            frequency: 440.0,
            duration: 6.0,
            sampleRate: 44100.0,
            channels: 2,
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = try await engine.analyze(url: tempURL)

        XCTAssertEqual(result.url, tempURL)
        XCTAssertGreaterThan(result.durationSeconds, 5.0)
        XCTAssertGreaterThan(result.bpm, 0.0)
        XCTAssertGreaterThanOrEqual(result.bpmConfidence, 0.0)
        XCTAssertGreaterThanOrEqual(result.keyConfidence, 0.0)
        XCTAssertGreaterThanOrEqual(result.overallConfidence, 0.0)
        XCTAssertNotNil(result.camelotKey)
        XCTAssertNotNil(result.musicalKey)
        XCTAssertFalse(result.beatGrid.beatTimes.isEmpty)
    }

    func testEngine2FacadeMissingFileThrowsError() async {
        let invalidURL = URL(fileURLWithPath: "/tmp/non_existent_file_\(UUID().uuidString).mp3")
        
        do {
            _ = try await engine.analyze(url: invalidURL)
            XCTFail("Expected AudioAnalysisEngine2 to throw error for missing file")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
