# Convertra Handoff

## Project Overview

Convertra is a new native macOS audio utility for DJs and music libraries. The dependency-free SwiftUI foundation is in place and targets macOS 12.0 or later on both Intel and Apple Silicon Macs. The local Apple development environment is installed, configured, and verified.

## Architecture

- Swift Package executable with a native SwiftUI `App` entry point.
- Feature folders are separated into Analysis, Metadata, Conversion, and Player.
- Library ingestion is isolated into a `Core/Services` scanner and a `Features/Library` view.
- Shared domain models live in `Core/Models`; future audio and service layers have dedicated folders.
- UI state is held in a main-actor `AppViewModel`; feature processing will be asynchronous and kept outside the UI layer.
- No external dependencies have been added.

## Completed Tasks

1. 2026-08-09 — Created the macOS 12+ Swift Package app foundation.
2. 2026-08-09 — Created the requested feature, core, resource, test, and handoff folder structure.
3. 2026-08-09 — Implemented the SwiftUI shell with navigation and importer entry points.
4. 2026-08-09 — Added audio file, metadata, analysis, codec, musical-key, and conversion-job models.
5. 2026-08-09 — Added a model test for the required MP3 320 kbps CBR conversion default.
6. 2026-08-09 — Reviewed model value conformance and corrected hashability required by library and conversion records.
7. 2026-08-09 — Inspected the Apple development environment and opened the official App Store listing for Xcode.
8. 2026-08-09 — Confirmed the development Mac runs macOS Ventura 13.7.8 on Intel hardware (MacBookPro14,1). Identified Xcode 15.2 as the current compatible Xcode release and opened Apple Developer Downloads for it.
9. 2026-08-10 — Installed Xcode 15.2 in `/Applications`, selected it as the active developer directory, and completed Apple’s Xcode first-launch setup.
10. 2026-08-10 — Verified `xcodebuild -version` (Xcode 15.2, build 15C500b), `swift --version` (Apple Swift 5.9.2), `swift build`, and `swift test` (1 test, 0 failures).
11. 2026-08-10 — Implemented initial library ingestion: file/folder selection, Finder drag-and-drop, recursive supported-format discovery, background scanning, deduplication, and a library list.
12. 2026-08-10 — Added scanner coverage for nested folders and supported-format filtering.
13. 2026-08-10 — Corrected the library-file construction and actor-isolated button actions found during the initial compiler check.
14. 2026-08-10 — Corrected the scanner test’s extension normalization call found during test compilation.
15. 2026-08-10 — Verified the library-ingestion implementation with `swift build` and `swift test`: 2 tests passed with 0 failures.
16. 2026-08-10 — Added minimal Git ignores for local SwiftPM, Xcode, and Finder build artifacts.
17. 2026-08-10 — Connected the local repository to `https://github.com/hamidkazimov777-cmd/convertra.git`; the remote was empty when checked.
18. 2026-08-10 — Created the initial local Git commit `f484f2d` (`Initial Convertra foundation and library ingestion`) containing the complete project foundation and library-ingestion work.

## Current State

The project is configured as a native SwiftUI macOS executable. It displays a sidebar for Library, Conversion, Metadata, and Player. Users can select or drag files and folders into Library; supported audio files are discovered recursively off the main actor and listed without duplicate paths. Core in-memory models exist, including the mandated 320 kbps CBR MP3 conversion settings. The project builds and its tests pass locally.

## Pending Tasks

- Implement AVFoundation-backed technical metadata extraction.
- Design and implement BPM and musical-key analysis.
- Implement library persistence and large-library background processing.
- Implement metadata reading, single/batch editing, artwork handling, and writing.
- Implement a conversion engine after selecting an approved encoding approach.
- Implement playback, seeking, volume, and waveform preview.
- Build production UI, error handling, accessibility, and broader test coverage.

## Technical Decisions

- Minimum deployment target: macOS 12.0.
- Development environment target: Xcode 15.2, which Apple supports on macOS Ventura 13.5 or later and is suitable for this Intel Mac running Ventura 13.7.8.
- UI framework: SwiftUI, with AppKit reserved only for platform gaps.
- Foundation uses no third-party libraries or downloaded assets.
- Source control remote: `origin` points to `hamidkazimov777-cmd/convertra` on GitHub. Generated build output remains ignored.
- Folder traversal uses `AudioLibraryScanner`, an actor. It requests security-scoped access only while scanning a user-selected URL and releases it immediately afterwards; persistent bookmark storage is deferred until library persistence exists.
- Conversion default is modeled as MP3 at 320 kbps CBR with metadata, artwork, and folder-structure preservation enabled.
- Artwork is modeled as a file location rather than retained image data, which protects memory usage for large libraries.

## Known Issues

- File import access is session-only. Chosen folders are not persisted across relaunches until security-scoped bookmark persistence is implemented.
- No audio analysis, metadata persistence/editing, conversion, or playback is implemented yet.
- Swift Package development setup is not a signed/distributable `.app` bundle yet.

## Next Recommended Step

Implement AVFoundation-backed extraction of duration, bitrate, sample rate, channels, and codec for imported tracks.
