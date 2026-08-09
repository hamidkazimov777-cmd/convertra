import Foundation

struct AudioMetadata: Codable, Hashable, Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var comments: String?
    var isrc: String?
    var composer: String?
    /// Artwork data is intentionally not held here yet, preventing large library
    /// records from retaining image data in memory.
    var artworkLocation: URL?

    static let empty = AudioMetadata()

    init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        comments: String? = nil,
        isrc: String? = nil,
        composer: String? = nil,
        artworkLocation: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.comments = comments
        self.isrc = isrc
        self.composer = composer
        self.artworkLocation = artworkLocation
    }
}
