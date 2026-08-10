import XCTest
@testable import Convertra

final class CamelotKeyTests: XCTestCase {
    func testMusicalKeyToCamelotMapping() {
        XCTAssertEqual(MusicalKey.fMinor.camelotKey.code, "4A")
        XCTAssertEqual(MusicalKey.cMajor.camelotKey.code, "8B")
        XCTAssertEqual(MusicalKey.aMinor.camelotKey.code, "8A")
        XCTAssertEqual(MusicalKey.eMinor.camelotKey.code, "9A")
        XCTAssertEqual(MusicalKey.bMinor.camelotKey.code, "10A")
        XCTAssertEqual(MusicalKey.gSharpMinor.camelotKey.code, "1A")
        XCTAssertEqual(MusicalKey.bMajor.camelotKey.code, "1B")
        XCTAssertEqual(MusicalKey.eMajor.camelotKey.code, "12B")
    }

    func testCamelotCodeParsing() {
        let key4A = CamelotKey(code: "4A")
        XCTAssertNotNil(key4A)
        XCTAssertEqual(key4A?.number, 4)
        XCTAssertEqual(key4A?.mode, .a)
        XCTAssertEqual(key4A?.musicalKey, .fMinor)

        let key8B = CamelotKey(code: "8b")
        XCTAssertNotNil(key8B)
        XCTAssertEqual(key8B?.number, 8)
        XCTAssertEqual(key8B?.mode, .b)
        XCTAssertEqual(key8B?.musicalKey, .cMajor)

        XCTAssertNil(CamelotKey(code: "13A"))
        XCTAssertNil(CamelotKey(code: "0B"))
        XCTAssertNil(CamelotKey(code: "XYZ"))
    }

    func testHarmonicCompatibilityMatches() {
        guard let key4A = CamelotKey(code: "4A") else {
            XCTFail("Could not create 4A key")
            return
        }

        let matches = key4A.harmonicMatches
        let matchCodes = matches.map(\.code)

        // 4A should be compatible with: 4A (Same), 4B (Relative Major), 5A (+1 step), 3A (-1 step), 5B & 3B (Diagonal)
        XCTAssertTrue(matchCodes.contains("4A"), "Exact match missing")
        XCTAssertTrue(matchCodes.contains("4B"), "Relative Major missing")
        XCTAssertTrue(matchCodes.contains("5A"), "Energy +1 step missing")
        XCTAssertTrue(matchCodes.contains("3A"), "Energy -1 step missing")
        XCTAssertTrue(matchCodes.contains("5B"), "Diagonal +1 missing")
        XCTAssertTrue(matchCodes.contains("3B"), "Diagonal -1 missing")
    }

    func testWheelBoundaryWrap() {
        guard let key12A = CamelotKey(code: "12A") else {
            XCTFail("Could not create 12A key")
            return
        }

        let matches = key12A.harmonicMatches.map(\.code)
        // 12A should wrap around to 1A (+1 step) and 11A (-1 step)
        XCTAssertTrue(matches.contains("1A"), "12A -> 1A wrap missing")
        XCTAssertTrue(matches.contains("11A"), "12A -> 11A step missing")

        guard let key1A = CamelotKey(code: "1A") else {
            XCTFail("Could not create 1A key")
            return
        }
        let matches1A = key1A.harmonicMatches.map(\.code)
        // 1A should wrap down to 12A (-1 step) and 2A (+1 step)
        XCTAssertTrue(matches1A.contains("12A"), "1A -> 12A wrap missing")
        XCTAssertTrue(matches1A.contains("2A"), "1A -> 2A step missing")
    }

    func testDistanceCalculation() {
        let key4A = CamelotKey(code: "4A")!
        let key5A = CamelotKey(code: "5A")!
        let key10A = CamelotKey(code: "10A")!
        let key4B = CamelotKey(code: "4B")!

        XCTAssertEqual(key4A.distance(to: key5A), 1)
        XCTAssertEqual(key4A.distance(to: key4B), 1) // Mode change adds 1 step
        XCTAssertEqual(key4A.distance(to: key10A), 6) // Shortest path around 12-position wheel: 4 -> 10 is 6 steps
    }
}
