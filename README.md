<div align="center">

# Convertra

**Native macOS Audio Platform & Proprietary DSP Engine for DJs**

[![macOS](https://img.shields.io/badge/macOS-12.0%2B-000000?style=flat-square&logo=apple&logoColor=white)]()
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)]()
[![DSP](https://img.shields.io/badge/AudioCore-C%2B%2B%20%7C%20vDSP-00599C?style=flat-square)]()

</div>

---

## What is Convertra?

Convertra is a professional, native macOS application designed for DJs and music producers. It serves as a local, offline alternative to the analysis and tagging workflows found in industry standards like rekordbox, Serato, and Mixed In Key.

Instead of wrapping a web app in Electron, Convertra is built from the ground up using **Swift** and Apple's native frameworks (SwiftUI, AVFoundation, CoreData). This ensures zero latency, minimal memory footprint, and deep OS integration.

**Core Capabilities:**
- **Smart Ingestion**: Drag-and-drop recursive directory scanning with delta-sync SQLite persistence.
- **Pro-Grade Metadata**: ID3v2 tagging with native cover-art embedding (supports both MP3 and AIFF).
- **Lossless Conversion**: Batch conversion queue powered by an optimized FFmpeg pipeline.
- **Native Playback**: High-performance AVFoundation player with dynamic waveform visualization.

---

## 💎 The Crown Jewel: Convertra AudioCore

While the UI and library management are open for inspection, the true engineering feat of this project is **Convertra AudioCore** — a proprietary Digital Signal Processing (DSP) engine. 

AudioCore performs musical key (Camelot Wheel) and BPM tempo detection entirely on-device. It runs without cloud APIs or heavy neural networks, utilizing pure mathematical DSP over Apple's `Accelerate` and `vDSP` frameworks.

### Benchmark Validation
Tested against ground-truth tags from 111 commercial tracks (house, tech-house, hip-hop, pop):

| Metric | Accuracy / Performance |
|---|---|
| **Key Detection** (Exact Camelot match) | **~70%** |
| **Key Detection** (Harmonic/mix-compatible match) | **~83%** |
| **Tempo Detection** (Within ±0.5 BPM) | **~82%** |
| **Analysis Speed** (Per track on Apple Silicon) | **~1 second** |

*Methodology: Peak-picking harmonic pitch-class profiling (HPCP) for key detection; autocorrelation with parabolic sub-BPM interpolation for tempo. Detailed methodology is documented in [`HANDOFF.md`](./HANDOFF.md).*

> **OEM Licensing:** The AudioCore engine is distributed within this repository as a pre-compiled `.xcframework` binary. If you are building DJ software and need a drop-in C++/Swift DSP engine for key and BPM detection, please reach out.

---

## Architecture

The application is structured using a domain-driven architecture to maintain strict separation between the UI, business logic, and the heavy DSP layers:

```text
App/                    Application lifecycle & global state
Core/
  ├── Audio/            AVFoundation player engines
  ├── Services/
  │   ├── Analysis/     AudioAnalysisEngine adapters → Convertra AudioCore binary
  │   ├── Metadata/     Native ID3v2 tag/cover-art writers
  │   └── Persistence/  CoreData/SQLite delta-sync storage
Features/
  ├── Library/          Drag-and-drop, track inspector, recursive scanning
  ├── Conversion/       FFmpeg-powered batch conversion queue
  └── Player/           Waveform rendering and playback control
Frameworks/             ConvertraAudioCore.xcframework (Closed-source DSP binary)
```

**Engineering Highlights:**
- **Concurrency**: Actor-based background library scanning. Tempo and Key detection run concurrently per track.
- **Sandbox Compliance**: Security-scoped resource handling for robust App Store sandbox constraints.
- **Memory Efficiency**: Fast single-pass audio decode via `AVAssetReader` directly into vDSP buffers.

---

## Build Instructions

```bash
git clone https://github.com/hamidkazimov777-cmd/convertra.git
cd convertra

# Run test suite
swift test

# Build and package signed Convertra.app bundle
./package_app.sh
```
*Requires macOS 12.0+ and Xcode 15.2+*

---

## Contact & Credits
**Built by Hamid Kazimov** — Product Builder & Software Creator. 
For professional inquiries, collaboration, or AudioCore licensing, contact me on [Telegram](https://t.me/hamidkazim).
