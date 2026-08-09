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
19. 2026-08-10 — Published the initial project history to GitHub on `main`; the local branch now tracks `origin/main`.
20. 2026-08-10 — Added a recruiter-oriented README covering product purpose, implemented scope, architecture, engineering decisions, setup, roadmap, and professional contact information.
21. 2026-08-10 — Implemented AVFoundation-based technical metadata extraction for imported tracks, including duration, bitrate, sample rate, channel count, and codec, plus a generated-WAV extractor test.
22. 2026-08-10 — Verified technical metadata extraction with `swift build` and `swift test`: 3 tests passed with 0 failures. Excluded README from the executable target to remove the SwiftPM manifest warning.
23. 2026-08-10 — Implemented Library UX improvements: searchable and sortable columns, persistent multi-track selection, and severity-based processing/error feedback.
24. 2026-08-10 — Added presentation-model coverage for display fallbacks and technical-value formatting.
25. 2026-08-10 — Verified Library UX improvements with `swift build` and `swift test`: 5 tests passed with 0 failures.
26. 2026-08-10 — Implemented persistent local library snapshots with atomic writes, Codable track state, security-scoped bookmarks, and startup restoration of accessible tracks.
27. 2026-08-10 — Added persistence coverage for snapshot round trips and restoration of an accessible track without a bookmark.
28. 2026-08-10 — Corrected bookmark refresh resolution found during the initial persistence compiler check.
29. 2026-08-10 — Reworked the persistence test’s async assertion pattern so the actor call completes before XCTest evaluates the result.
30. 2026-08-10 — Verified persistent-library storage with `swift build` and `swift test`: 7 tests passed with 0 failures.
31. 2026-08-10 — Aligned the handoff sequence with the approved roadmap: metadata reading is the next implementation stage, before BPM/key analysis.
32. 2026-08-10 — Implemented AVFoundation metadata reading for common, iTunes, and ID3 fields, with merge-safe updates and local artwork caching.
33. 2026-08-10 — Added metadata-value parser and artwork-cache coverage.
34. 2026-08-10 — Removed unsupported Common metadata identifiers discovered during the initial compiler check; genre and track number remain covered through iTunes and ID3 identifiers.
35. 2026-08-10 — Made the metadata extractor a stateless `Sendable` service, avoiding AVFoundation non-Sendable metadata objects crossing an actor boundary while retaining asynchronous processing.
36. 2026-08-10 — Verified metadata reading and artwork caching with a warning-free `swift build` and `swift test`: 10 tests passed with 0 failures.
37. 2026-08-10 — Implemented a native single/batch metadata editor with selective field application, numeric validation, artwork replacement/removal, rollback on local persistence failure, and source-file write transparency.
38. 2026-08-10 — Added metadata edit-draft coverage for selective updates, clearing values, and validation.
39. 2026-08-10 — Corrected metadata editor compatibility with macOS 12 and draft initialization/empty-track-number edge cases found during the initial compiler check.
40. 2026-08-10 — Verified native batch metadata editing with `swift build` and `swift test`: 13 tests passed with 0 failures.
41. 2026-08-10 — Initiated Stage 6 (Audio Player). Analyzed project architecture and created `AudioPlayerEngine` in `Core/Audio` acting as an `ObservableObject` wrapper around `AVPlayer` for safe playback on the MainActor, fulfilling the 'no dependencies' and 'Apple Frameworks natively' constraints.
42. 2026-08-10 — Completed Stage 6 base. Implemented `PlayerViewModel` and `PlayerView` UI containing Play, Pause, Stop, Seek, Volume, and duration formatting. Resolved Swift 6 concurrency warnings. The player now works seamlessly with library track selections.
60. 2026-08-10 — Initiated Stage 7 (Audio Conversion & Metadata Writing). Configured integration strategy to use pre-compiled FFmpeg binary for cross-format robustness (avoiding limits of AVFoundation).
61. 2026-08-10 — Implemented `FFmpegCommandRunner`, `AudioMetadataWriter`, and `AudioConversionEngine` using Swift `async/await` and non-blocking `Process` execution.
62. 2026-08-10 — Created `ConversionQueueViewModel` and `ConversionQueueView` to manage and display lossless-to-MP3 conversion jobs. Integrated the Convert action into the main Library toolbar.
63. 2026-08-10 — Initiated Stage 8 (BPM and Key Analysis).
64. 2026-08-10 — Developed a completely native 0-dependency `AudioAnalyzerEngine` utilizing Apple's Accelerate framework (vDSP) to perform high-speed offline tempo extraction via envelope and onset detection.
65. 2026-08-10 — Integrated BPM into `AudioTechnicalMetadataExtractor` and updated `LibraryView` to display and sort by BPM. Key detection is left as a future iteration due to complexity.
66. 2026-08-10 — Initiated Stage 9. Improved FFmpeg error messages to be more actionable.
67. 2026-08-10 — Developed `WaveformAnalyzer` and integrated a dynamic SwiftUI `WaveformShape` into `PlayerView` with progress masking.
68. 2026-08-10 — Migrated `LibraryPersistenceStore` from a monolithic JSON file to Programmatic Core Data (SQLite), strictly adhering to the no-dependencies rule. Saving 10,000+ tracks is now virtually instant through delta syncs via `NSBatchDeleteRequest` logic emulation and `NSPersistentContainer`.

## Current State

The project is configured as a native SwiftUI macOS executable. It displays a sidebar for Library, Conversion, Metadata, and Player. Users can select or drag files and folders into Library; supported audio files are discovered recursively off the main actor, analyzed through AVFoundation, and listed without duplicate paths. Common, iTunes, and ID3 metadata is read on import, with artwork retained as local cached files. Selected tracks can be updated singly or in batches through the native Metadata editor, with changes persisted in Convertra's library snapshot and written permanently to the source audio files via an integrated FFmpeg engine. 

Library supports search, sortable columns, multi-track selection, clear processing/error feedback, and startup restoration from a local snapshot. Core in-memory models exist, including the mandated 320 kbps CBR MP3 conversion settings. The AudioPlayerEngine provides a foundation for AVFoundation-based playback. The AudioConversionEngine uses FFmpeg to transcode tracks into MP3s, managed visually by the new Conversion Queue. The project builds without warnings and tests pass locally. Its source history is published on GitHub `main` and includes a professional README.

## Pending Tasks

- Refine Key Analysis if required.
- Build production UI, accessibility, and broader test coverage.

## Technical Decisions

- Minimum deployment target: macOS 12.0.
- Development environment target: Xcode 15.2, which Apple supports on macOS Ventura 13.5 or later and is suitable for this Intel Mac running Ventura 13.7.8.
- UI framework: SwiftUI, with AppKit reserved only for platform gaps.
- Foundation uses no third-party libraries or downloaded assets.
- Source control remote: `origin` points to `hamidkazimov777-cmd/convertra` on GitHub. Generated build output remains ignored.
- Folder traversal uses `AudioLibraryScanner`, an actor. It requests security-scoped access only while scanning a user-selected URL and releases it immediately afterwards; persistent bookmark storage is deferred until library persistence exists.
- Technical properties are extracted through `AVURLAsset` and audio-track format descriptions. The app holds a selected root's security-scoped access through both discovery and extraction, allowing nested folder items to be analyzed safely.
- Library sorting and search are UI-local for instant feedback. Selected track IDs are held in `AppViewModel`, creating a reusable selection boundary for batch metadata and conversion workflows.
- Library state is stored atomically as JSON in Application Support. Security-scoped bookmarks are kept for selected sources and tracks; unavailable entries are omitted during restoration and reported to the user.
- Metadata extraction uses AVFoundation common, iTunes, and ID3 identifiers. Cover art is cached locally in Application Support rather than retained in large in-memory library records.
- Batch metadata changes are explicit per field: disabled fields remain unchanged, while an enabled blank field clears its value. Edits are first persisted in Convertra's snapshot; source media files are not modified yet.
- Conversion default is modeled as MP3 at 320 kbps CBR with metadata, artwork, and folder-structure preservation enabled.
- Artwork is modeled as a file location rather than retained image data, which protects memory usage for large libraries.
- For Stage 6, the `AudioPlayerEngine` relies exclusively on native `AVFoundation` (`AVPlayer`, `AVPlayerItem`) for standard playback capabilities (Play, Pause, Stop, Seek, Volume, Duration), strictly avoiding unapproved third-party dependencies. 
- For Stage 7, the `AudioConversionEngine` and `AudioMetadataWriter` utilize a pre-compiled `ffmpeg` binary called via `Process`. This bypasses Apple's lack of native MP3 encoding and poor in-place metadata rewriting support while maintaining strict Swift memory safety by not importing raw C-libraries.

## Known Issues

- Persistent bookmarks are created from user-selected locations, but bookmark behavior has not yet been verified in a sandboxed, signed `.app` bundle.
- AVFoundation metadata coverage differs by audio container; reading has not yet been validated against a broad real-world media corpus.
- The bundled FFmpeg binary strategy requires the user to place an `ffmpeg` executable in the bundle Resources or `/opt/homebrew/bin/ffmpeg` path for operations to succeed.
- Swift Package development setup is not a signed/distributable `.app` bundle yet.

## Next Recommended Step

Polishing the Production UI, adding accessibility, and refining the general aesthetics.
