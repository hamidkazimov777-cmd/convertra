import Foundation

/// Real Audio Benchmark Runner for AudioAnalysisEngine 2.0.
/// Analyzes physical audio files on disk (MP3, FLAC, WAV, AIFF) through the complete engine pipeline:
/// AudioDecoder -> SignalPreprocessor (HPSS) -> TempoDetector -> KeyDetector -> CamelotMapper.
/// Evaluates accuracy against ground-truth dataset and third-party software exports (Mixed In Key, rekordbox, Lexicon).
actor RealAudioBenchmarkRunner {
    private let decoder = AudioDecoder()
    private let preprocessor = SignalPreprocessor()
    private let tempoDetector = TempoDetector()
    private let keyDetector = KeyDetector()
    private let segmentFusion = SegmentFusion()

    /// Runs real-audio benchmark over a dataset JSON specification file.
    func runBenchmark(datasetURL: URL) async throws -> RealBenchmarkReport {
        guard FileManager.default.fileExists(atPath: datasetURL.path) else {
            return makeEmptyReport(summaryNote: "Real-world accuracy is not yet verified. Benchmark dataset JSON file not found at '\(datasetURL.path)'.")
        }

        let datasetData = try Data(contentsOf: datasetURL)
        let decoder = JSONDecoder()
        let dataset: RealBenchmarkDataset
        do {
            dataset = try decoder.decode(RealBenchmarkDataset.self, from: datasetData)
        } catch {
            return makeEmptyReport(summaryNote: "Real-world accuracy is not yet verified. Failed to parse benchmark dataset JSON: \(error.localizedDescription)")
        }

        guard !dataset.tracks.isEmpty else {
            return makeEmptyReport(summaryNote: "Real-world accuracy is not yet verified. Dataset contains 0 track entries.")
        }

        var totalTracks = 0
        var processedTracks = 0
        var skippedMissingFiles = 0
        var skippedMissingReference = 0

        var bpmExactMatches = 0 // +/- 0.1
        var bpmTolerantMatches = 0 // +/- 0.5
        var bpmOctaveErrors = 0
        var totalBPMErrorSum: Double = 0.0

        var exactCamelotMatches = 0
        var harmonicCamelotMatches = 0
        var relativeErrors = 0
        var fifthErrors = 0
        var criticalErrors = 0

        var bpmConfidenceSum: Double = 0.0
        var keyConfidenceSum: Double = 0.0
        var realtimeFactorSum: Double = 0.0

        var discrepancies: [DiscrepancyEntry] = []

        for track in dataset.tracks {
            totalTracks += 1

            let fileURL = URL(fileURLWithPath: track.filePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                skippedMissingFiles += 1
                continue
            }

            // Determine ground truth reference values
            let targetBPM = track.groundTruthBPM ?? track.mixedInKey?.bpm ?? track.rekordbox?.bpm ?? track.lexicon?.bpm
            let targetCamelotStr = track.groundTruthCamelotKey ?? track.mixedInKey?.camelotKey ?? track.rekordbox?.camelotKey ?? track.lexicon?.camelotKey

            guard let truthBPM = targetBPM, let truthCamelotStr = targetCamelotStr else {
                skippedMissingReference += 1
                continue
            }

            // 1. Run AudioDecoder (Streaming chunked decoding)
            let tStart = Date()
            let decoded: DecodedAudio
            do {
                decoded = try await self.decoder.decode(url: fileURL)
            } catch {
                skippedMissingFiles += 1
                continue
            }
            let tDecode = Date().timeIntervalSince(tStart)

            // Analyze strategic Body B or Intro segment
            guard let primarySegment = decoded.segments.first(where: { $0.type == .bodyB }) ?? decoded.segments.first else {
                skippedMissingFiles += 1
                continue
            }

            // 2. Run SignalPreprocessor (HPSS)
            let tHPSSStart = Date()
            let preprocessed = await preprocessor.process(segment: primarySegment)
            let tHPSS = Date().timeIntervalSince(tHPSSStart)

            // 3. Run TempoDetector
            let tTempoStart = Date()
            let tempoResult = await tempoDetector.detectTempo(pcm: preprocessed.percussivePCM)
            let tTempo = Date().timeIntervalSince(tTempoStart)

            // 4. Run KeyDetector
            let tKeyStart = Date()
            let keyResult = await keyDetector.detectKey(pcm: preprocessed.harmonicPCM)
            let tKey = Date().timeIntervalSince(tKeyStart)

            let tTotal = Date().timeIntervalSince(tStart)
            let realtimeFactor = tTotal > 0 ? (primarySegment.durationSeconds / tTotal) : 0.0

            processedTracks += 1
            bpmConfidenceSum += tempoResult.confidence
            keyConfidenceSum += keyResult.confidence
            realtimeFactorSum += realtimeFactor

            let detectedBPM = tempoResult.bpm
            let detectedCamelotStr = keyResult.camelotKey.code

            // Evaluate BPM
            let bpmDiff = abs(detectedBPM - truthBPM)
            totalBPMErrorSum += bpmDiff

            var isOctaveError = false
            if bpmDiff <= 0.1 {
                bpmExactMatches += 1
                bpmTolerantMatches += 1
            } else if bpmDiff <= 0.5 {
                bpmTolerantMatches += 1
            } else if abs(detectedBPM * 2.0 - truthBPM) < 1.0 || abs(detectedBPM * 0.5 - truthBPM) < 1.0 {
                bpmOctaveErrors += 1
                isOctaveError = true
            }

            // Evaluate Key
            let errorCategory: KeyErrorCategory
            if detectedCamelotStr == truthCamelotStr {
                exactCamelotMatches += 1
                harmonicCamelotMatches += 1
                errorCategory = .exactMatch
            } else if let detCamelot = CamelotKey(code: detectedCamelotStr),
                       let truthCamelot = CamelotKey(code: truthCamelotStr) {
                if detCamelot.isHarmonicallyCompatible(with: truthCamelot) {
                    harmonicCamelotMatches += 1
                    if detCamelot.number == truthCamelot.number {
                        relativeErrors += 1
                        errorCategory = .relativeError
                    } else {
                        fifthErrors += 1
                        errorCategory = .fifthError
                    }
                } else if detCamelot.number == truthCamelot.number {
                    errorCategory = .parallelError
                } else {
                    criticalErrors += 1
                    errorCategory = .badKeyError
                }
            } else {
                criticalErrors += 1
                errorCategory = .badKeyError
            }

            // Log discrepancy if not exact match
            if bpmDiff > 0.5 || detectedCamelotStr != truthCamelotStr {
                discrepancies.append(
                    DiscrepancyEntry(
                        trackID: track.id,
                        fileName: track.fileName,
                        genre: track.genre ?? "Unknown",
                        referenceBPM: truthBPM,
                        convertraBPM: detectedBPM,
                        bpmError: bpmDiff,
                        referenceCamelot: truthCamelotStr,
                        convertraCamelot: detectedCamelotStr,
                        confidence: keyResult.confidence,
                        errorCategory: errorCategory,
                        isBPMOctaveError: isOctaveError
                    )
                )
            }
        }

        guard processedTracks > 0 else {
            return makeEmptyReport(summaryNote: "Real-world accuracy is not yet verified. Processed 0 physical audio files.")
        }

        let countDouble = Double(processedTracks)
        let bpmExactPct = (Double(bpmExactMatches) / countDouble) * 100.0
        let bpmTolerantPct = (Double(bpmTolerantMatches) / countDouble) * 100.0
        let octaveErrorPct = (Double(bpmOctaveErrors) / countDouble) * 100.0
        let meanBPMError = totalBPMErrorSum / countDouble

        let exactKeyPct = (Double(exactCamelotMatches) / countDouble) * 100.0
        let harmonicKeyPct = (Double(harmonicCamelotMatches) / countDouble) * 100.0
        let relativePct = (Double(relativeErrors) / countDouble) * 100.0
        let fifthPct = (Double(fifthErrors) / countDouble) * 100.0
        let criticalPct = (Double(criticalErrors) / countDouble) * 100.0

        let avgBPMConf = bpmConfidenceSum / countDouble
        let avgKeyConf = keyConfidenceSum / countDouble
        let avgRealtime = realtimeFactorSum / countDouble

        return RealBenchmarkReport(
            datasetVersion: dataset.version,
            category: .realData,
            totalTracksInDataset: totalTracks,
            processedTracksCount: processedTracks,
            skippedMissingFilesCount: skippedMissingFiles,
            skippedMissingReferenceCount: skippedMissingReference,
            bpmExactAccuracyPct: bpmExactPct,
            bpmTolerantAccuracyPct: bpmTolerantPct,
            bpmOctaveErrorRatePct: octaveErrorPct,
            bpmMeanAbsoluteError: meanBPMError,
            keyExactMatchPct: exactKeyPct,
            keyHarmonicMatchPct: harmonicKeyPct,
            keyRelativeErrorPct: relativePct,
            keyFifthErrorPct: fifthPct,
            keyCriticalErrorPct: criticalPct,
            averageBPMConfidence: avgBPMConf,
            averageKeyConfidence: avgKeyConf,
            averageRealtimeFactor: avgRealtime,
            discrepancies: discrepancies,
            summaryNote: "Real-world audio benchmark completed across \(processedTracks) physical files."
        )
    }

    private func makeEmptyReport(summaryNote: String) -> RealBenchmarkReport {
        RealBenchmarkReport(
            datasetVersion: "1.0",
            category: .unverifiedData,
            totalTracksInDataset: 0,
            processedTracksCount: 0,
            skippedMissingFilesCount: 0,
            skippedMissingReferenceCount: 0,
            bpmExactAccuracyPct: 0.0,
            bpmTolerantAccuracyPct: 0.0,
            bpmOctaveErrorRatePct: 0.0,
            bpmMeanAbsoluteError: 0.0,
            keyExactMatchPct: 0.0,
            keyHarmonicMatchPct: 0.0,
            keyRelativeErrorPct: 0.0,
            keyFifthErrorPct: 0.0,
            keyCriticalErrorPct: 0.0,
            averageBPMConfidence: 0.0,
            averageKeyConfidence: 0.0,
            averageRealtimeFactor: 0.0,
            discrepancies: [],
            summaryNote: summaryNote
        )
    }
}
