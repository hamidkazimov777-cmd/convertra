import Foundation

/// Represents a key in the Camelot Wheel system (1A–12A for Minor, 1B–12B for Major).
/// Used extensively in professional DJ software for harmonic mixing.
struct CamelotKey: Codable, Hashable, Sendable, CustomStringConvertible, Identifiable {
    enum Mode: String, Codable, Hashable, Sendable, CaseIterable {
        case a = "A" // Minor
        case b = "B" // Major

        var name: String {
            switch self {
            case .a: return "Minor"
            case .b: return "Major"
            }
        }
    }

    let number: Int // 1...12
    let mode: Mode

    var id: String { code }

    var code: String {
        "\(number)\(mode.rawValue)"
    }

    var isMinor: Bool { mode == .a }
    var isMajor: Bool { mode == .b }

    var description: String { code }

    init?(number: Int, mode: Mode) {
        guard (1...12).contains(number) else { return nil }
        self.number = number
        self.mode = mode
    }

    init?(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count >= 2 else { return nil }

        let lastChar = trimmed.suffix(1)
        guard let mode = Mode(rawValue: String(lastChar)) else { return nil }

        let numberString = trimmed.dropLast()
        guard let number = Int(numberString), (1...12).contains(number) else { return nil }

        self.number = number
        self.mode = mode
    }

    init(musicalKey: MusicalKey) {
        switch musicalKey {
        // Minor Keys (A)
        case .gSharpMinor, .aFlatMinor: self = CamelotKey(number: 1, mode: .a)!
        case .dSharpMinor, .eFlatMinor: self = CamelotKey(number: 2, mode: .a)!
        case .aSharpMinor, .bFlatMinor: self = CamelotKey(number: 3, mode: .a)!
        case .fMinor: self = CamelotKey(number: 4, mode: .a)!
        case .cMinor: self = CamelotKey(number: 5, mode: .a)!
        case .gMinor: self = CamelotKey(number: 6, mode: .a)!
        case .dMinor: self = CamelotKey(number: 7, mode: .a)!
        case .aMinor: self = CamelotKey(number: 8, mode: .a)!
        case .eMinor: self = CamelotKey(number: 9, mode: .a)!
        case .bMinor: self = CamelotKey(number: 10, mode: .a)!
        case .fSharpMinor: self = CamelotKey(number: 11, mode: .a)!
        case .cSharpMinor: self = CamelotKey(number: 12, mode: .a)!

        // Major Keys (B)
        case .bMajor: self = CamelotKey(number: 1, mode: .b)!
        case .fSharpMajor, .gFlatMajor: self = CamelotKey(number: 2, mode: .b)!
        case .cSharpMajor, .dFlatMajor: self = CamelotKey(number: 3, mode: .b)!
        case .gSharpMajor, .aFlatMajor: self = CamelotKey(number: 4, mode: .b)!
        case .dSharpMajor, .eFlatMajor: self = CamelotKey(number: 5, mode: .b)!
        case .aSharpMajor, .bFlatMajor: self = CamelotKey(number: 6, mode: .b)!
        case .fMajor: self = CamelotKey(number: 7, mode: .b)!
        case .cMajor: self = CamelotKey(number: 8, mode: .b)!
        case .gMajor: self = CamelotKey(number: 9, mode: .b)!
        case .dMajor: self = CamelotKey(number: 10, mode: .b)!
        case .aMajor: self = CamelotKey(number: 11, mode: .b)!
        case .eMajor: self = CamelotKey(number: 12, mode: .b)!
        }
    }

    var musicalKey: MusicalKey {
        switch (number, mode) {
        case (1, .a): return .gSharpMinor
        case (2, .a): return .dSharpMinor
        case (3, .a): return .aSharpMinor
        case (4, .a): return .fMinor
        case (5, .a): return .cMinor
        case (6, .a): return .gMinor
        case (7, .a): return .dMinor
        case (8, .a): return .aMinor
        case (9, .a): return .eMinor
        case (10, .a): return .bMinor
        case (11, .a): return .fSharpMinor
        case (12, .a): return .cSharpMinor

        case (1, .b): return .bMajor
        case (2, .b): return .fSharpMajor
        case (3, .b): return .cSharpMajor
        case (4, .b): return .gSharpMajor
        case (5, .b): return .dSharpMajor
        case (6, .b): return .aSharpMajor
        case (7, .b): return .fMajor
        case (8, .b): return .cMajor
        case (9, .b): return .gMajor
        case (10, .b): return .dMajor
        case (11, .b): return .aMajor
        case (12, .b): return .eMajor

        default: return .cMajor
        }
    }

    /// Formatted string showing both Camelot code and Musical Key name (e.g. "4A (F Minor)").
    var formattedKey: String {
        "\(code) (\(musicalKey.rawValue))"
    }

    /// Computes list of harmonically compatible Camelot keys for seamless DJ mixing.
    var harmonicMatches: [CamelotKey] {
        var matches: [CamelotKey] = []

        // 1. Same Key (Exact Match)
        matches.append(self)

        // 2. Relative Major / Minor (Same Number, Opposite Mode: e.g. 4A <-> 4B)
        let oppositeMode: Mode = (mode == .a) ? .b : .a
        if let relative = CamelotKey(number: number, mode: oppositeMode) {
            matches.append(relative)
        }

        // 3. Energy Boost (+1 step: e.g. 4A -> 5A)
        let nextNumber = (number % 12) + 1
        if let nextKey = CamelotKey(number: nextNumber, mode: mode) {
            matches.append(nextKey)
        }

        // 4. Energy Drop (-1 step: e.g. 4A -> 3A)
        let prevNumber = (number == 1) ? 12 : number - 1
        if let prevKey = CamelotKey(number: prevNumber, mode: mode) {
            matches.append(prevKey)
        }

        // 5. Diagonal Modulation (Diagonal transition: +1 step opposite mode / -1 step opposite mode)
        if let diagNext = CamelotKey(number: nextNumber, mode: oppositeMode) {
            matches.append(diagNext)
        }
        if let diagPrev = CamelotKey(number: prevNumber, mode: oppositeMode) {
            matches.append(diagPrev)
        }

        return matches
    }

    /// Returns shortest distance (steps) on the 12-position Camelot wheel.
    func distance(to other: CamelotKey) -> Int {
        let diff = abs(number - other.number)
        let stepDistance = min(diff, 12 - diff)
        return mode == other.mode ? stepDistance : stepDistance + 1
    }

    /// Returns true if two keys are harmonically compatible for DJ mixing.
    func isHarmonicallyCompatible(with other: CamelotKey) -> Bool {
        harmonicMatches.contains(other)
    }

    /// All 24 Camelot keys in order
    static var allCases: [CamelotKey] {
        var list: [CamelotKey] = []
        for num in 1...12 {
            if let a = CamelotKey(number: num, mode: .a) { list.append(a) }
            if let b = CamelotKey(number: num, mode: .b) { list.append(b) }
        }
        return list
    }
}
