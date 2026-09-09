# Convertra

Native macOS app that analyses a DJ library — musical key (Camelot) and BPM —
entirely on-device, with no cloud service and no neural network.

Built in Swift on Apple's native frameworks (SwiftUI, AVFoundation, CoreData)
rather than a web view wrapped in Electron. Key and tempo detection run through
`ConvertraAudioCore`, a closed-source DSP framework, over Apple's `Accelerate`
and `vDSP`.

## The problem it solves

DJs tag their libraries with tools like rekordbox, Serato or Mixed In Key to get
a musical key and BPM for every track, so sets can be beat- and harmonically
mixed. Convertra does that analysis locally: drop a folder in, get Camelot keys
and tempos written back to the files, without uploading anything or paying a
subscription.

## Accuracy

Measured against ground-truth tags from a private set of 111 commercial tracks
(house, tech-house, hip-hop, pop). The tracks are commercial recordings and are
not redistributable, so the set itself is not in the repository; the harness,
schema and methodology that produced these numbers are — see
[`benchmark/`](benchmark/).

| Metric | Result |
| --- | --- |
| Key — exact Camelot match | ~70% |
| Key — harmonically compatible match | ~83% |
| Tempo — within ±0.5 BPM | ~82% |
| Analysis time per track (Apple Silicon) | ~1 s |

"Harmonically compatible" means the detected key is the same Camelot number or
an adjacent one — a mix-safe neighbour on the wheel — rather than an exact hit.
It is reported separately because a neighbour is usable in a set and an exact
match is not always necessary.

## Technical notes

- **On-device DSP.** The pipeline is decode → HPSS pre-separation →
  tempo detection → key detection → Camelot mapping. Key detection uses harmonic
  pitch-class profiling with peak-picking; tempo uses autocorrelation with
  parabolic interpolation for sub-BPM resolution. No network, no model download.
- **Closed engine, open orchestration.** The heavy DSP lives in the
  `ConvertraAudioCore.xcframework` binary; the ~9k lines of Swift in this repo
  (`Core/Services/Analysis`, metadata, persistence, playback, UI) orchestrate it
  and are open to read.
- **Concurrency.** Library scanning is actor-based; tempo and key detection run
  concurrently per track.
- **Single-pass decode.** Audio is decoded once through `AVAssetReader` straight
  into vDSP buffers, so a track is not read from disk more than necessary.
- **Native metadata.** ID3v2 tag and cover-art writing for MP3 and AIFF is done
  natively, not shelled out.
- **Sandbox compliance.** Security-scoped resource handling for App Sandbox
  constraints.

## Stack

Swift · SwiftUI · AVFoundation · CoreData/SQLite · Accelerate/vDSP · FFmpeg
(batch conversion) · `ConvertraAudioCore.xcframework` (closed-source DSP)

## Build and test

```bash
git clone https://github.com/hamidkazimov777-cmd/convertra.git
cd convertra

swift test          # 59 unit tests across 20 files
./package_app.sh    # build and locally sign Convertra.app
```

Requires macOS 12.0+ and Xcode 15.2+.

## Known limitations

- The 111-track benchmark set is private (commercial audio), so the headline
  accuracy numbers are reproducible only with your own labelled tracks; the
  harness in [`benchmark/`](benchmark/) makes that path explicit.
- `ConvertraAudioCore` ships as a pre-compiled binary; its DSP internals are not
  open. The Swift layer that drives it is.
- Accuracy is highest on 4/4 electronic material with a clear tonal centre;
  ambient, heavily atonal, or beatless tracks are weaker for both key and tempo.
- macOS only. The engine is built for Apple Silicon and Intel; there is no
  Windows or Linux target.

## Licence

Source-available, all rights reserved — see [LICENSE](LICENSE). The
`ConvertraAudioCore` engine is a closed-source binary; contact me about OEM
licensing if you need a drop-in key/BPM DSP engine.

Built by Hamid Kazimov — [Telegram](https://t.me/hamidkazim).
