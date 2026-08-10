import Foundation

/// Importer interface for loading exported reference data from third-party DJ software (CSV format).
actor ReferenceDataImporter {
    struct ImportedReferenceEntry: Sendable {
        let filePath: String
        let title: String?
        let artist: String?
        let bpm: Double?
        let musicalKey: MusicalKey?
        let camelotKey: CamelotKey?
    }

    /// Parses a CSV export file containing track metadata and analysis results.
    func parseCSV(url: URL) throws -> [ImportedReferenceEntry] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else { return [] }
        
        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        // Locate column indices
        let pathIdx = headers.firstIndex(where: { $0.contains("path") || $0.contains("file") || $0.contains("location") })
        let bpmIdx = headers.firstIndex(where: { $0.contains("bpm") || $0.contains("tempo") })
        let keyIdx = headers.firstIndex(where: { $0.contains("key") || $0.contains("initialkey") || $0.contains("camelot") })
        let titleIdx = headers.firstIndex(where: { $0.contains("title") || $0.contains("name") })
        let artistIdx = headers.firstIndex(where: { $0.contains("artist") })

        var entries: [ImportedReferenceEntry] = []

        for lineIdx in 1..<lines.count {
            let cols = lines[lineIdx].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.count > 0 else { continue }

            let filePath = pathIdx != nil && pathIdx! < cols.count ? cols[pathIdx!] : "Track_\(lineIdx)"
            let rawBPM = bpmIdx != nil && bpmIdx! < cols.count ? cols[bpmIdx!] : nil
            let rawKey = keyIdx != nil && keyIdx! < cols.count ? cols[keyIdx!] : nil
            let title = titleIdx != nil && titleIdx! < cols.count ? cols[titleIdx!] : nil
            let artist = artistIdx != nil && artistIdx! < cols.count ? cols[artistIdx!] : nil

            let bpm = ReferenceNormalizer.normalizeBPM(rawBPM)
            let camelotKey = ReferenceNormalizer.normalizeCamelotKey(rawKey)
            let musicalKey = camelotKey?.musicalKey ?? ReferenceNormalizer.normalizeMusicalKey(rawKey)

            entries.append(
                ImportedReferenceEntry(
                    filePath: filePath,
                    title: title,
                    artist: artist,
                    bpm: bpm,
                    musicalKey: musicalKey,
                    camelotKey: camelotKey
                )
            )
        }

        return entries
    }
}
