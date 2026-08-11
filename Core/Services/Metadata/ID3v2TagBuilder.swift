import Foundation

/// Builds a complete ID3v2.3 tag blob from `AudioMetadata` (+ optional artwork).
///
/// Text frames are encoded as UTF-16 with a BOM (encoding byte 0x01), which is
/// the ID3v2.3-standard Unicode form and safely carries Cyrillic and other
/// non-Latin characters. Artwork is embedded as an APIC frame (front cover).
enum ID3v2TagBuilder {

    /// The picture kinds we recognise for the artwork MIME type.
    private static func mimeType(for imageData: Data) -> String {
        let bytes = [UInt8](imageData.prefix(4))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        return "image/jpeg"
    }

    /// Produces the full tag: "ID3" header + synchsafe size + frames.
    static func build(metadata: AudioMetadata, artwork: Data?) -> Data {
        var frames = Data()

        func textFrame(_ id: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            frames.append(makeTextFrame(id: id, text: value))
        }

        textFrame("TIT2", metadata.title)
        textFrame("TPE1", metadata.artist)
        textFrame("TALB", metadata.album)
        textFrame("TPE2", metadata.albumArtist)
        textFrame("TCON", metadata.genre)
        textFrame("TYER", metadata.year.map(String.init))
        textFrame("TRCK", metadata.trackNumber.map(String.init))
        textFrame("TPOS", metadata.discNumber.map(String.init))
        textFrame("TCOM", metadata.composer)
        textFrame("TIT1", metadata.grouping)
        textFrame("TPUB", metadata.publisher)
        textFrame("TCOP", metadata.copyright)
        textFrame("TBPM", metadata.bpmTag.map(String.init))
        textFrame("TKEY", metadata.initialKey)
        textFrame("TSRC", metadata.isrc)

        if let comment = metadata.comments, !comment.isEmpty {
            frames.append(makeCommentFrame(text: comment))
        }
        if let artwork, !artwork.isEmpty {
            frames.append(makeAPICFrame(imageData: artwork))
        }

        var tag = Data()
        tag.append(contentsOf: Array("ID3".utf8))       // identifier
        tag.append(contentsOf: [0x03, 0x00])            // version 2.3.0
        tag.append(0x00)                                 // flags
        tag.append(contentsOf: synchsafe(UInt32(frames.count)))
        tag.append(frames)
        return tag
    }

    // MARK: - Frame builders

    private static func makeTextFrame(id: String, text: String) -> Data {
        var content = Data()
        content.append(0x01) // UTF-16 with BOM
        content.append(utf16BOMEncoded(text))

        var frame = Data()
        frame.append(contentsOf: Array(id.utf8))
        frame.append(contentsOf: bigEndian(UInt32(content.count)))
        frame.append(contentsOf: [0x00, 0x00]) // flags
        frame.append(content)
        return frame
    }

    private static func makeCommentFrame(text: String) -> Data {
        var content = Data()
        content.append(0x01)                             // encoding: UTF-16 + BOM
        content.append(contentsOf: Array("eng".utf8))    // language
        content.append(contentsOf: [0xFF, 0xFE, 0x00, 0x00]) // empty short description (BOM + terminator)
        content.append(utf16BOMEncoded(text))

        var frame = Data()
        frame.append(contentsOf: Array("COMM".utf8))
        frame.append(contentsOf: bigEndian(UInt32(content.count)))
        frame.append(contentsOf: [0x00, 0x00])
        frame.append(content)
        return frame
    }

    private static func makeAPICFrame(imageData: Data) -> Data {
        var content = Data()
        content.append(0x00) // encoding for the text fields: ISO-8859-1
        content.append(contentsOf: Array(mimeType(for: imageData).utf8))
        content.append(0x00) // MIME terminator
        content.append(0x03) // picture type: front cover
        content.append(0x00) // empty description terminator (ISO-8859-1)
        content.append(imageData)

        var frame = Data()
        frame.append(contentsOf: Array("APIC".utf8))
        frame.append(contentsOf: bigEndian(UInt32(content.count)))
        frame.append(contentsOf: [0x00, 0x00])
        frame.append(content)
        return frame
    }

    // MARK: - Encoding helpers

    /// UTF-16 little-endian with a leading BOM and a trailing double-null.
    private static func utf16BOMEncoded(_ text: String) -> Data {
        var data = Data([0xFF, 0xFE]) // little-endian BOM
        for unit in text.utf16 {
            data.append(UInt8(unit & 0xFF))
            data.append(UInt8(unit >> 8))
        }
        data.append(contentsOf: [0x00, 0x00]) // terminator
        return data
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    /// 28-bit synchsafe integer used by the ID3v2 tag-size header field.
    private static func synchsafe(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value >> 21 & 0x7F),
            UInt8(value >> 14 & 0x7F),
            UInt8(value >> 7 & 0x7F),
            UInt8(value & 0x7F)
        ]
    }
}
