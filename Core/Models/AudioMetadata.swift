import Foundation

struct AudioMetadata: Codable, Hashable, Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var comments: String?
    var isrc: String?
    var composer: String?
    var grouping: String?
    var publisher: String?
    var copyright: String?
    /// BPM value stored in the file's tag (distinct from analyzed BPM).
    var bpmTag: Int?
    /// Key value stored in the file's tag (e.g. "8A", "Am"), distinct from analysis.
    var initialKey: String?
    /// Artwork data is intentionally not held here, preventing large library
    /// records from retaining image data in memory. Points to a cached file.
    var artworkLocation: URL?

    static let empty = AudioMetadata()

    init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        comments: String? = nil,
        isrc: String? = nil,
        composer: String? = nil,
        grouping: String? = nil,
        publisher: String? = nil,
        copyright: String? = nil,
        bpmTag: Int? = nil,
        initialKey: String? = nil,
        artworkLocation: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.comments = comments
        self.isrc = isrc
        self.composer = composer
        self.grouping = grouping
        self.publisher = publisher
        self.copyright = copyright
        self.bpmTag = bpmTag
        self.initialKey = initialKey
        self.artworkLocation = artworkLocation
    }

    func merged(with readMetadata: AudioMetadata) -> AudioMetadata {
        AudioMetadata(
            title: readMetadata.title ?? title,
            artist: readMetadata.artist ?? artist,
            album: readMetadata.album ?? album,
            albumArtist: readMetadata.albumArtist ?? albumArtist,
            genre: readMetadata.genre ?? genre,
            year: readMetadata.year ?? year,
            trackNumber: readMetadata.trackNumber ?? trackNumber,
            discNumber: readMetadata.discNumber ?? discNumber,
            comments: readMetadata.comments ?? comments,
            isrc: readMetadata.isrc ?? isrc,
            composer: readMetadata.composer ?? composer,
            grouping: readMetadata.grouping ?? grouping,
            publisher: readMetadata.publisher ?? publisher,
            copyright: readMetadata.copyright ?? copyright,
            bpmTag: readMetadata.bpmTag ?? bpmTag,
            initialKey: readMetadata.initialKey ?? initialKey,
            artworkLocation: readMetadata.artworkLocation ?? artworkLocation
        )
    }
}
