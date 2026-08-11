import Foundation

/// Inserts/replaces an ID3v2 tag inside MP3 and AIFF containers at the byte
/// level. This is what lets Convertra write cover art into AIFF files, which
/// FFmpeg's AIFF muxer silently drops. Pure functions over `Data` for testability.
enum NativeContainerTagger {

    enum TaggerError: Error, LocalizedError {
        case unsupportedContainer
        case malformedFile(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedContainer:
                return "This file format does not support native ID3 tagging."
            case let .malformedFile(reason):
                return "The audio file structure could not be parsed: \(reason)."
            }
        }
    }

    /// Returns a new file image for `fileData` with `id3Tag` applied, choosing
    /// the container strategy from the leading bytes.
    static func apply(id3Tag: Data, to fileData: Data) throws -> Data {
        if fileData.starts(with: Array("FORM".utf8)) {
            return try applyToAIFF(id3Tag: id3Tag, fileData: fileData)
        }
        // MP3: either starts with an existing "ID3" tag or with an MPEG frame sync (0xFF Ex/Fx).
        return applyToMP3(id3Tag: id3Tag, fileData: fileData)
    }

    static func supports(pathExtension: String) -> Bool {
        ["mp3", "aif", "aiff", "aifc"].contains(pathExtension.lowercased())
    }

    // MARK: - MP3

    private static func applyToMP3(id3Tag: Data, fileData: Data) -> Data {
        var audioStart = 0
        let bytes = [UInt8](fileData)
        if bytes.count >= 10, bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 { // "ID3"
            let flags = bytes[5]
            let size = decodeSynchsafe(bytes[6], bytes[7], bytes[8], bytes[9])
            var tagSize = 10 + Int(size)
            if flags & 0x10 != 0 { tagSize += 10 } // footer present
            if tagSize <= bytes.count { audioStart = tagSize }
        }
        var result = Data()
        result.append(id3Tag)
        result.append(fileData.subdata(in: audioStart..<fileData.count))
        return result
    }

    // MARK: - AIFF

    private static func applyToAIFF(id3Tag: Data, fileData: Data) throws -> Data {
        let bytes = [UInt8](fileData)
        guard bytes.count >= 12 else { throw TaggerError.malformedFile("file too small") }
        let formType = Array(bytes[8..<12]) // "AIFF" or "AIFC"

        // Walk the top-level chunks, keeping every one except an existing "ID3 ".
        var chunks: [(id: [UInt8], data: [UInt8])] = []
        var cursor = 12
        while cursor + 8 <= bytes.count {
            let chunkID = Array(bytes[cursor..<cursor + 4])
            let sizeBytes = Array(bytes[cursor + 4..<cursor + 8])
            let size = Int(UInt32(sizeBytes[0]) << 24 | UInt32(sizeBytes[1]) << 16 | UInt32(sizeBytes[2]) << 8 | UInt32(sizeBytes[3]))
            let dataStart = cursor + 8
            let dataEnd = min(dataStart + size, bytes.count)
            guard dataStart <= dataEnd else { throw TaggerError.malformedFile("bad chunk size") }
            let chunkData = Array(bytes[dataStart..<dataEnd])
            let isID3 = chunkID == Array("ID3 ".utf8)
            if !isID3 {
                chunks.append((chunkID, chunkData))
            }
            // Advance past data + pad byte (chunks are word-aligned).
            cursor = dataStart + size + (size % 2)
        }

        // Append the fresh ID3 chunk at the end.
        chunks.append((Array("ID3 ".utf8), [UInt8](id3Tag)))

        // Reassemble the FORM.
        var body = Data()
        body.append(contentsOf: formType)
        for chunk in chunks {
            body.append(contentsOf: chunk.id)
            body.append(contentsOf: bigEndian(UInt32(chunk.data.count)))
            body.append(contentsOf: chunk.data)
            if chunk.data.count % 2 == 1 { body.append(0x00) } // pad
        }

        var result = Data()
        result.append(contentsOf: Array("FORM".utf8))
        result.append(contentsOf: bigEndian(UInt32(body.count)))
        result.append(body)
        return result
    }

    // MARK: - Helpers

    private static func decodeSynchsafe(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) -> UInt32 {
        (UInt32(b0 & 0x7F) << 21) | (UInt32(b1 & 0x7F) << 14) | (UInt32(b2 & 0x7F) << 7) | UInt32(b3 & 0x7F)
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }
}
