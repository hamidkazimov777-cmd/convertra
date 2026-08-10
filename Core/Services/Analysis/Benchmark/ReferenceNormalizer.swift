import Foundation

/// Normalizer for parsing raw BPM, Musical Key, and Camelot Key values exported from third-party DJ software
/// (Mixed In Key, rekordbox, Lexicon).
struct ReferenceNormalizer: Sendable {
    /// Normalizes raw BPM string or Double value.
    static func normalizeBPM(_ rawValue: Any?) -> Double? {
        if let doubleVal = rawValue as? Double, doubleVal > 0 {
            return doubleVal
        }
        if let intVal = rawValue as? Int, intVal > 0 {
            return Double(intVal)
        }
        if let strVal = rawValue as? String {
            let cleaned = strVal.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
            if let parsed = Double(cleaned), parsed > 0 {
                return parsed
            }
        }
        return nil
    }

    /// Normalizes raw Camelot key string (e.g. "4A", "8B", "4a", "04A").
    static func normalizeCamelotKey(_ rawValue: String?) -> CamelotKey? {
        guard let rawValue = rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }

        // If direct Camelot code (e.g. "4A", "08B")
        if let key = CamelotKey(code: trimmed) {
            return key
        }

        // If formatted as "04A" or "08B"
        if trimmed.hasPrefix("0") && trimmed.count >= 3 {
            let stripped = String(trimmed.dropFirst())
            if let key = CamelotKey(code: stripped) {
                return key
            }
        }

        // If Musical Key string (e.g. "F Minor", "Fm", "C Major")
        if let musicalKey = normalizeMusicalKey(trimmed) {
            return musicalKey.camelotKey
        }

        return nil
    }

    /// Normalizes raw Musical Key string from ID3 or DJ software exports.
    static func normalizeMusicalKey(_ rawValue: String?) -> MusicalKey? {
        guard let rawValue = rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Match against MusicalKey raw values
        for key in MusicalKey.allCases {
            if key.rawValue.localizedCaseInsensitiveCompare(trimmed) == .orderedSame {
                return key
            }
        }

        // Common shorthand mappings
        let shorthands: [String: MusicalKey] = [
            "FM": .fMinor, "F MINOR": .fMinor, "F MIN": .fMinor, "F-MIN": .fMinor,
            "CM": .cMinor, "C MINOR": .cMinor, "C MIN": .cMinor, "C-MIN": .cMinor,
            "C": .cMajor, "C MAJOR": .cMajor, "C MAJ": .cMajor, "C-MAJ": .cMajor,
            "AM": .aMinor, "A MINOR": .aMinor, "A MIN": .aMinor, "A-MIN": .aMinor,
            "GM": .gMinor, "G MINOR": .gMinor, "G MIN": .gMinor, "G-MIN": .gMinor,
            "DM": .dMinor, "D MINOR": .dMinor, "D MIN": .dMinor, "D-MIN": .dMinor,
            "EM": .eMinor, "E MINOR": .eMinor, "E MIN": .eMinor, "E-MIN": .eMinor,
            "BM": .bMinor, "B MINOR": .bMinor, "B MIN": .bMinor, "B-MIN": .bMinor,
            "F#M": .fSharpMinor, "F# MINOR": .fSharpMinor, "F#MIN": .fSharpMinor,
            "C#M": .cSharpMinor, "C# MINOR": .cSharpMinor, "C#MIN": .cSharpMinor,
            "G#M": .gSharpMinor, "G# MINOR": .gSharpMinor, "G#MIN": .gSharpMinor,
            "D#M": .dSharpMinor, "D# MINOR": .dSharpMinor, "D#MIN": .dSharpMinor,
            "A#M": .aSharpMinor, "A# MINOR": .aSharpMinor, "A#MIN": .aSharpMinor,
            "F": .fMajor, "F MAJOR": .fMajor, "F MAJ": .fMajor,
            "G": .gMajor, "G MAJOR": .gMajor, "G MAJ": .gMajor,
            "D": .dMajor, "D MAJOR": .dMajor, "D MAJ": .dMajor,
            "A": .aMajor, "A MAJOR": .aMajor, "A MAJ": .aMajor,
            "E": .eMajor, "E MAJOR": .eMajor, "E MAJ": .eMajor,
            "B": .bMajor, "B MAJOR": .bMajor, "B MAJ": .bMajor,
            "F#": .fSharpMajor, "F# MAJOR": .fSharpMajor,
            "C#": .cSharpMajor, "C# MAJOR": .cSharpMajor,
            "G#": .gSharpMajor, "G# MAJOR": .gSharpMajor,
            "D#": .dSharpMajor, "D# MAJOR": .dSharpMajor,
            "A#": .aSharpMajor, "A# MAJOR": .aSharpMajor
        ]

        let upper = trimmed.uppercased()
        return shorthands[upper]
    }
}
