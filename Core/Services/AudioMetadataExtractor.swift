import AVFoundation
import Foundation

struct AudioMetadataReadResult: Sendable {
    let audioFileID: AudioFile.ID
    let metadata: AudioMetadata?
}

/// Reads standard, iTunes, and ID3 metadata without modifying the source file.
struct AudioMetadataExtractor: Sendable {
    private let artworkCache: ArtworkCache

    init(artworkCache: ArtworkCache = ArtworkCache()) {
        self.artworkCache = artworkCache
    }

    func read(files: [AudioFile]) async -> [AudioMetadataReadResult] {
        var results: [AudioMetadataReadResult] = []
        results.reserveCapacity(files.count)

        for audioFile in files {
            results.append(await read(audioFile))
        }
        return results
    }

    private func read(_ audioFile: AudioFile) async -> AudioMetadataReadResult {
        let accessedSecurityScope = audioFile.url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                audioFile.url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let asset = AVURLAsset(url: audioFile.url)
            let commonMetadata = try await asset.load(.commonMetadata)
            let fileMetadata = try await asset.load(.metadata)
            let metadataItems = commonMetadata + fileMetadata
            var metadata = AudioMetadata(
                title: stringValue(in: metadataItems, identifiers: Self.titleIdentifiers),
                artist: stringValue(in: metadataItems, identifiers: Self.artistIdentifiers),
                album: stringValue(in: metadataItems, identifiers: Self.albumIdentifiers),
                albumArtist: stringValue(in: metadataItems, identifiers: Self.albumArtistIdentifiers),
                genre: stringValue(in: metadataItems, identifiers: Self.genreIdentifiers),
                year: yearValue(in: metadataItems),
                trackNumber: trackNumberValue(in: metadataItems),
                discNumber: intValue(in: metadataItems, identifiers: Self.discNumberIdentifiers),
                comments: stringValue(in: metadataItems, identifiers: Self.commentIdentifiers),
                isrc: stringValue(in: metadataItems, identifiers: Self.isrcIdentifiers),
                composer: stringValue(in: metadataItems, identifiers: Self.composerIdentifiers),
                grouping: stringValue(in: metadataItems, identifiers: Self.groupingIdentifiers),
                publisher: stringValue(in: metadataItems, identifiers: Self.publisherIdentifiers),
                copyright: stringValue(in: metadataItems, identifiers: Self.copyrightIdentifiers),
                bpmTag: intValue(in: metadataItems, identifiers: Self.bpmIdentifiers),
                initialKey: stringValue(in: metadataItems, identifiers: Self.keyIdentifiers)
            )

            if let artworkData = dataValue(in: metadataItems, identifiers: Self.artworkIdentifiers), !artworkData.isEmpty {
                metadata.artworkLocation = try? await artworkCache.store(artworkData, for: audioFile.id)
            }

            return AudioMetadataReadResult(audioFileID: audioFile.id, metadata: metadata)
        } catch {
            return AudioMetadataReadResult(audioFileID: audioFile.id, metadata: nil)
        }
    }

    private func stringValue(
        in metadataItems: [AVMetadataItem],
        identifiers: [AVMetadataIdentifier]
    ) -> String? {
        guard let item = metadataItems.first(where: { item in
            guard let identifier = item.identifier else { return false }
            return identifiers.contains(identifier)
        }) else {
            return nil
        }

        let value = item.stringValue ?? item.numberValue?.stringValue
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func dataValue(
        in metadataItems: [AVMetadataItem],
        identifiers: [AVMetadataIdentifier]
    ) -> Data? {
        metadataItems.first { item in
            guard let identifier = item.identifier else { return false }
            return identifiers.contains(identifier)
        }?.dataValue
    }

    private func yearValue(in metadataItems: [AVMetadataItem]) -> Int? {
        guard let value = stringValue(in: metadataItems, identifiers: Self.yearIdentifiers) else { return nil }
        return AudioMetadataValueParser.year(from: value)
    }

    private func trackNumberValue(in metadataItems: [AVMetadataItem]) -> Int? {
        guard let value = stringValue(in: metadataItems, identifiers: Self.trackNumberIdentifiers) else { return nil }
        return AudioMetadataValueParser.trackNumber(from: value)
    }

    private func intValue(in metadataItems: [AVMetadataItem], identifiers: [AVMetadataIdentifier]) -> Int? {
        guard let value = stringValue(in: metadataItems, identifiers: identifiers) else { return nil }
        return AudioMetadataValueParser.trackNumber(from: value)
    }

    private static let titleIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierTitle,
        .iTunesMetadataSongName,
        .id3MetadataTitleDescription
    ]
    private static let artistIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierArtist,
        .iTunesMetadataArtist,
        .id3MetadataLeadPerformer
    ]
    private static let albumIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierAlbumName,
        .iTunesMetadataAlbum,
        .id3MetadataAlbumTitle
    ]
    private static let genreIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataUserGenre,
        .id3MetadataContentType
    ]
    private static let yearIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierCreationDate,
        .iTunesMetadataReleaseDate,
        .id3MetadataYear
    ]
    private static let trackNumberIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataTrackNumber,
        .id3MetadataTrackNumber
    ]
    private static let commentIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierDescription,
        .iTunesMetadataUserComment,
        .id3MetadataComments
    ]
    private static let isrcIdentifiers: [AVMetadataIdentifier] = [
        .id3MetadataInternationalStandardRecordingCode
    ]
    private static let composerIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataComposer,
        .id3MetadataComposer,
        .commonIdentifierCreator
    ]
    private static let artworkIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierArtwork,
        .iTunesMetadataCoverArt,
        .id3MetadataAttachedPicture
    ]
    private static let albumArtistIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataAlbumArtist,
        .id3MetadataBand
    ]
    private static let discNumberIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataDiscNumber,
        .id3MetadataPartOfASet
    ]
    private static let groupingIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataGrouping,
        .id3MetadataContentGroupDescription
    ]
    private static let publisherIdentifiers: [AVMetadataIdentifier] = [
        .id3MetadataPublisher,
        .commonIdentifierPublisher
    ]
    private static let copyrightIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierCopyrights,
        .iTunesMetadataCopyright,
        .id3MetadataCopyright
    ]
    private static let bpmIdentifiers: [AVMetadataIdentifier] = [
        .iTunesMetadataBeatsPerMin,
        .id3MetadataBeatsPerMinute
    ]
    private static let keyIdentifiers: [AVMetadataIdentifier] = [
        .id3MetadataInitialKey
    ]
}

enum AudioMetadataValueParser {
    static func year(from value: String) -> Int? {
        let digits = value.filter(\.isNumber)
        guard digits.count >= 4, let year = Int(digits.prefix(4)), (1000...9999).contains(year) else {
            return nil
        }
        return year
    }

    static func trackNumber(from value: String) -> Int? {
        let digitGroups = value.split(whereSeparator: { !$0.isNumber })
        guard let firstGroup = digitGroups.first, let trackNumber = Int(firstGroup), trackNumber > 0 else {
            return nil
        }
        return trackNumber
    }
}
