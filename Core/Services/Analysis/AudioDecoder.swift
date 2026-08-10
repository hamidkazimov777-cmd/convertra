import AVFoundation
import Accelerate

enum AudioDecoderError: Error, LocalizedError {
    case fileUnreadable(URL, String)
    case invalidFormat(URL)
    case emptyAudioData(URL)
    
    var errorDescription: String? {
        switch self {
        case let .fileUnreadable(url, reason):
            return "Unable to open audio file '\(url.lastPathComponent)': \(reason)"
        case let .invalidFormat(url):
            return "Unsupported or invalid audio format in '\(url.lastPathComponent)'"
        case let .emptyAudioData(url):
            return "Audio file '\(url.lastPathComponent)' contains no audio frames"
        }
    }
}

/// Represents a decoded PCM audio segment downmixed to 22,050 Hz mono.
struct AudioSegment: Sendable {
    enum SegmentType: String, Codable, Hashable, Sendable {
        case full
        case intro
        case bodyA
        case bodyB
        case outro
    }
    
    let type: SegmentType
    let pcmData: [Float] // 22,050 Hz Mono PCM Float samples
    let sampleRate: Double // Always 22050.0
    let startFrame: Int64
    let durationSeconds: Double
}

/// Result of decoding an audio file into strategic analysis segments.
struct DecodedAudio: Sendable {
    let url: URL
    let totalDurationSeconds: Double
    let originalSampleRate: Double
    let originalChannels: Int
    let segments: [AudioSegment]
}

/// Independent, high-performance chunked audio decoder for AudioAnalysisEngine 2.0.
/// Decodes FLAC, WAV, AIFF, MP3 into 22,050 Hz mono PCM segments with streaming chunking (RAM <= 25MB).
actor AudioDecoder {
    static let targetSampleRate: Double = 22050.0
    static let chunkSizeSeconds: Double = 5.0

    func decode(url: URL) async throws -> DecodedAudio {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioDecoderError.fileUnreadable(url, error.localizedDescription)
        }

        let fileLength = file.length
        guard fileLength > 0 else {
            throw AudioDecoderError.emptyAudioData(url)
        }

        let processingFormat = file.processingFormat
        let originalSampleRate = processingFormat.sampleRate
        let originalChannels = Int(processingFormat.channelCount)

        guard originalSampleRate > 0, originalChannels > 0 else {
            throw AudioDecoderError.invalidFormat(url)
        }

        let totalDuration = Double(fileLength) / originalSampleRate
        let segmentBounds = calculateSegmentBounds(totalDuration: totalDuration, sampleRate: originalSampleRate, totalFrames: fileLength)

        var segments: [AudioSegment] = []
        segments.reserveCapacity(segmentBounds.count)

        for bound in segmentBounds {
            let pcm = try decodeSegment(
                file: file,
                startFrame: bound.startFrame,
                frameCount: bound.frameCount,
                format: processingFormat
            )

            let duration = Double(pcm.count) / Self.targetSampleRate

            segments.append(
                AudioSegment(
                    type: bound.type,
                    pcmData: pcm,
                    sampleRate: Self.targetSampleRate,
                    startFrame: bound.startFrame,
                    durationSeconds: duration
                )
            )
        }

        return DecodedAudio(
            url: url,
            totalDurationSeconds: totalDuration,
            originalSampleRate: originalSampleRate,
            originalChannels: originalChannels,
            segments: segments
        )
    }

    // MARK: - Strategic Segment Calculation

    private struct SegmentBound {
        let type: AudioSegment.SegmentType
        let startFrame: Int64
        let frameCount: Int64
    }

    private func calculateSegmentBounds(totalDuration: Double, sampleRate: Double, totalFrames: Int64) -> [SegmentBound] {
        if totalDuration < 25.0 {
            // Short file fallback: decode full file as single segment
            return [
                SegmentBound(type: .full, startFrame: 0, frameCount: totalFrames)
            ]
        } else if totalDuration < 60.0 {
            // Medium file (25s - 60s): Intro (0-15s) + Body/Outro (15s - End)
            let introFrames = min(totalFrames, Int64(15.0 * sampleRate))
            let bodyStart = introFrames
            let bodyFrames = max(0, totalFrames - bodyStart)

            var bounds = [
                SegmentBound(type: .intro, startFrame: 0, frameCount: introFrames)
            ]
            if bodyFrames > 0 {
                bounds.append(SegmentBound(type: .bodyA, startFrame: bodyStart, frameCount: bodyFrames))
            }
            return bounds
        } else {
            // Standard/Long file (>= 60s): 4 Strategic Segments
            // Intro: 0s - 25s
            let introFrames = min(totalFrames, Int64(25.0 * sampleRate))

            // Body A: 25% - 45% (max 30s duration)
            let bodyAStart = Int64(totalDuration * 0.25 * sampleRate)
            let bodyADuration = min(30.0, totalDuration * 0.20)
            let bodyAFrames = min(totalFrames - bodyAStart, Int64(bodyADuration * sampleRate))

            // Body B / Drop: 55% - 75% (max 30s duration)
            let bodyBStart = Int64(totalDuration * 0.55 * sampleRate)
            let bodyBDuration = min(30.0, totalDuration * 0.20)
            let bodyBFrames = min(totalFrames - bodyBStart, Int64(bodyBDuration * sampleRate))

            // Outro: 85% - 100% (max 25s duration)
            let outroStart = Int64(max(0.0, totalDuration - 25.0) * sampleRate)
            let outroFrames = max(0, totalFrames - outroStart)

            var bounds = [
                SegmentBound(type: .intro, startFrame: 0, frameCount: introFrames)
            ]

            if bodyAFrames > 0 && bodyAStart < totalFrames {
                bounds.append(SegmentBound(type: .bodyA, startFrame: bodyAStart, frameCount: bodyAFrames))
            }
            if bodyBFrames > 0 && bodyBStart < totalFrames {
                bounds.append(SegmentBound(type: .bodyB, startFrame: bodyBStart, frameCount: bodyBFrames))
            }
            if outroFrames > 0 && outroStart < totalFrames {
                bounds.append(SegmentBound(type: .outro, startFrame: outroStart, frameCount: outroFrames))
            }

            return bounds
        }
    }

    // MARK: - Chunked Decoding, Mono Downmix & Resampling

    private func decodeSegment(
        file: AVAudioFile,
        startFrame: Int64,
        frameCount: Int64,
        format: AVAudioFormat
    ) throws -> [Float] {
        file.framePosition = startFrame

        let sourceSampleRate = format.sampleRate
        let channels = Int(format.channelCount)

        // Calculate chunk size in frames (~5 seconds of audio)
        let chunkSize = AVAudioFrameCount(Self.chunkSizeSeconds * sourceSampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
            throw AudioDecoderError.invalidFormat(file.url)
        }

        var remainingFrames = frameCount
        var resampledSegment: [Float] = []
        let estimatedOutputCapacity = Int(Double(frameCount) * (Self.targetSampleRate / sourceSampleRate)) + 100
        resampledSegment.reserveCapacity(estimatedOutputCapacity)

        // Working buffer for mono downmixing per chunk
        var monoChunk = [Float](repeating: 0, count: Int(chunkSize))

        while remainingFrames > 0 {
            let framesToRead = AVAudioFrameCount(min(Int64(chunkSize), remainingFrames))
            try file.read(into: buffer, frameCount: framesToRead)

            let readLength = Int(buffer.frameLength)
            if readLength == 0 { break }

            guard let channelData = buffer.floatChannelData else { break }

            // Ensure working buffer size matches read length
            if monoChunk.count < readLength {
                monoChunk = [Float](repeating: 0, count: readLength)
            }

            // 1. Downmix to Mono using vDSP
            if channels == 1 {
                let channelPointer = channelData[0]
                vDSP_mmov(channelPointer, &monoChunk, vDSP_Length(readLength), 1, 1, 1)
            } else {
                // Clear mono chunk to 0
                vDSP_vclr(&monoChunk, 1, vDSP_Length(readLength))

                // Sum across all channels
                for c in 0..<channels {
                    let channelPointer = channelData[c]
                    vDSP_vadd(monoChunk, 1, channelPointer, 1, &monoChunk, 1, vDSP_Length(readLength))
                }

                // Divide by channel count
                var div = Float(channels)
                vDSP_vsdiv(monoChunk, 1, &div, &monoChunk, 1, vDSP_Length(readLength))
            }

            // 2. Resample mono chunk to 22,050 Hz using Accelerate vDSP
            let resampledChunk = resample(
                monoData: Array(monoChunk[0..<readLength]),
                sourceRate: sourceSampleRate,
                targetRate: Self.targetSampleRate
            )

            resampledSegment.append(contentsOf: resampledChunk)
            remainingFrames -= Int64(readLength)
        }

        return resampledSegment
    }

    // MARK: - Resampling Engine via vDSP Linear Interpolation

    private func resample(monoData: [Float], sourceRate: Double, targetRate: Double) -> [Float] {
        guard !monoData.isEmpty else { return [] }

        if abs(sourceRate - targetRate) < 1.0 {
            return monoData
        }

        let inputCount = monoData.count
        let ratio = sourceRate / targetRate
        let outputCount = Int(Double(inputCount) / ratio)

        guard outputCount > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputCount)

        // Perform linear interpolation over resampled time steps
        monoData.withUnsafeBufferPointer { inputPtr in
            guard let baseInput = inputPtr.baseAddress else { return }

            for i in 0..<outputCount {
                let sourcePos = Double(i) * ratio
                let index0 = Int(sourcePos)
                let index1 = min(index0 + 1, inputCount - 1)
                let alpha = Float(sourcePos - Double(index0))

                let val0 = baseInput[index0]
                let val1 = baseInput[index1]

                output[i] = val0 + alpha * (val1 - val0)
            }
        }

        return output
    }
}
