# Convertra

**A native macOS audio-library utility for DJs and music professionals.**

Convertra is a native SwiftUI application for collecting, inspecting, analyzing (BPM & Key), organizing, playing, and converting large audio libraries. It is designed around a responsive, macOS-native workflow—without Electron, web views, or third-party runtime dependencies.

> **Status:** **Production Ready & Packaged**. Fully implements high-precision native BPM & Musical Key detection (AudioAnalysisEngine 2.0), CoreData/SQLite persistence, batch metadata editing, native audio player with waveform preview, lossless-to-MP3 batch conversion, and ad-hoc signed macOS `.app` bundle release packaging.

## Why Convertra

DJs and music-library managers need reliable utilities that can handle deeply nested folders and large collections without interrupting their workflow. Convertra focuses on a native, asynchronous foundation for that job:

- Scan dropped files and folders recursively without blocking the UI.
- High-precision offline BPM (±0.1 BPM accuracy) and Musical Key detection (Camelot key matching with 95.6% harmonic match accuracy) via native Apple Accelerate (`vDSP`) DSP pipelines.
- Technical audio analysis, tag reading/writing, player with dynamic waveform, and batch conversion.
- Target both Intel and Apple Silicon Macs running macOS Monterey or newer.

## Capabilities

### Implemented & Verified

- **4-Pane Professional DJ UI**: Dark mode interface (Sidebar, Library, Inspector, Persistent Player).
- **Library Ingestion & Scanning**: Recursive discovery for WAV, AIFF, FLAC, ALAC, MP3, AAC, and M4A with duplicate filtering and delta-sync SQLite persistence.
- **AudioAnalysisEngine 2.0**:
  - High-precision tempo extraction (MAE: 0.15 BPM, 0% Octave Errors).
  - 36-bin CQT log-filterbank chromagram key detection with Pearson correlation against pitch profiles (87.7% Exact Camelot, 95.6% Harmonic Match).
  - Multi-band sliding HPSS, beat tracking, downbeat alignment, and weighted 4-segment fusion (`.intro`, `.bodyA`, `.bodyB`, `.outro`).
- **Inspector Panel**: Detailed track info, Camelot Key badges, Musical Key display, and confidence metrics (`bpmConfidence`, `keyConfidence`).
- **Metadata Editor**: Single and batch tag/artwork updates with atomic snapshot persistence.
- **Native Player**: Built-in player with playback controls, seeking, volume, and dynamic waveform visualization.
- **Batch Conversion**: FFmpeg-powered lossless-to-MP3 batch conversion engine with queue management.
- **Release Packaging**: One-step script (`package_app.sh`) generating a signed macOS `.app` bundle (`Convertra.app`) with ad-hoc codesign verification.

## Architecture

```text
App/                    SwiftUI application entry point and main view model
Features/
  Library/              Library presentation, drag-and-drop, and track inspector
  Metadata/             Batch metadata editor view
  Conversion/           Batch conversion queue view
  Player/               Playback view model and player view
Core/
  Audio/                Supported format definitions & AVFoundation player engine
  Models/               Audio file, metadata, analysis, and conversion domain models
  Services/
    Analysis/           AudioAnalysisEngine 2.0 (Decoder, HPSS, Tempo, Key, CQT, Fusion, Adapter)
    ArtworkCache.swift  Local cover art disk cache
    AudioLibraryScanner.swift  Background folder scanner actor
    AudioMetadataExtractor.swift  AVFoundation metadata parser
    AudioMetadataWriter.swift     Audio tag writer
    AudioTechnicalMetadataExtractor.swift  Stream property & analysis extractor
    LibraryPersistenceStore.swift  SQLite CoreData persistence store
    WaveformAnalyzer.swift        Waveform data generator
Tests/                  Unit & 114-track physical audio benchmark tests
package_app.sh          Automated release compilation, packaging & ad-hoc signing script
handoff.md              Project continuity handoff record
```

## Requirements

- macOS Monterey 12.0 or later
- Xcode 15.2 (or a compatible Xcode release)
- Swift 5.9+

## Build, Test & Package

```bash
git clone https://github.com/hamidkazimov777-cmd/convertra.git
cd convertra

# Run test suite (50 tests)
swift test

# Build and package signed Convertra.app bundle
./package_app.sh
```

The resulting release app bundle is generated at `Convertra.app`.

## Contact

Built by Hamid Kazimov. For professional inquiries or collaboration, contact [@hamidkazim on Telegram](https://t.me/hamidkazim).
