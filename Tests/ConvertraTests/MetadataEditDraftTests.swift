import Foundation
import XCTest
@testable import Convertra

final class MetadataEditDraftTests: XCTestCase {
    func testApplyingDraftChangesOnlyEnabledFields() throws {
        var draft = MetadataEditDraft()
        draft.title = MetadataEditField(isEnabled: true, value: "New Title")
        draft.year = MetadataEditField(isEnabled: true, value: "2024")
        let original = AudioMetadata(title: "Old Title", artist: "Artist", year: 1999)

        let updated = try draft.applying(to: original)

        XCTAssertEqual(updated.title, "New Title")
        XCTAssertEqual(updated.artist, "Artist")
        XCTAssertEqual(updated.year, 2024)
    }

    func testBlankEnabledValueClearsMetadataField() throws {
        var draft = MetadataEditDraft()
        draft.genre = MetadataEditField(isEnabled: true, value: "  ")

        let updated = try draft.applying(to: AudioMetadata(genre: "House"))

        XCTAssertNil(updated.genre)
    }

    func testDraftRejectsInvalidNumericValues() {
        var draft = MetadataEditDraft()
        draft.trackNumber = MetadataEditField(isEnabled: true, value: "zero")

        XCTAssertThrowsError(try draft.applying(to: .empty)) { error in
            XCTAssertEqual(error as? MetadataEditValidationError, .invalidTrackNumber)
        }
    }
}
