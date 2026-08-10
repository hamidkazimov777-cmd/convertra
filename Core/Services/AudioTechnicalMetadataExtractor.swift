import AudioToolbox
import AVFoundation
import CoreMedia
import Foundation

struct AudioTechnicalMetadataResult: Sendable {
    let url: URL
    let analysis: AudioAnalysis?
}

/// Reads technical stream properties using AVFoundation. It intentionally does
/// not perform BPM/key analysis or mutate media-file metadata.
actor AudioTechnicalMetadataExtractor {
    private let engine2 = AudioAnalysisEngine2()
    private let legacyAnalyzer = AudioAnalyzerEngine()
    
    func analyze(urls: [URL]) async -> [AudioTechnicalMetadataResult] {
        var results: [AudioTechnicalMetadataResult] = []
        results.reserveCapacity(urls.count)

        for url in urls {
            results.append(await analyze(url: url))
        }

        return results
    }

    private func analyze(url: URL) async -> AudioTechnicalMetadataResult {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                return AudioTechnicalMetadataResult(url: url, analysis: nil)
            }

            let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            let formatDescription = formatDescriptions.first
            let streamDescription = formatDescription.flatMap(CMAudioFormatDescriptionGetStreamBasicDescription)

            let durationSeconds = CMTimeGetSeconds(duration)
            let validDuration = durationSeconds.isFinite && durationSeconds >= 0 ? durationSeconds : 0
            let bitrate = estimatedDataRate > 0 ? Int(estimatedDataRate.rounded()) : nil
            let sampleRate = streamDescription?.pointee.mSampleRate
            let channels = streamDescription.map { Int($0.pointee.mChannelsPerFrame) }
            let detectedCodec = codec(for: url, formatDescription: formatDescription)
            
            // Primary path: AudioAnalysisEngine2
            let analysis: AudioAnalysis
            if let result2 = try? await engine2.analyze(url: url) {
                analysis = AudioAnalysis2Adapter.adapt(
                    result: result2,
                    bitrate: bitrate,
                    sampleRate: sampleRate,
                    channels: channels,
                    codec: detectedCodec
                )
            } else if let legacyAnalysis = try? await legacyAnalyzer.analyze(url: url) {
                // Fallback path: Legacy AudioAnalyzerEngine
                analysis = AudioAnalysis(
                    bpm: legacyAnalysis.bpm.map { Double($0) },
                    musicalKey: legacyAnalysis.key.flatMap { MusicalKey(rawValue: $0) },
                    duration: validDuration,
                    bitrate: bitrate,
                    sampleRate: sampleRate,
                    channels: channels,
                    codec: detectedCodec
                )
            } else {
                analysis = AudioAnalysis(
                    duration: validDuration,
                    bitrate: bitrate,
                    sampleRate: sampleRate,
                    channels: channels,
                    codec: detectedCodec
                )
            }

            return AudioTechnicalMetadataResult(url: url, analysis: analysis)
        } catch {
            return AudioTechnicalMetadataResult(url: url, analysis: nil)
        }
    }

    private func codec(for url: URL, formatDescription: CMFormatDescription?) -> AudioCodec {
        guard let formatDescription else {
            return codecFromFileExtension(url)
        }

        switch CMFormatDescriptionGetMediaSubType(formatDescription) {
        case kAudioFormatMPEG4AAC:
            return .aac
        case kAudioFormatAppleLossless:
            return .alac
        case kAudioFormatMPEGLayer3:
            return .mp3
        case kAudioFormatFLAC:
            return .flac
        case kAudioFormatLinearPCM:
            return codecFromFileExtension(url)
        default:
            return codecFromFileExtension(url)
        }
    }

    private func codecFromFileExtension(_ url: URL) -> AudioCodec {
        switch url.pathExtension.lowercased() {
        case "wav", "wave": return .wav
        case "aif", "aiff": return .aiff
        case "flac": return .flac
        case "alac": return .alac
        case "mp3": return .mp3
        case "aac": return .aac
        case "m4a": return .m4a
        default: return .unknown
        }
    }
}
