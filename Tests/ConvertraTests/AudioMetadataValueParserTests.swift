import Foundation
import XCTest
@testable import Convertra

final class AudioMetadataValueParserTests: XCTestCase {
    func testYearParserReadsYearFromCommonDateFormats() {
        XCTAssertEqual(AudioMetadataValueParser.year(from: "2024"), 2024)
        XCTAssertEqual(AudioMetadataValueParser.year(from: "2021-08-10"), 2021)
        XCTAssertNil(AudioMetadataValueParser.year(from: "Unknown"))
    }

    func testTrackNumberParserReadsLeadingTrackNumber() {
        XCTAssertEqual(AudioMetadataValueParser.trackNumber(from: "07/12"), 7)
        XCTAssertEqual(AudioMetadataValueParser.trackNumber(from: "5"), 5)
        XCTAssertNil(AudioMetadataValueParser.trackNumber(from: "No track"))
    }
}
