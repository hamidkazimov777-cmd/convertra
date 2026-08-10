import XCTest
@testable import Convertra
import AVFoundation

final class KeyDetectorTests: XCTestCase {
    var keyDetector: KeyDetector!
    var camelotMapper: CamelotMapper!

    override func setUp() {
        super.setUp()
        keyDetector = KeyDetector()
        camelotMapper = CamelotMapper()
    }

    override func tearDown() {
        keyDetector = nil
        camelotMapper = nil
        super.tearDown()
    }

    func testDetectKeyFMinor4A() async {
        // Generate F Minor chord: F4 (349.23 Hz) + Ab4 (415.30 Hz) + C5 (523.25 Hz)
        let pcm = generateChordPCM(frequencies: [349.23, 415.30, 523.25], durationSeconds: 6.0)
        let result = await keyDetector.detectKey(pcm: pcm)

        XCTAssertEqual(result.camelotKey.code, "4A", "F Minor chord should be detected as 4A Camelot key, got \(result.camelotKey.code)")
        XCTAssertEqual(result.musicalKey, .fMinor)
        XCTAssertGreaterThan(result.confidence, 0.40)
    }

    func testDetectKeyCMajor8B() async {
        // Generate C Major chord: C4 (261.63 Hz) + E4 (329.63 Hz) + G4 (392.00 Hz)
        let pcm = generateChordPCM(frequencies: [261.63, 329.63, 392.00], durationSeconds: 6.0)
        let result = await keyDetector.detectKey(pcm: pcm)

        XCTAssertEqual(result.camelotKey.code, "8B", "C Major chord should be detected as 8B Camelot key, got \(result.camelotKey.code)")
        XCTAssertEqual(result.musicalKey, .cMajor)
        XCTAssertGreaterThan(result.confidence, 0.40)
    }

    func testDetectKeyAMinor8A() async {
        // Generate A Minor chord: A4 (440.00 Hz) + C5 (523.25 Hz) + E5 (659.25 Hz)
        let pcm = generateChordPCM(frequencies: [440.00, 523.25, 659.25], durationSeconds: 6.0)
        let result = await keyDetector.detectKey(pcm: pcm)

        XCTAssertEqual(result.camelotKey.code, "8A", "A Minor chord should be detected as 8A Camelot key, got \(result.camelotKey.code)")
        XCTAssertEqual(result.musicalKey, .aMinor)
    }

    func testDetectKeyGMajor9B() async {
        // Generate G Major chord: G4 (392.00 Hz) + B4 (493.88 Hz) + D5 (587.33 Hz)
        let pcm = generateChordPCM(frequencies: [392.00, 493.88, 587.33], durationSeconds: 6.0)
        let result = await keyDetector.detectKey(pcm: pcm)

        XCTAssertEqual(result.camelotKey.code, "9B", "G Major chord should be detected as 9B Camelot key, got \(result.camelotKey.code)")
        XCTAssertEqual(result.musicalKey, .gMajor)
    }

    func testCamelotMapperCompatibility() async {
        let key4A = CamelotKey(code: "4A")!
        let key4B = CamelotKey(code: "4B")!
        let key5A = CamelotKey(code: "5A")!
        let key9A = CamelotKey(code: "9A")!

        let is4Aand4BCompat = await camelotMapper.isHarmonicallyCompatible(keyA: key4A, keyB: key4B)
        let is4Aand5ACompat = await camelotMapper.isHarmonicallyCompatible(keyA: key4A, keyB: key5A)
        let is4Aand9ACompat = await camelotMapper.isHarmonicallyCompatible(keyA: key4A, keyB: key9A)

        XCTAssertTrue(is4Aand4BCompat, "4A and 4B (relative major/minor) MUST be harmonically compatible")
        XCTAssertTrue(is4Aand5ACompat, "4A and 5A (+1 energy step) MUST be harmonically compatible")
        XCTAssertFalse(is4Aand9ACompat, "4A and 9A (5 steps away) MUST NOT be compatible")
    }

    // Helper: Generates multi-tone chord PCM Float array at 22,050 Hz
    private func generateChordPCM(frequencies: [Float], durationSeconds: Double, sampleRate: Double = 22050.0) -> [Float] {
        let totalFrames = Int(durationSeconds * sampleRate)
        var pcm = [Float](repeating: 0, count: totalFrames)

        for freq in frequencies {
            for i in 0..<totalFrames {
                let time = Float(i) / Float(sampleRate)
                pcm[i] += (1.0 / Float(frequencies.count)) * sin(2.0 * Float.pi * freq * time)
            }
        }
        return pcm
    }
}
