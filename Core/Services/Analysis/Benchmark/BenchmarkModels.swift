import Foundation

/// Reference label from third-party DJ software (Mixed In Key, rekordbox, Lexicon).
struct SoftwareReferenceResult: Codable, Hashable, Sendable {
    let bpm: Double?
    let musicalKey: String?
    let camelotKey: String?
}

/// Specification of a single track entry in `benchmark_dataset.json`.
struct RealBenchmarkTrackSpec: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let filePath: String
    let fileName: String
    let title: String?
    let artist: String?
    let genre: String?
    let audioFormat: String? // mp3, flac, wav, aiff
    let durationSeconds: Double?
    let sampleRate: Double?
    
    // Ground Truth values
    let groundTruthBPM: Double?
    let groundTruthMusicalKey: String?
    let groundTruthCamelotKey: String?
    let firstBeatTimeSeconds: Double?
    
    // Reference results from external software
    let mixedInKey: SoftwareReferenceResult?
    let rekordbox: SoftwareReferenceResult?
    let lexicon: SoftwareReferenceResult?
}

/// Complete benchmark dataset schema matching `benchmark_dataset_spec.md`.
struct RealBenchmarkDataset: Codable, Hashable, Sendable {
    let version: String
    let description: String
    let tracks: [RealBenchmarkTrackSpec]
}

/// Classification of errors in key detection.
enum KeyErrorCategory: String, Codable, Hashable, Sendable {
    case exactMatch = "Exact Match"
    case harmonicallyCompatible = "Harmonically Compatible"
    case fifthError = "Fifth Error (+/- 1 Step)"
    case relativeError = "Relative Major/Minor Error"
    case parallelError = "Parallel Key Error"
    case badKeyError = "Critical Bad Key Error (>= 2 Steps)"
}

/// Individual discrepancy entry for detailed benchmark logging.
struct DiscrepancyEntry: Codable, Hashable, Sendable, Identifiable {
    var id: String { trackID }
    let trackID: String
    let fileName: String
    let genre: String
    let referenceBPM: Double?
    let convertraBPM: Double?
    let bpmError: Double?
    let referenceCamelot: String?
    let convertraCamelot: String?
    let confidence: Double
    let errorCategory: KeyErrorCategory
    let isBPMOctaveError: Bool
}

/// Category classification for data authenticity.
enum DataCategory: String, Codable, Hashable, Sendable {
    case realData = "REAL DATA"
    case syntheticData = "SYNTHETIC DATA"
    case mockedData = "MOCKED / PRECOMPUTED DATA"
    case unverifiedData = "UNVERIFIED DATA"
}

/// Performance timing breakdown per real audio file.
struct FilePerformanceMetrics: Sendable {
    let decodeTimeSeconds: Double
    let hpssTimeSeconds: Double
    let tempoTimeSeconds: Double
    let keyTimeSeconds: Double
    let totalTimeSeconds: Double
    let audioDurationSeconds: Double
    var realtimeFactor: Double {
        totalTimeSeconds > 0 ? (audioDurationSeconds / totalTimeSeconds) : 0.0
    }
}

/// Comprehensive statistics report output.
struct RealBenchmarkReport: Sendable {
    let datasetVersion: String
    let category: DataCategory
    let totalTracksInDataset: Int
    let processedTracksCount: Int
    let skippedMissingFilesCount: Int
    let skippedMissingReferenceCount: Int
    
    // BPM Accuracy
    let bpmExactAccuracyPct: Double // +/- 0.1 BPM
    let bpmTolerantAccuracyPct: Double // +/- 0.5 BPM
    let bpmOctaveErrorRatePct: Double
    let bpmMeanAbsoluteError: Double
    
    // Key Accuracy
    let keyExactMatchPct: Double
    let keyHarmonicMatchPct: Double
    let keyRelativeErrorPct: Double
    let keyFifthErrorPct: Double
    let keyCriticalErrorPct: Double
    
    // Confidence & Performance
    let averageBPMConfidence: Double
    let averageKeyConfidence: Double
    let averageRealtimeFactor: Double
    
    let discrepancies: [DiscrepancyEntry]
    let summaryNote: String
}
