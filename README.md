# Convertra

**A native macOS audio-library utility for DJs and music professionals.**

Convertra is a SwiftUI application for collecting, inspecting, organizing, and eventually converting large audio libraries. It is designed around a responsive, macOS-native workflow—without Electron, web views, or third-party runtime dependencies.

> **Status:** active MVP development. Library ingestion is implemented; technical audio analysis, metadata editing, playback, and conversion are the next milestones.

## Why Convertra

DJs and music-library managers need reliable utilities that can handle deeply nested folders and large collections without interrupting their workflow. Convertra focuses on a native, asynchronous foundation for that job:

- Scan dropped files and folders recursively.
- Keep filesystem traversal away from the main thread.
- Prepare each track for technical analysis, metadata editing, playback, and batch conversion.
- Target both Intel and Apple Silicon Macs running macOS Monterey or newer.

## Current capabilities

### Implemented

- Native SwiftUI macOS app shell with Library, Conversion, Metadata, and Player areas.
- Finder file and folder selection.
- Drag-and-drop ingestion for files and folders.
- Recursive discovery of WAV, AIFF, FLAC, ALAC, MP3, AAC, and M4A files.
- Background library scanning through an isolated Swift actor.
- Duplicate-path filtering and a live library list.
- AVFoundation-backed duration, bitrate, sample-rate, channel-count, and codec extraction.
- Unit coverage for recursive discovery, technical metadata extraction, and the default MP3 conversion settings.

### Planned

- BPM and musical-key analysis.
- Batch metadata editing, cover artwork, and persistence.
- Built-in player with seeking, volume, and waveform preview.
- Lossless-to-MP3 batch conversion with metadata and folder-structure preservation.

## Engineering highlights

- **Native by design:** Swift + SwiftUI; AppKit is reserved for macOS-specific gaps.
- **Performance-aware:** file traversal runs in `AudioLibraryScanner`, an actor outside the UI layer.
- **Permission-aware:** selected locations receive security-scoped access only for the duration of scanning.
- **Dependency-free foundation:** no third-party packages, FFmpeg, Homebrew packages, Electron, or web wrappers.
- **Broad platform support:** macOS 12.0+, Intel (`x86_64`) and Apple Silicon.

## Architecture

```text
App/                    SwiftUI application entry point and app state
Features/
  Library/              Library presentation and drag-and-drop workflow
  Analysis/             Reserved for audio-analysis UI
  Metadata/             Reserved for metadata-editing UI
  Conversion/           Reserved for conversion UI
  Player/               Reserved for playback UI
Core/
  Audio/                Supported-format definitions and audio primitives
  Models/               Audio file, metadata, analysis, and conversion models
  Services/             Background services, including recursive library scanning
Tests/                  Unit tests
handoff/HANDOFF.md      Continuity record for project state and next work
```

## Requirements

- macOS Monterey 12.0 or later
- Xcode 15.2 (or a compatible Xcode release)
- Swift 5.9+

## Build and test

```bash
git clone https://github.com/hamidkazimov777-cmd/convertra.git
cd convertra
swift build
swift test
```

Open `Package.swift` in Xcode to run the native SwiftUI app.

## Development status

The current milestone establishes reliable ingestion and technical inspection. The immediate next task is a more capable Library UI: sortable columns, search, selection, and clearer processing feedback.

For a detailed change log, design decisions, known limitations, and the next recommended task, see [handoff/HANDOFF.md](handoff/HANDOFF.md).

## Contact

Built by Hamid Kazimov. For professional inquiries or collaboration, contact [@hamidkazim on Telegram](https://t.me/hamidkazim).
