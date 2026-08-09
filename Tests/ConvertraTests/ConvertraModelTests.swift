import XCTest
@testable import Convertra

final class ConvertraModelTests: XCTestCase {
    func testDefaultConversionUses320KilobitCBRMP3() {
        let settings = ConversionSettings.mp3_320CBR

        XCTAssertEqual(settings.outputFormat, .mp3)
        XCTAssertEqual(settings.bitrate, .constant(kilobitsPerSecond: 320))
        XCTAssertTrue(settings.preserveMetadata)
        XCTAssertTrue(settings.preserveArtwork)
        XCTAssertTrue(settings.preserveFolderStructure)
    }
}
