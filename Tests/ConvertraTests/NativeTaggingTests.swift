import AVFoundation
import Foundation
import XCTest
@testable import Convertra

/// Verifies that native ID3 tagging round-trips through AVFoundation for the
/// containers Convertra tags natively (MP3-style ID3 blob + AIFF chunk).
final class NativeTaggingTests: XCTestCase {

    func testAIFFRoundTripsTitleArtistAndArtwork() async throws {
        let fm = FileManager.default
        let url = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).aiff")
        defer { try? fm.removeItem(at: url) }
        try makeSilentAIFF(at: url)

        // Stage artwork through the cache so the writer can pick it up.
        let cache = ArtworkCache()
        let artworkURL = try await cache.store(makePNG(), for: UUID())

        var metadata = AudioMetadata(title: "Náïve Тест", artist: "Convertra QA", album: "Block B")
        metadata.artworkLocation = artworkURL

        try await AudioMetadataWriter().write(metadata: metadata, to: url)

        // Re-read via the production extractor path.
        let file = AudioFile(url: url)
        let results = await AudioMetadataExtractor().read(files: [file])
        let read = try XCTUnwrap(results.first?.metadata)

        XCTAssertEqual(read.title, "Náïve Тест")
        XCTAssertEqual(read.artist, "Convertra QA")
        XCTAssertEqual(read.album, "Block B")
        XCTAssertNotNil(read.artworkLocation, "Cover art should survive the AIFF round-trip")

        // The AIFF must still be a decodable audio file.
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0.4)
    }

    func testMP3RoundTripsTitleArtistAndArtwork() async throws {
        let fm = FileManager.default
        guard let ffmpeg = locateFFmpeg() else {
            throw XCTSkip("ffmpeg not available to synthesize an MP3 fixture")
        }
        let url = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp3")
        defer { try? fm.removeItem(at: url) }
        try runFFmpeg(ffmpeg, ["-f", "lavfi", "-i", "sine=frequency=440:duration=1", "-b:a", "192k", url.path, "-y"])

        let cache = ArtworkCache()
        let artworkURL = try await cache.store(makePNG(), for: UUID())
        var metadata = AudioMetadata(title: "MP3 Тест", artist: "QA", album: "Block B")
        metadata.artworkLocation = artworkURL

        try await AudioMetadataWriter().write(metadata: metadata, to: url)

        let results = await AudioMetadataExtractor().read(files: [AudioFile(url: url)])
        let read = try XCTUnwrap(results.first?.metadata)
        XCTAssertEqual(read.title, "MP3 Тест")
        XCTAssertEqual(read.artist, "QA")
        XCTAssertNotNil(read.artworkLocation, "Cover art should survive the MP3 round-trip")

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0.4)
    }

    // MARK: - Fixtures

    private func locateFFmpeg() -> String? {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func runFFmpeg(_ path: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "ffmpeg fixture generation failed")
    }


    private func makeSilentAIFF(at url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: true,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let frames: AVAudioFrameCount = 44_100 / 2
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        try file.write(from: buffer)
    }

    private func makePNG() -> Data {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 16).fill()
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        let rep = NSBitmapImageRep(data: tiff)!
        return rep.representation(using: .png, properties: [:])!
    }
}
