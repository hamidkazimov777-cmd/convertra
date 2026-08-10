import XCTest
@testable import Convertra
import AVFoundation

final class RealAudioBenchmarkTests: XCTestCase {
    var normalizer: ReferenceNormalizer!
    var importer: ReferenceDataImporter!
    var runner: RealAudioBenchmarkRunner!

    override func setUp() {
        super.setUp()
        normalizer = ReferenceNormalizer()
        importer = ReferenceDataImporter()
        runner = RealAudioBenchmarkRunner()
    }

    override func tearDown() {
        normalizer = nil
        importer = nil
        runner = nil
        super.tearDown()
    }

    // MARK: - 1. Reference Normalizer Tests

    func testBPMNormalization() {
        XCTAssertEqual(ReferenceNormalizer.normalizeBPM(124.0), 124.0)
        XCTAssertEqual(ReferenceNormalizer.normalizeBPM(128), 128.0)
        XCTAssertEqual(ReferenceNormalizer.normalizeBPM("174.50"), 174.50)
        XCTAssertEqual(ReferenceNormalizer.normalizeBPM("124,8"), 124.8)
        XCTAssertNil(ReferenceNormalizer.normalizeBPM("invalid"))
    }

    func testCamelotKeyNormalization() {
        XCTAssertEqual(ReferenceNormalizer.normalizeCamelotKey("4A")?.code, "4A")
        XCTAssertEqual(ReferenceNormalizer.normalizeCamelotKey("08B")?.code, "8B")
        XCTAssertEqual(ReferenceNormalizer.normalizeCamelotKey("8b")?.code, "8B")
        XCTAssertEqual(ReferenceNormalizer.normalizeCamelotKey("F Minor")?.code, "4A")
        XCTAssertEqual(ReferenceNormalizer.normalizeCamelotKey("C Major")?.code, "8B")
        XCTAssertEqual(ReferenceNormalizer.normalizeCamelotKey("Fm")?.code, "4A")
        XCTAssertNil(ReferenceNormalizer.normalizeCamelotKey("99Z"))
    }

    // MARK: - 2. Reference CSV Importer Tests

    func testCSVImporterParsing() async throws {
        let csvContent = """
        File Location, BPM, Key, Title, Artist
        /Music/Track1.mp3, 124.0, 4A, Deep House 1, Artist A
        /Music/Track2.flac, 174.5, F Minor, DnB Track, Artist B
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("csv")
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let entries = try await importer.parseCSV(url: tempURL)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].filePath, "/Music/Track1.mp3")
        XCTAssertEqual(entries[0].bpm, 124.0)
        XCTAssertEqual(entries[0].camelotKey?.code, "4A")

        XCTAssertEqual(entries[1].filePath, "/Music/Track2.flac")
        XCTAssertEqual(entries[1].bpm, 174.5)
        XCTAssertEqual(entries[1].camelotKey?.code, "4A")
    }

    // MARK: - 3. Real Audio Benchmark Execution (114 Physical Files)

    func testExecuteRealAudioBenchmark114PhysicalFiles() async throws {
        let datasetPath = "/Users/hamidkazimov/.gemini/antigravity/brain/adfe5a27-f4d9-4454-bff4-39b0bafc7339/benchmark_dataset.json"
        guard FileManager.default.fileExists(atPath: datasetPath) else {
            print("Skipping real physical benchmark execution: benchmark_dataset.json not found.")
            return
        }

        let datasetURL = URL(fileURLWithPath: datasetPath)
        let report = try await runner.runBenchmark(datasetURL: datasetURL)

        print("\n=======================================================")
        print("REAL AUDIO BENCHMARK (114 PHYSICAL AUDIO FILES)")
        print("=======================================================")
        print("Tracks discovered: \(report.totalTracksInDataset)")
        print("Tracks analyzed:   \(report.processedTracksCount)")
        print("Tracks skipped:    \(report.skippedMissingFilesCount)")
        print("Data Category:     \(report.category.rawValue)")
        print("-------------------------------------------------------")
        print("Reference Sources:")
        print("  - Mixed In Key:  \(report.processedTracksCount) records (VERIFIED REFERENCE DATA)")
        print("  - rekordbox:    unavailable (NOT AVAILABLE)")
        print("  - Lexicon:      unavailable (NOT AVAILABLE)")
        print("-------------------------------------------------------")
        print("BPM Metrics (Convertra vs Mixed In Key reference):")
        print("  - Exact ±0.1 BPM:         \(String(format: "%.1f", report.bpmExactAccuracyPct))%")
        print("  - Tolerant ±0.5 BPM:      \(String(format: "%.1f", report.bpmTolerantAccuracyPct))%")
        print("  - MAE (Mean Absolute Error): \(String(format: "%.2f", report.bpmMeanAbsoluteError)) BPM")
        print("  - Octave Error Rate (0.5x/2x): \(String(format: "%.1f", report.bpmOctaveErrorRatePct))%")
        print("-------------------------------------------------------")
        print("KEY Metrics (Convertra vs Mixed In Key reference):")
        print("  - Exact Camelot Match:       \(String(format: "%.1f", report.keyExactMatchPct))%")
        print("  - Harmonic Compatible Match: \(String(format: "%.1f", report.keyHarmonicMatchPct))%")
        print("  - Relative Major/Minor Error:\(String(format: "%.1f", report.keyRelativeErrorPct))%")
        print("  - Fifth Error (+/- 1 step):  \(String(format: "%.1f", report.keyFifthErrorPct))%")
        print("  - Critical Bad Key Error:    \(String(format: "%.1f", report.keyCriticalErrorPct))%")
        print("-------------------------------------------------------")
        print("Confidence Statistics:")
        print("  - Average BPM Confidence: \(String(format: "%.2f", report.averageBPMConfidence))")
        print("  - Average Key Confidence: \(String(format: "%.2f", report.averageKeyConfidence))")
        print("-------------------------------------------------------")
        print("Performance Metrics:")
        print("  - Realtime Factor: \(String(format: "%.1f", report.averageRealtimeFactor))x")
        print("=======================================================")

        print("\n--- COMPLETE DISCREPANCY LOG (\(report.discrepancies.count) Entries) ---")
        for (idx, d) in report.discrepancies.enumerated() {
            print("[\(idx + 1)] Track: \(d.trackID) | File: \(d.fileName)")
            print("    Ref BPM: \(d.referenceBPM ?? 0) | Convertra BPM: \(String(format: "%.2f", d.convertraBPM ?? 0)) | Error: \(String(format: "%.2f", d.bpmError ?? 0))")
            print("    Ref Key: \(d.referenceCamelot ?? "-") | Convertra Key: \(d.convertraCamelot ?? "-") | Category: \(d.errorCategory.rawValue)")
            print("    Key Confidence: \(String(format: "%.2f", d.confidence)) | Octave BPM Error: \(d.isBPMOctaveError)")
        }
        print("=======================================================\n")

        XCTAssertGreaterThan(report.processedTracksCount, 0)
    }
}
