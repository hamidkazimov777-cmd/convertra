import AppKit
import ImageIO

/// In-memory caches shared by track rows.
///
/// Prior to this, every visible row decoded its artwork from disk and ran a
/// `stat()` on its file on *every* SwiftUI `body` evaluation. Inside a
/// `LazyVStack`, bodies are re-evaluated constantly while scrolling, so those
/// synchronous disk operations piled up on the main thread and caused visible
/// scroll jank once the library held more than a screenful of tracks.
///
/// Both artwork and file size are effectively stable for a library item, so we
/// pay the disk cost at most once per URL and serve every later render from
/// memory. Visual output is identical — only the source of the data changes.
///
/// Artwork is additionally **downsampled** at decode time: cover art is often
/// 1000–1400 px square, but a row shows it at 36 pt (72 px on a 2× Retina
/// panel). Caching the full-resolution `NSImage` wasted hundreds of MB of RAM
/// on large libraries and forced the GPU to rescale a huge bitmap on every
/// composition. We now cache a thumbnail sized for the row, cutting both memory
/// and per-frame scaling cost with no visible difference.
@MainActor
enum RowContentCache {
    /// Row artwork renders in a 36 pt tile; 2× Retina needs 72 px. A little
    /// headroom (96 px) keeps it crisp without paying for full-resolution art.
    private static let thumbnailMaxPixelSize = 96

    private static let artworkCache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 512
        return cache
    }()

    /// Decodes, downsamples and caches the artwork thumbnail once per URL.
    /// Returns `nil` when the file is missing or unreadable so the caller can
    /// fall back to the placeholder tile.
    static func artwork(at url: URL) -> NSImage? {
        let key = url as NSURL
        if let cached = artworkCache.object(forKey: key) {
            return cached
        }
        guard let image = downsampledImage(at: url, maxPixelSize: thumbnailMaxPixelSize) else { return nil }
        artworkCache.setObject(image, forKey: key)
        return image
    }

    /// Produces a thumbnail no larger than `maxPixelSize` on its longest edge
    /// using ImageIO, which decodes straight to the target size instead of
    /// materializing the full-resolution bitmap first.
    private static func downsampledImage(at url: URL, maxPixelSize: Int) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Drops every in-memory thumbnail and file-size memo, reclaiming their RAM.
    /// Non-destructive: the next render simply re-decodes on demand. Backs the
    /// Settings "Clear cache" action.
    static func clear() {
        artworkCache.removeAllObjects()
        fileSizes.removeAll()
    }

    private static var fileSizes: [URL: Int64] = [:]

    /// Returns the file size, running the underlying `stat()` at most once per
    /// URL instead of on every row render.
    static func fileSize(for url: URL) -> Int64 {
        if let cached = fileSizes[url] { return cached }
        let size: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let value = attrs[.size] as? Int64 {
            size = value
        } else {
            size = 0
        }
        fileSizes[url] = size
        return size
    }
}
