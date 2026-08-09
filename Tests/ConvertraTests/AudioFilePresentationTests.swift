import Foundation
import XCTest
@testable import Convertra

final class AudioFilePresentationTests: XCTestCase {
    func testDisplayValuesUseMetadataAndTechnicalAnalysis() {
        let audioFile = AudioFile(
            url: URL(fileURLWithPath: "/Music/Example.mp3"),
            metadata: AudioMetadata(title: "  Midnight Set  ", artist: "  DJ Convertra  "),
            analysis: AudioAnalysis(
                duration: 125,
                bitrate: 320_000,
                sampleRate: 44_100,
                channels: 2,
                codec: .mp3
            )
        )

        XCTAssertEqual(audioFile.displayTitle, "Midnight Set")
        XCTAssertEqual(audioFile.displayArtist, "DJ Convertra")
        XCTAssertEqual(audioFile.displayDuration, "2:05")
        XCTAssertEqual(audioFile.displaySampleRate, "44.1 kHz")
        XCTAssertEqual(audioFile.displayBitrate, "320 kbps")
        XCTAssertEqual(audioFile.displayCodec, "MP3")
    }

    func testDisplayTitleFallsBackToFileNameWhenMetadataIsMissing() {
        let audioFile = AudioFile(url: URL(fileURLWithPath: "/Music/Example.wav"))

        XCTAssertEqual(audioFile.displayTitle, "Example")
        XCTAssertEqual(audioFile.displayArtist, "—")
        XCTAssertEqual(audioFile.displayDuration, "—")
    }
}
