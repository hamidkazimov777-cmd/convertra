import Foundation

struct MetadataEditField: Equatable, Sendable {
    var isEnabled = false
    var value = ""
}

enum ArtworkEditMode: String, CaseIterable, Identifiable, Sendable {
    case unchanged = "Keep existing"
    case replace = "Replace artwork"
    case remove = "Remove artwork"

    var id: Self { self }
}

enum MetadataEditValidationError: LocalizedError, Equatable {
    case invalidYear
    case invalidTrackNumber
    case missingArtwork

    var errorDescription: String? {
        switch self {
        case .invalidYear: return "Year must be a four-digit number."
        case .invalidTrackNumber: return "Track number must be a positive whole number."
        case .missingArtwork: return "Choose an image before replacing artwork."
        }
    }
}

struct MetadataEditDraft: Equatable, Sendable {
    var title = MetadataEditField()
    var artist = MetadataEditField()
    var album = MetadataEditField()
    var albumArtist = MetadataEditField()
    var genre = MetadataEditField()
    var year = MetadataEditField()
    var trackNumber = MetadataEditField()
    var discNumber = MetadataEditField()
    var composer = MetadataEditField()
    var grouping = MetadataEditField()
    var publisher = MetadataEditField()
    var comments = MetadataEditField()
    var bpmTag = MetadataEditField()
    var initialKey = MetadataEditField()
    var isrc = MetadataEditField()
    var copyright = MetadataEditField()
    var artworkMode: ArtworkEditMode = .unchanged
    var artworkData: Data?

    private var allFields: [MetadataEditField] {
        [title, artist, album, albumArtist, genre, year, trackNumber, discNumber,
         composer, grouping, publisher, comments, bpmTag, initialKey, isrc, copyright]
    }

    init(files: [AudioFile] = []) {
        title.value = Self.commonString(files, keyPath: \.metadata.title)
        artist.value = Self.commonString(files, keyPath: \.metadata.artist)
        album.value = Self.commonString(files, keyPath: \.metadata.album)
        albumArtist.value = Self.commonString(files, keyPath: \.metadata.albumArtist)
        genre.value = Self.commonString(files, keyPath: \.metadata.genre)
        year.value = Self.commonInteger(files, keyPath: \.metadata.year)
        trackNumber.value = Self.commonInteger(files, keyPath: \.metadata.trackNumber)
        discNumber.value = Self.commonInteger(files, keyPath: \.metadata.discNumber)
        composer.value = Self.commonString(files, keyPath: \.metadata.composer)
        grouping.value = Self.commonString(files, keyPath: \.metadata.grouping)
        publisher.value = Self.commonString(files, keyPath: \.metadata.publisher)
        comments.value = Self.commonString(files, keyPath: \.metadata.comments)
        bpmTag.value = Self.commonInteger(files, keyPath: \.metadata.bpmTag)
        initialKey.value = Self.commonString(files, keyPath: \.metadata.initialKey)
        isrc.value = Self.commonString(files, keyPath: \.metadata.isrc)
        copyright.value = Self.commonString(files, keyPath: \.metadata.copyright)
    }

    var hasChanges: Bool {
        allFields.contains(where: \.isEnabled) || artworkMode != .unchanged
    }

    func applying(to metadata: AudioMetadata) throws -> AudioMetadata {
        if artworkMode == .replace, artworkData == nil {
            throw MetadataEditValidationError.missingArtwork
        }

        var m = metadata
        if title.isEnabled { m.title = valueOrNil(title.value) }
        if artist.isEnabled { m.artist = valueOrNil(artist.value) }
        if album.isEnabled { m.album = valueOrNil(album.value) }
        if albumArtist.isEnabled { m.albumArtist = valueOrNil(albumArtist.value) }
        if genre.isEnabled { m.genre = valueOrNil(genre.value) }
        if composer.isEnabled { m.composer = valueOrNil(composer.value) }
        if grouping.isEnabled { m.grouping = valueOrNil(grouping.value) }
        if publisher.isEnabled { m.publisher = valueOrNil(publisher.value) }
        if comments.isEnabled { m.comments = valueOrNil(comments.value) }
        if initialKey.isEnabled { m.initialKey = valueOrNil(initialKey.value) }
        if isrc.isEnabled { m.isrc = valueOrNil(isrc.value) }
        if copyright.isEnabled { m.copyright = valueOrNil(copyright.value) }

        if year.isEnabled {
            if let value = valueOrNil(year.value) {
                guard value.count == 4, let parsed = Int(value) else {
                    throw MetadataEditValidationError.invalidYear
                }
                m.year = parsed
            } else {
                m.year = nil
            }
        }
        if trackNumber.isEnabled {
            m.trackNumber = try positiveInt(trackNumber.value)
        }
        if discNumber.isEnabled {
            m.discNumber = try positiveInt(discNumber.value)
        }
        if bpmTag.isEnabled {
            m.bpmTag = try positiveInt(bpmTag.value)
        }
        if artworkMode == .remove {
            m.artworkLocation = nil
        }
        return m
    }

    private func positiveInt(_ raw: String) throws -> Int? {
        guard let value = valueOrNil(raw) else { return nil }
        guard let parsed = Int(value), parsed > 0 else {
            throw MetadataEditValidationError.invalidTrackNumber
        }
        return parsed
    }

    private func valueOrNil(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func commonString(_ files: [AudioFile], keyPath: KeyPath<AudioFile, String?>) -> String {
        let values = files.map { $0[keyPath: keyPath] }
        guard let firstValue = values.first, values.allSatisfy({ $0 == firstValue }) else { return "" }
        return firstValue ?? ""
    }

    private static func commonInteger(_ files: [AudioFile], keyPath: KeyPath<AudioFile, Int?>) -> String {
        let values = files.map { $0[keyPath: keyPath] }
        guard let firstValue = values.first, values.allSatisfy({ $0 == firstValue }) else { return "" }
        return firstValue.map(String.init) ?? ""
    }
}
