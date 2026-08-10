import Foundation

/// Independent Camelot Mapper for AudioAnalysisEngine 2.0.
/// Maps MusicalKey and KeyResult into Camelot notation and evaluates harmonic compatibility.
actor CamelotMapper {
    func map(musicalKey: MusicalKey) -> CamelotKey {
        musicalKey.camelotKey
    }

    func isHarmonicallyCompatible(keyA: CamelotKey, keyB: CamelotKey) -> Bool {
        keyA.isHarmonicallyCompatible(with: keyB)
    }

    func getCompatibleTransitions(for key: CamelotKey) -> [CamelotKey] {
        key.harmonicMatches
    }
}
