# Convertra

## Product description

Convertra is a native macOS audio-library and conversion application for DJs and music professionals.

It provides a macOS-native workflow for:
- audio library ingestion and organization;
- technical audio analysis;
- metadata inspection and editing;
- audio playback;
- lossless-to-MP3 conversion.

## Current status

Convertra is production-ready. The core workflows for library management, audio analysis, metadata editing, playback, and batch conversion are fully implemented and operational.

## Convertra AudioCore

**Convertra AudioCore** is the proprietary local audio-analysis technology used by the production application. It is implemented internally through the current `AudioAnalysisEngine2` implementation.

The production analysis path is:
`AppViewModel.scanAndAdd()`
→ `AudioTechnicalMetadataExtractor.analyze()`
→ `AudioAnalysisEngine2.analyze()`
→ `AudioDecoder`
→ `SignalPreprocessor` (HPSS)
→ `TempoDetector`
→ `BeatTracker`
→ `PhaseAligner`
→ `DownbeatDetector`
→ `KeyDetector`
→ `SegmentFusion`
→ `AudioAnalysisResult2`
→ `AudioAnalysis2Adapter`
→ `AudioAnalysis`
→ `TrackListView` / `TrackInspectorView`

AudioCore provides:
- BPM / tempo detection
- beat tracking
- downbeat detection
- musical key detection
- Camelot key mapping
- segment-based analysis/fusion
- confidence scoring

The analysis is performed locally using Swift and Apple's AVFoundation, Accelerate, and vDSP technologies. The production audio-analysis path does NOT depend on external audio-analysis APIs, cloud analysis services, or third-party audio-analysis engines. It is a proprietary DSP-based audio-analysis engine, not a neural-network or AI system.

## Current capabilities

- **Native SwiftUI macOS application**: Built entirely with Swift and modern macOS frameworks.
- **File/folder selection & drag-and-drop ingestion**: Intuitive import workflows via native macOS panels and drop targets.
- **Recursive audio discovery**: Efficient scanning of deeply nested directories for supported audio formats.
- **Persistent library**: Delta-sync SQLite (CoreData) persistence ensuring fast loads and reliable metadata storage.
- **Technical metadata extraction**: Automatic reading of stream properties and tags.
- **Convertra AudioCore analysis**: High-precision local DSP analysis for BPM, Camelot keys, and beat grids.
- **Metadata inspection/editing**: Inspector panel for viewing and batch-updating track metadata.
- **Audio playback**: Native AVFoundation player with dynamic waveform visualization.
- **Lossless-to-MP3 conversion**: FFmpeg-powered batch conversion queue.

## Engineering highlights

- Native Swift + SwiftUI macOS application.
- Apple-native audio technologies (AVFoundation, Accelerate, vDSP).
- Local asynchronous processing.
- Actor-based/background library scanning.
- Security-scoped resource handling for robust sandbox compliance.
- Proprietary local DSP analysis through Convertra AudioCore.
- No Electron/web wrappers.
- No external audio-analysis service.
- Support for both Intel and Apple Silicon Macs.

*(Note: Batch conversion utilizes a bundled FFmpeg command runner, but the core analysis and playback pipelines are entirely native.)*

## Architecture

The repository is structured around a domain-driven feature architecture:

```text
App/                    Application lifecycle, main view models, and UI routing
Core/
  Audio/                Supported formats and audio player engines
  Models/               Domain models (AudioFile, AudioAnalysis, ConversionJob, etc.)
  Services/             Core business logic:
    Analysis/           Convertra AudioCore (AudioAnalysisEngine2 and DSP pipelines)
    AudioLibraryScanner Audio ingestion and discovery
    LibraryPersistence  CoreData / SQLite storage
    Metadata Extractors Metadata reading and writing
    ConversionEngine    Batch audio conversion handling
Features/
  Library/              Track list, drag-and-drop handling, and track inspector UI
  Metadata/             Metadata editor UI
  Conversion/           Conversion queue UI
  Player/               Player view model and waveform UI components
Tests/                  Unit tests, AudioCore benchmarks, and validation infrastructure
UI/                     Shared UI components, theming, layouts, and sidebars
Resources/              Asset catalogs and bundled resources
```

## Benchmark information

The Convertra AudioCore technology has been validated against a benchmark of 114 real commercial audio tracks. The existing benchmark results are:

- **Key Exact Camelot**: 87.7%
- **Key Harmonic Match**: 95.6%
- **Critical Bad Key Errors**: 4.4%
- **BPM Exact ±0.1**: 85.1%
- **BPM Tolerant ±0.5**: 95.6%
- **BPM MAE**: 0.15 BPM
- **Octave Errors**: 0%
- **Realtime Factor**: 145.2x

## Development status

The application has successfully reached its production release milestone. Core features including library ingestion, local DSP analysis (AudioCore), metadata editing, audio playback, and lossless conversion are complete and functionally verified. Development is currently focused on continuous refinement, bug fixes, and minor UI polishes.

## Documentation

For historical context and a detailed continuity record of the development process, refer to [HANDOFF.md](./HANDOFF.md). Please note that `HANDOFF.md` serves as a development record; this `README.md` and the source code itself remain the primary sources of truth for the current implementation status.

## Requirements

- macOS Monterey 12.0 or later
- Xcode 15.2 (or a compatible Xcode release)
- Swift 5.9+

## Build, Test & Package

```bash
git clone https://github.com/hamidkazimov777-cmd/convertra.git
cd convertra

# Run test suite
swift test

# Build and package signed Convertra.app bundle
./package_app.sh
```

The resulting release app bundle is generated at `Convertra.app`.

## Contact

Built by Hamid Kazimov. For professional inquiries or collaboration, contact [@hamidkazim on Telegram](https://t.me/hamidkazim).
