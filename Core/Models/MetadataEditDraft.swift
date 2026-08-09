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
    var genre = MetadataEditField()
    var year = MetadataEditField()
    var trackNumber = MetadataEditField()
    var comments = MetadataEditField()
    var isrc = MetadataEditField()
    var composer = MetadataEditField()
    var artworkMode: ArtworkEditMode = .unchanged
    var artworkData: Data?

    init(files: [AudioFile] = []) {
        title.value = Self.commonString(files, keyPath: \.metadata.title)
        artist.value = Self.commonString(files, keyPath: \.metadata.artist)
        album.value = Self.commonString(files, keyPath: \.metadata.album)
        genre.value = Self.commonString(files, keyPath: \.metadata.genre)
        year.value = Self.commonInteger(files, keyPath: \.metadata.year)
        trackNumber.value = Self.commonInteger(files, keyPath: \.metadata.trackNumber)
        comments.value = Self.commonString(files, keyPath: \.metadata.comments)
        isrc.value = Self.commonString(files, keyPath: \.metadata.isrc)
        composer.value = Self.commonString(files, keyPath: \.metadata.composer)
    }

    var hasChanges: Bool {
        [title, artist, album, genre, year, trackNumber, comments, isrc, composer].contains(where: \.isEnabled)
            || artworkMode != .unchanged
    }

    func applying(to metadata: AudioMetadata) throws -> AudioMetadata {
        if artworkMode == .replace, artworkData == nil {
            throw MetadataEditValidationError.missingArtwork
        }

        var updatedMetadata = metadata
        if title.isEnabled { updatedMetadata.title = valueOrNil(title.value) }
        if artist.isEnabled { updatedMetadata.artist = valueOrNil(artist.value) }
        if album.isEnabled { updatedMetadata.album = valueOrNil(album.value) }
        if genre.isEnabled { updatedMetadata.genre = valueOrNil(genre.value) }
        if comments.isEnabled { updatedMetadata.comments = valueOrNil(comments.value) }
        if isrc.isEnabled { updatedMetadata.isrc = valueOrNil(isrc.value) }
        if composer.isEnabled { updatedMetadata.composer = valueOrNil(composer.value) }

        if year.isEnabled {
            let value = valueOrNil(year.value)
            guard let value else {
                updatedMetadata.year = nil
                return try applyTrackNumberAndArtwork(to: updatedMetadata)
            }
            guard value.count == 4, let parsedYear = Int(value) else {
                throw MetadataEditValidationError.invalidYear
            }
            updatedMetadata.year = parsedYear
        }

        return try applyTrackNumberAndArtwork(to: updatedMetadata)
    }

    private func applyTrackNumberAndArtwork(to metadata: AudioMetadata) throws -> AudioMetadata {
        var updatedMetadata = metadata
        if trackNumber.isEnabled {
            let value = valueOrNil(trackNumber.value)
            guard let value else {
                updatedMetadata.trackNumber = nil
                if artworkMode == .remove {
                    updatedMetadata.artworkLocation = nil
                }
                return updatedMetadata
            }
            guard let parsedTrackNumber = Int(value), parsedTrackNumber > 0 else {
                throw MetadataEditValidationError.invalidTrackNumber
            }
            updatedMetadata.trackNumber = parsedTrackNumber
        }
        if artworkMode == .remove {
            updatedMetadata.artworkLocation = nil
        }
        return updatedMetadata
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
