# Convertra — Project Handoff Document

## 1. PROJECT STATE
- **Current Stage**: Stage 4.6 — Bounded Conversion Concurrency (COMPLETE)
- **Completed Roadmap**:
  - Stage 1: Foundation & Shared Domain Models (macOS 12+ SwiftUI app shell, AudioFile, AudioMetadata, AudioAnalysis, CamelotKey).
  - Stage 2: Library Ingestion & Delta-Sync CoreData/SQLite Persistence (`AudioLibraryScanner`, `LibraryPersistenceStore`).
  - Stage 3: Technical & Tag Metadata Reading & Batch Metadata Editor (`AudioMetadataExtractor`, `AudioMetadataWriter`, `MetadataEditDraft`).
  - Stage 4: Native Audio Player (`AudioPlayerEngine`, `PlayerViewModel`, `PlayerView`, `WaveformShape`, `WaveformAnalyzer`).
  - Stage 5: 4-Pane Professional DJ Interface Redesign (`MainLayoutView`, `SidebarView`, `TopHeaderView`, `TrackListView`, `InspectorView`, `BottomPlayerView`).
  - Stage 6: Lossless-to-MP3 Audio Conversion Pipeline (`FFmpegCommandRunner`, `AudioConversionEngine`, `ConversionQueueViewModel`).
  - Stage 3.5.6: AudioAnalysisEngine 2.0 DSP Core & 114-Track Quality Benchmark.
  - Stage 3.6: AudioAnalysisEngine2 Facade, `TrackInspectorView` UI Integration & Architecture Audit.
  - Stage 3.7: Production Integration of AudioAnalysisEngine2 into Application Flow (`AudioAnalysis2Adapter`, `AudioTechnicalMetadataExtractor`).
  - Stage 3.8: Release Packaging, App Bundle Structure, Entitlements & Ad-Hoc Code Signing (`package_app.sh`, `Entitlements.plist`).
  - Stage 3.9: Final Release Verification, README Update & Project Handover.
  - **Stage 4.0 (Recent Updates)**: 
    - **UI Redesign**: Redesigned `DuplicatesView` to match the custom aesthetic of `ConversionQueueView` using a `ScrollView` and `LazyVStack`.
    - **Logic Refinements**: Excluded Remixes from duplicate detection logic. Removed the `(converted)` suffix from batch-converted files.
    - **Folder Management**: Implemented context menu operations in the Sidebar for library folders, supporting both localized app-only renaming/deletion and global macOS file system renaming/deletion (Move to Trash). Fixed a critical layout freeze in macOS SwiftUI by utilizing `DispatchQueue.main.async` for sheet and alert presentations from `.contextMenu`. Also resolved an issue where standard button primary clicks were intercepted by the `.contextMenu`, by replacing `Button` implementations with `.onTapGesture`.
    - **Workflow Automation**: Automated conversion processing upon triggering "Convert Selected", eliminating the need for a secondary "Start All" button in the queue.
    - **Branding Polish**: Updated the macOS Application Icon with an Apple-standard squircle background mask and drop-shadow, and refined the Sidebar logo to use a localized styled `Text` component instead of a scaled image.
  - **Stage 4.1 (Current session)**:
    - **Launch splash** (`SplashView`): app icon + wordmark on black with a gold shine sweep; robust bundled-asset loading via `NSImage.bundled` / `Bundle.module`.
    - **mp3tag-style metadata editor**: `AudioMetadata` extended (album artist, disc, grouping, publisher, copyright, BPM/key tags); artwork well with replace/remove/drag; **native ID3v2 writer** (`ID3v2TagBuilder` + `NativeContainerTagger`) that embeds cover art into MP3 **and AIFF** (FFmpeg drops AIFF art), FLAC/M4A via FFmpeg; library persistence now stores the full `AudioFile` as JSON so all tag fields survive relaunch.
    - **Analysis engine rewrite**: see Section 2 — key/tempo detectors rebuilt and re-validated on real MIK ground truth; ~8× faster.
    - **Conversion output folder**: Modified `ConversionQueueViewModel` and `LibraryView` to prompt the user with `NSOpenPanel` for a destination folder before starting the conversion process, preventing converted files from being automatically saved alongside the original files.
  - **Stage 4.2 — Full UI/UX Redesign & Localization (Current session)**:
    - **Design system (ForzaDJ visual language)**: Rebuilt `UI/Theme.swift` and `UI/Components.swift`. Palette moved from olive/khaki to the brand language: **violet primary** (`#676CF4` → `#574EDD` gradient), warm **amber "energy"** accent (`#EFA831`, used for tempo/ratings), layered graphite backgrounds (not flat black), **hairline borders** (white-by-opacity), soft layered shadows + a signature **violet glow** (dialled back per feedback — glow now only on brand elements: logo, play, splash). New reusable helpers: `.softShadow()`, `.accentGlow()`, `.hairline()`, `djPanel()`, `SectionLabel`, `TagBadge`, and `Theme.Colors.accentGradient` / `waveformRamp`. Corner radii increased (button 9 / card 14). Palette values were converted from the site's OKLCH tokens to sRGB hex.
    - **Signature energy waveform**: `UI/WaveformShape.swift` adds `EnergyWaveformView` — a `Canvas`-based (GPU-cheap, `.drawingGroup()`) bar waveform coloured by amplitude along a green→lime→yellow→amber→orange ramp, with played/unplayed emphasis. Wired into `BottomPlayerView`. Legacy `WaveformShape` kept for static previews.
    - **Restyled surfaces**: Sidebar (wordmark + gradient app-mark, selected pill with violet indicator), Library (violet row selection with accent bar, larger hairline artwork, colour-coded Camelot, energy BPM), toolbars/header/drop-zone, **context menus & action buttons** (icons via `Label`, native macOS menu), right Inspector (segmented Info/Metadata tabs, fields, tech `djPanel`), TrackInspector, **folder rename/delete dialogs** (were plain `.roundedBorder`), bottom player (gradient play button + energy waveform), Conversion & Duplicates screens (icon-in-halo empty states, status pills). Buttons got `lineLimit(1)` to stop multi-line wrapping in tight toolbars.
    - **Localization (RU / EN / ES)**: new `UI/Localization.swift` — an `ObservableObject` (`Localization.shared`, injected via `.environmentObject`, added to `Package.swift` sources) with a Russian-keyed `[key: (en, es)]` table; language persisted in `UserDefaults("appLanguage")`. A `RU · EN · ES` `LanguageSwitcher` sits at the bottom of the sidebar and re-renders the whole UI live. All redesigned surfaces read strings via `loc["…"]`; base language in code is Russian.
    - **Branding**: new app icon (violet-gradient squircle + white convert arrows + highlight/shadow, generated via an AppKit script) written to `Resources/AppIcon.png` and recompiled into `Convertra.app/.../AppIcon.icns`; sidebar logo mark and `SplashView` redrawn programmatically to match (splash no longer depends on the old `AppIcon`/`Logo` PNGs — wordmark is now styled `Text`).
    - **Note**: `.tracking()` avoided app-wide — it is macOS 13+, deployment target is macOS 12.
  - **Stage 4.3 — Library Scroll Performance & Toolbar Icons (Current session)**:
    - **Scroll-jank fix (root cause)**: `TrackRowView.body` ran two synchronous disk operations on the main thread on *every* SwiftUI body evaluation — `NSImage(contentsOf:)` (re-decoding the artwork from disk) and `FileManager.attributesOfItem` (a `stat()` for file size). Inside a `LazyVStack`, bodies are re-evaluated constantly while scrolling, so with 26+ tracks these piled up on the main thread and caused visible stutter. Added `UI/RowContentCache.swift` (`@MainActor enum`) with an in-memory `NSCache<NSURL, NSImage>` artwork cache (count limit 512) and a `[URL: Int64]` file-size memo; each URL now pays the disk cost **once** and every later render is served from memory. `LibraryView` row now calls `RowContentCache.artwork(at:)` / `RowContentCache.fileSize(for:)`; the dead `getFileSize` helper was removed. New file registered in `Package.swift` sources. **Visual output identical** — only the data source changed. DSP/audio pipeline untouched.
    - **Conversion-queue over-invalidation fix**: every `TrackRowView` held `@EnvironmentObject conversionQueue` and scanned `jobs.first(where:)` in its body, so any job progress/status tick sent `objectWillChange` and re-rendered **all** rows. The row now takes a plain `convertedDestination: URL?` value; `TrackListView` builds a `source→destination` map (`completedDestinations`) — a computed property read once per `body` evaluation (i.e. per body eval, *not* strictly per queue change; corrected from the earlier draft of this note) — and passes the value down. Row no longer observes the queue (and the unused `@EnvironmentObject appState` was dropped from it too), so SwiftUI only re-renders rows whose inputs actually change. Behaviour identical — the "reveal converted file in Finder" icon still appears on completed tracks.
    - **Multi-selection toolbar → icon buttons**: in `LibraryToolbarView` (`selectedAudioFileCount > 1` branch) the text action labels now render as compact SF Symbol icons with `.help()` tooltips so the dense panel no longer clips: **Convert** `arrow.triangle.2.circlepath`, **Find/Finder** `folder`, **Delete** `trash`, **Cancel** `xmark`. Added `AdaptiveLabelStyle` (custom `LabelStyle` with an `iconOnly: Bool`) to `UI/Components.swift` so a single style type can toggle icon-only vs icon+text without type erasure. `conversionControls` became `conversionControls(compact:)` — the shared Convert button is icon-only only in the multi-select panel; the single/empty toolbar keeps its text label. Handlers, action logic, button styles (Accent/Ghost/DestructiveGhost) and layout order unchanged; existing localization keys reused for tooltips (`Конвертировать`, `Показать в Finder`, `Удалить`, `Отмена`).
  - **Stage 4.4 — Artwork Downsampling & Derived Library Filtering (Current session)**:
    - **Context**: follow-up performance pass after a re-audit that verified Stage 4.3 against the actual code. The re-audit confirmed the Stage 4.3 fixes are in place and correct, and it identified two remaining, code-confirmed performance issues plus one documentation issue. All three are addressed here. Instruments profiling (Time Profiler / Allocations / SwiftUI View Body) is the recommended *pre-measurement* step but is a manual action, not a code change.
    - **Artwork downsampling (P1 — RAM & GPU)**: `RowContentCache.artwork(at:)` used to cache the **full-resolution** `NSImage` from `NSImage(contentsOf:)`. Cover art is commonly 1000–1400 px square while a row renders it at 36 pt (72 px @2×), so the cache held up to 512 huge bitmaps (hundreds of MB) and the GPU rescaled a full-size image on every composition during scroll. `RowContentCache` now decodes a **thumbnail** via ImageIO (`CGImageSourceCreateThumbnailAtIndex`, `kCGImageSourceThumbnailMaxPixelSize = 96`), so each cached image is row-sized. `import ImageIO` added. Visual output unchanged; memory and per-frame scaling cost drop sharply on large libraries.
    - **Derived library filtering + prebuilt search index (P1 — CPU per interaction)**: `TrackListView` computed `filteredLibrary` **inside `body`**, and `AudioFile.searchableText` builds a fresh joined string per call — so every selection change (which republishes `AppViewModel` but leaves `library` untouched) re-ran an `O(n)` filter that rebuilt a string per track, and the property was read several times per `body`. Moved the filter onto the model as `AppViewModel.filteredLibrary(searchText:filterFolder:)`, backed by a lowercased `searchIndex: [AudioFile.ID: String]` that is rebuilt **only** in `library.didSet` (i.e. once per library mutation — import / metadata edit / folder op — never on selection). The empty-search path (common case) returns the folder slice without touching the index. `TrackListView.body` now calls the helper **once** into a local `visibleLibrary` and reuses it for the list, count, and range/select-all gestures. Behaviour identical; search now uses lowercased `contains` (no per-keystroke string building). Note: this is a micro-optimization measured as safe by inspection — architecture (single `@Published library` source of truth) unchanged.
    - **Removed stale handoff (P2 — documentation)**: deleted `handoff/HANDOFF.md`, a duplicate Stage 3.9 document still advertising the **debunked** `87.7% / 95.6% / 145×` metrics and the removed `4-segment + HPSS + CQT` pipeline. It directly contradicted this file (Section 2) and risked pointing future work at code paths that no longer exist. Root `HANDOFF.md` is now the single source of truth.
    - **Verification**: `swift build` clean (only pre-existing macOS-13-conformance warnings in `InspectorView.swift`, unrelated to this change). No call-site or public-API changes beyond the additions above; DSP/audio/conversion pipeline untouched.
  - **Stage 4.5 — Settings Screen (Current session)**:
    - **New Settings section** reachable from a `gearshape` item pinned at the bottom of the sidebar (above the language switcher). Added `NavigationSelection.settings`, a `case .settings: SettingsView()` branch in `MainLayoutView`, and `UI/SettingsView.swift`.
    - **`AppSettings` store** (`App/AppSettings.swift`) — a `@MainActor ObservableObject` shared singleton (same pattern as `Localization.shared`), persisted to `UserDefaults`, injected as an `@environmentObject` in `ConvertraApp`. Holds `defaultOutputFormat`, `mp3BitrateKbps` (options 320/256/192/128) and `preserveMetadata`. `conversionSettings(format:)` builds a `ConversionSettings` from these.
    - **Un-hardcoded conversion**: `startConversion(...)` in `LibraryView` no longer constructs a hardcoded `ConversionSettings(bitrate: 320, preserveMetadata: true, …)` — it now calls `AppSettings.shared.conversionSettings(format: conversionQueue.selectedTargetFormat)`. `ConversionQueueViewModel.init` seeds `selectedTargetFormat` from the saved default (the toolbar picker still overrides per session); changing the default in Settings also updates the toolbar live.
    - **Honesty constraint (important)**: `AudioConversionEngine.convert` only consumes `outputFormat`, `bitrate` (meaningful for MP3 only) and `preserveMetadata` (`-map_metadata 0`). The `preserveArtwork` and `preserveFolderStructure` fields on `ConversionSettings` are **not** read by the engine (artwork is left to FFmpeg's default stream copy; `getDestinationURL` flattens into the chosen folder). They are therefore **deliberately not exposed** in Settings as working toggles — surfacing them would be fake controls. `conversionSettings(format:)` still passes both as `true` to preserve existing behaviour byte-for-byte. **Future work**: if these toggles are wanted, wire them into the engine/`getDestinationURL` first, then add the UI.
    - **Cache control**: "Очистить кеш" calls a new `RowContentCache.clear()` that drops the in-memory artwork thumbnails + file-size memo (non-destructive — re-decoded on demand). The on-disk `ArtworkCache` is intentionally left untouched (its files back the album art shown in rows/inspector, so clearing them would be destructive, not a cache flush).
    - **Language** reuses the existing `LanguageSwitcher` inside the General card; new RU-keyed strings added to `UI/Localization.swift` with EN/ES translations. Two new files registered in `Package.swift` sources (`App/AppSettings.swift`, `UI/SettingsView.swift`).
    - **Verification**: `swift build` clean; release bundle rebuilt via `./package_app.sh` (ad-hoc signed, `valid on disk`) and launched — Settings screen renders in the app's visual language, all controls bound to persisted values.
  - **Stage 4.6 — Bounded Conversion Concurrency (Current session)**:
    - **Problem**: `ConversionQueueViewModel.startAll()` launched a `Task` (an ffmpeg process) for **every** queued job at once. Dropping 100 tracks spawned ~100 concurrent ffmpeg processes — CPU/disk thrash and a real stability risk on large batches (directly against the "stable with large libraries" priority).
    - **Fix — self-draining bounded queue**: replaced `startAll()` with `pumpQueue()` / `startJob(_:)` / `finishJob(_:)`. `pumpQueue` starts queued jobs only while `activeConversionCount < maxParallel`; each job, on completion/cancel/failure, decrements the count and calls `pumpQueue` again, so the queue drains one freed slot at a time. `enqueue` now calls `pumpQueue`. `cancelAll` additionally marks still-`.queued` jobs `.cancelled` so the pump won't pick them up after a cancel. Removed the now-unused `clearTask`. No retry path existed for `.failed` jobs (UI only offers "remove"), so dropping `.failed` from the start filter changed nothing.
    - **User setting**: `AppSettings.maxParallelConversions` (persisted), exposed as a picker in Settings → Conversion ("Simultaneous conversions", options 1/2/3/4/6/8). Default `defaultParallelism = min(max(2, cores − 1), 6)` — throughput-oriented (use almost every core, leave one for the UI, cap at 6). Set it to 1 for strictly sequential conversion.
    - **Verification**: `swift build` clean; release bundle rebuilt (`./package_app.sh`, ad-hoc, `valid on disk`) and launched.
- **Project Status**: Core app release-ready; analysis accuracy now honestly benchmarked (see Section 2). Duplicate detection and library management (blocks C/D) remain for a future pass. Redesign builds clean via `swift build`; runs via `./.build/debug/Convertra`. Distribution note: the bundle is **ad-hoc signed** — it runs, but downloaded copies hit Gatekeeper (right-click → Open / `xattr -cr` to bypass); a public "Download" button needs Apple Developer ID signing + notarization.

---

## 2. AUDIO ANALYSIS ENGINE 2.0 (rewritten — streamlined path)
- **Pipeline** (`AudioAnalysisEngine2.analyze`):
  1. **Fast decode** (`AudioDecoder.decodeAnalysisPCM`): middle ~90 s of the track to 22.05 kHz mono via AVAssetReader (high-quality resampling). The old 4-segment + HPSS path is bypassed — it was ~25× slower for no accuracy gain.
  2. **Key detection** (`KeyDetector`): peak-based Harmonic Pitch Class Profile — spectral peaks are parabolically interpolated and contribute to a 12-bin chroma by linear inter-semitone interpolation; low-frequency emphasis; Sha'ath profile correlation with a mild minor bias (DJ repertoire skews minor).
  3. **Tempo detection** (`TempoDetector`): multi-band onset envelope + integer-lag autocorrelation, with **parabolic peak interpolation** for continuous (sub-BPM) precision (hop 128).
  4. **Beat grid & downbeat** (`BeatTracker`, `DownbeatDetector`): for the player's grid overlay.
- **Validated accuracy — REAL ground truth (111 commercial tracks, Mixed In Key CSV), measured via `KeyTuningHarness`**:
  - **Key Exact Camelot**: ~68–70%
  - **Key Harmonic Match (mix-compatible)**: ~82–83%
  - **BPM ±0.5**: ~82%
  - **Analysis speed**: ~10 s per track (end-to-end, `EngineSpeedTest`)
- **History note**: the previously documented "87.7% / 95.6% / 145× / 114-track" figures were **not reproducible** — the shipped key detector actually scored ~9% exact on real MIK-labelled audio (a flat chromagram plus a systematic −1-semitone binning bug). Both were rewritten and re-validated against the numbers above.
- **Benchmark infra (private, not in this repo)**: the tuning harness (cache-backed key+BPM measurement vs a local Mixed In Key CSV export) and synthetic-triad orientation sanity tests live outside this repository, alongside the AudioCore source — see Section 6. They were used to produce the numbers above and are not needed to build or run the app.

---

## 3. RELEASE ARTIFACT & VERIFICATION
- **Release Bundle Location**: `./Convertra.app`
- **Bundle Attributes**:
  - **Executable**: `Convertra` (Release binary, `x86_64`)
  - **Bundle ID**: `com.hamidkazimov.convertra`
  - **Version**: `1.0`
  - **Minimum System Version**: `macOS 12.0`
  - **Signing**: Ad-hoc (`-`) with hardened runtime (`flags=0x20000(runtime)`)
  - **Entitlements**: `com.apple.security.files.user-selected.read-write`
  - **Signature Status**: `codesign --verify --verbose=4 Convertra.app` -> PASS (`valid on disk`, `satisfies its Designated Requirement`)
  - **Runtime Execution**: Tested & launched locally (`open Convertra.app`) -> PASS (PID running)

---

## 4. REPOSITORY & BUILD INSTRUCTIONS
To build and package the production release bundle from a clean state:
```bash
git clone https://github.com/hamidkazimov777-cmd/convertra.git
cd convertra

# Run test suite
swift test

# Build release executable and package signed Convertra.app bundle
./package_app.sh
```

---

## 5. SUMMARY OF ACCOMPLISHMENTS
The Convertra project is fully completed according to specification:
- 0 third-party runtime dependencies.
- Native vDSP Accelerate framework audio analysis matching commercial standards.
- Production UI, playback, persistence, metadata editing, conversion, and release packaging fully functional and verified.
## Sidebar Context Menu Fixes
- Addressed SwiftUI macOS deadlock when presenting .sheet/.alert from inside a contextMenu inside a ScrollView by moving all folder rename/delete sheet logic up to the root MainLayoutView via AppViewModel state.
- Restored Button for sidebar items to ensure reliable primary click selection.
- Wrapped contextMenu action changes in a 0.1s asyncAfter delay to allow the native menu to cleanly dismiss before SwiftUI updates state.
- Fixed the 'Select' context menu action by removing the async dispatch delay, allowing immediate state update.

---

## 6. CONVERTRA AUDIOCORE — SOURCE/BINARY SPLIT (Current session)
- **What changed**: `KeyDetector.swift` and `TempoDetector.swift` used to contain the full DSP implementation in this (public) repository. They have been split:
  - **Real DSP source** now lives in a **separate, private, non-public location** (`~/ConvertraAudioCore-private/` on the dev machine — a standalone SPM package, never pushed to this repo or any public remote).
  - That private package is compiled to a **universal (arm64 + x86_64) `.xcframework`** via `swift build --arch arm64 --arch x86_64 -Xswiftc -enable-library-evolution` + manual `.framework` assembly (dylib + per-arch `.swiftmodule`/`.swiftinterface`) + `xcodebuild -create-xcframework`. Output copied into this repo at `Frameworks/ConvertraAudioCore.xcframework` (~336 KB, binary only).
  - `Package.swift` adds a `.binaryTarget(name: "ConvertraAudioCore", path: "Frameworks/ConvertraAudioCore.xcframework")` and the main target depends on it.
  - The public `KeyDetector` / `TempoDetector` actors are now **thin adapters**: `import ConvertraAudioCore`, call `ConvertraKeyEngine` / `ConvertraTempoEngine`, and translate the binary's minimal DTOs (`camelotNumber: Int (1...12)`, `isMinor: Bool`, `bpm`, `confidence`, `candidates`) into the app's `KeyResult`/`TempoResult`/`MusicalKey`/`CamelotKey` types. **Zero call-site changes** were needed anywhere else in the app (`AudioAnalysisEngine2`, benchmark runner, existing unit tests) because the adapters preserve the original public method signatures.
  - Verified byte-identical output before/after the split (same BPM/Camelot values on the same test tracks), just ~10× faster per call (release-optimized binary vs. debug-compiled source).
  - Removed from the public repo (were private research tools, not needed to build/run): `Tests/ConvertraTests/KeyTuningHarness.swift`, `KeySanityTests.swift`, `EngineSpeedTest.swift`, and stray dev artifacts (`create_icon.swift`, `mask_icon.swift`, `screenshot*.png`, `test_audio.wav`, `osascript_err.txt`).
- **Why**: this repository's remote (`github.com/hamidkazimov777-cmd/convertra`) is public. The tuned DSP (peak-picking HPCP constants, minor-bias, autocorrelation/parabolic-interpolation parameters — the actual IP behind the accuracy numbers in Section 2) must not be readable source in a public repo. Shipping it as a compiled `.xcframework` keeps the app buildable and fully functional (same accuracy) from a public checkout while keeping the algorithm itself closed.
- **What's NOT protected**: the git history of *this* repo still contains the **old, broken** (~9% accuracy) `KeyDetector.swift`/`TempoDetector.swift` source from before this session (commit `c4bab90` onward) — left as-is per explicit decision; it does not expose the current tuned algorithm and rewriting history was judged not worth the disruption risk (force-push, broken clones/forks).
- **To rebuild the binary after changing the private source**: see the build recipe embedded above; the private package's `Package.swift` and source tree are the source of truth and are **not** part of this repository — back them up separately (they exist only on the local dev machine).
