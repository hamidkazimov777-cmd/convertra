import Foundation

struct DuplicateGroup: Identifiable, Equatable, Hashable, Sendable {
    let id = UUID()
    var tracks: [AudioFile]
}

struct DuplicateDetector: Sendable {
    private let remixKeywords = [
        "remix", "mix", "edit", "vip", "bootleg", 
        "mashup", "flip", "dub", "instrumental", 
        "acapella", "rmx"
    ]
    
    func findDuplicates(in files: [AudioFile]) -> [DuplicateGroup] {
        var groupsByMetadata: [String: [AudioFile]] = [:]
        var groupsBySize: [Int64: [AudioFile]] = [:]
        
        for file in files {
            // 1. Group by normalized Artist + Title
            let artist = normalize(file.displayArtist)
            let title = normalize(file.displayTitle)
            
            if !artist.isEmpty && !title.isEmpty && artist != "—" && title != file.fileName.lowercased() {
                let key = "\(artist)||\(title)"
                groupsByMetadata[key, default: []].append(file)
            }
            
            // 2. Group by exact file size (using URL)
            if let size = try? file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                groupsBySize[Int64(size), default: []].append(file)
            }
        }
        
        var resultGroups: [DuplicateGroup] = []
        var processedTrackIDs: Set<AudioFile.ID> = []
        
        // Process Metadata Groups
        for (_, tracks) in groupsByMetadata {
            if tracks.count > 1 {
                let validTracks = filterOutRemixes(from: tracks)
                if validTracks.count > 1 {
                    let group = DuplicateGroup(tracks: validTracks)
                    resultGroups.append(group)
                    processedTrackIDs.formUnion(validTracks.map(\.id))
                }
            }
        }
        
        // Process Size Groups (only for tracks not already grouped)
        for (_, tracks) in groupsBySize {
            let unprocessedTracks = tracks.filter { !processedTrackIDs.contains($0.id) }
            if unprocessedTracks.count > 1 {
                let validTracks = filterOutRemixes(from: unprocessedTracks)
                if validTracks.count > 1 {
                    let group = DuplicateGroup(tracks: validTracks)
                    resultGroups.append(group)
                    processedTrackIDs.formUnion(validTracks.map(\.id))
                }
            }
        }
        
        return resultGroups
    }
    
    private func filterOutRemixes(from tracks: [AudioFile]) -> [AudioFile] {
        var hasKeywordMap: [AudioFile: Bool] = [:]
        
        for track in tracks {
            let searchable = (track.displayTitle + " " + track.fileName).lowercased()
            let hasKeyword = remixKeywords.contains { searchable.contains($0) }
            hasKeywordMap[track] = hasKeyword
        }
        
        let allHaveKeywords = hasKeywordMap.values.allSatisfy { $0 == true }
        let noneHaveKeywords = hasKeywordMap.values.allSatisfy { $0 == false }
        
        if allHaveKeywords || noneHaveKeywords {
            return tracks 
        } else {
            // Mixed group: separate into original tracks and remix tracks.
            let originals = tracks.filter { hasKeywordMap[$0] == false }
            return originals
        }
    }
    
    private func normalize(_ string: String) -> String {
        return string.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).joined()
            .components(separatedBy: .punctuationCharacters).joined()
    }
}
