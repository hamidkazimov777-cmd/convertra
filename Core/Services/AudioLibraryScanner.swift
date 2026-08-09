import Foundation

struct AudioLibraryScanResult: Sendable {
    let audioURLs: [URL]
    let skippedItemCount: Int
}

/// Discovers supported audio files without performing media analysis. The actor
/// keeps synchronous file-system traversal off the main actor.
actor AudioLibraryScanner {
    private let fileManager = FileManager.default

    func scan(urls: [URL]) -> AudioLibraryScanResult {
        var discoveredURLs = Set<URL>()
        var skippedItemCount = 0

        for url in urls {
            let normalizedURL = url.standardizedFileURL
            let accessedSecurityScope = normalizedURL.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScope {
                    normalizedURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let values = try normalizedURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                if values.isDirectory == true {
                    let result = scanDirectory(at: normalizedURL)
                    discoveredURLs.formUnion(result.audioURLs)
                    skippedItemCount += result.skippedItemCount
                } else if values.isRegularFile == true, SupportedAudioFormat.supports(normalizedURL) {
                    discoveredURLs.insert(normalizedURL)
                } else {
                    skippedItemCount += 1
                }
            } catch {
                skippedItemCount += 1
            }
        }

        return AudioLibraryScanResult(
            audioURLs: discoveredURLs.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending },
            skippedItemCount: skippedItemCount
        )
    }

    private func scanDirectory(at directoryURL: URL) -> AudioLibraryScanResult {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return AudioLibraryScanResult(audioURLs: [], skippedItemCount: 1)
        }

        var audioURLs: [URL] = []
        var skippedItemCount = 0

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: resourceKeys)
                guard values.isRegularFile == true else { continue }

                if SupportedAudioFormat.supports(fileURL) {
                    audioURLs.append(fileURL.standardizedFileURL)
                } else {
                    skippedItemCount += 1
                }
            } catch {
                skippedItemCount += 1
            }
        }

        return AudioLibraryScanResult(audioURLs: audioURLs, skippedItemCount: skippedItemCount)
    }
}
