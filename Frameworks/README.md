# Convertra AudioCore

This directory contains `ConvertraAudioCore.xcframework` — a compiled, universal
(Apple Silicon + Intel) binary framework exposing Convertra's proprietary key
and tempo detection engines to the rest of the app.

## Why binary, not source

Convertra AudioCore is Convertra's core technology and competitive differentiator.
The rest of this repository — UI, library management, metadata editing, audio
conversion, and the thin adapter layer that calls into AudioCore — is
source-available. The DSP internals (chroma extraction, tuning correction,
key-profile correlation, onset detection, autocorrelation periodicity search,
and the tuned constants behind them) are not, and are distributed only as this
compiled artifact.

## Public API surface

The framework exposes exactly two actors and their result types — nothing else
is part of the public contract:

```swift
import ConvertraAudioCore

let keyEngine = ConvertraKeyEngine()
let keyResult = await keyEngine.detectKey(pcm: pcmFloatSamplesAt22050Hz)
// keyResult.camelotNumber (1...12), .isMinor, .confidence, .candidates

let tempoEngine = ConvertraTempoEngine()
let tempoResult = await tempoEngine.detectTempo(pcm: pcmFloatSamplesAt22050Hz)
// tempoResult.bpm, .confidence, .candidates
```

Both engines expect mono `Float` PCM at 22,050 Hz (see `ConvertraKeyEngine.sampleRate`
/ `ConvertraTempoEngine.sampleRate`). `Core/Services/Analysis/KeyDetector.swift`
and `TempoDetector.swift` in this repo are the thin, fully-open adapters that
convert between this DTO surface and the app's internal types — read those to
see exactly how AudioCore is wired into `AudioAnalysisEngine2`.

## Licensing

Convertra AudioCore is available for commercial licensing — as an SDK for
another DJ/library app, white-label integration, or outright acquisition of the
technology. The accuracy numbers in the main [README](../README.md) are measured
against real Mixed In Key ground truth, reproducibly, and the methodology is
documented in [HANDOFF.md](../HANDOFF.md).

For licensing or technical due-diligence inquiries, contact
[@hamidkazim on Telegram](https://t.me/hamidkazim).
