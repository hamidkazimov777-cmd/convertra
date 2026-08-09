import Foundation
import XCTest
@testable import Convertra

final class AudioTechnicalMetadataExtractorTests: XCTestCase {
    func testExtractorReadsPCMPropertiesFromWAVFile() async throws {
        let fileManager = FileManager.default
        let fileURL = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? fileManager.removeItem(at: fileURL) }

        try makeOneSecondStereoWAV().write(to: fileURL)

        let result = await AudioTechnicalMetadataExtractor().analyze(urls: [fileURL])

        XCTAssertEqual(result.count, 1)
        let analysis = try XCTUnwrap(result.first?.analysis)
        XCTAssertEqual(analysis.codec, .wav)
        XCTAssertEqual(analysis.sampleRate, 44_100)
        XCTAssertEqual(analysis.channels, 2)
        XCTAssertEqual(analysis.duration, 1, accuracy: 0.02)
    }

    private func makeOneSecondStereoWAV() -> Data {
        let sampleRate: UInt32 = 44_100
        let channels: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let audioDataSize = Int(byteRate)

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        appendLittleEndian(UInt32(36 + audioDataSize), to: &data)
        data.append("WAVEfmt ".data(using: .ascii)!)
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(channels, to: &data)
        appendLittleEndian(sampleRate, to: &data)
        appendLittleEndian(byteRate, to: &data)
        appendLittleEndian(blockAlign, to: &data)
        appendLittleEndian(bitsPerSample, to: &data)
        data.append("data".data(using: .ascii)!)
        appendLittleEndian(UInt32(audioDataSize), to: &data)
        data.append(Data(repeating: 0, count: audioDataSize))
        return data
    }

    private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
