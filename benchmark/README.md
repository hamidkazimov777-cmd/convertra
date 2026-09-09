# Convertra accuracy benchmark

The headline numbers in the top-level README come from running the analysis
engine over a labelled set of real tracks and comparing its output to
ground-truth key/BPM tags. This directory documents that process so it can be
re-run on any labelled library.

The 111-track set used for the published figures is commercial audio and cannot
be redistributed, so it is not in the repository. Everything needed to reproduce
the measurement on your own tracks is.

## What the numbers were

Private set of 111 commercial tracks (house, tech-house, hip-hop, pop):

| Metric | Result |
| --- | --- |
| Key — exact Camelot match | ~70% |
| Key — harmonically compatible match | ~83% |
| Tempo — within ±0.5 BPM | ~82% |
| Analysis time per track (Apple Silicon) | ~1 s |

## How the harness works

The pipeline is implemented in [`../Core/Services/Analysis/Benchmark`](../Core/Services/Analysis/Benchmark):

- `RealBenchmarkDataset` (`BenchmarkModels.swift`) — the JSON schema: a list of
  tracks, each with a file path, ground-truth key/BPM, and optional reference
  results from Mixed In Key, rekordbox and Lexicon.
- `ReferenceDataImporter.swift` — parses a CSV export from third-party DJ
  software into that schema, so you can build a dataset from tags you already
  have.
- `ReferenceNormalizer.swift` — normalises key spellings (`F Minor`, `Fm`, `4A`,
  `08B` → `4A`/`8B`) and BPM formats before comparison.
- `RealAudioBenchmarkRunner.swift` — decodes each file, runs the full engine,
  and classifies every result as exact / harmonically compatible / fifth /
  relative / parallel / critical error, plus BPM error and per-stage timing.

## Reproducing it on your own library

1. Tag a set of tracks in Mixed In Key / rekordbox / Lexicon (this is your
   ground truth).
2. Export those tags to CSV, or write a dataset JSON directly against the schema
   in [`benchmark_dataset.example.json`](benchmark_dataset.example.json). File
   paths must point at the actual audio files on disk.
3. Point `RealAudioBenchmarkRunner.runBenchmark(datasetURL:)` at your JSON. With
   no dataset present it returns an empty report marked
   "Real-world accuracy is not yet verified" rather than any invented number.
4. Read the report: exact/harmonic key rates, BPM tolerance rates, and timing.

## Honesty note

Without a labelled set on disk the engine reports nothing rather than a
placeholder. The published ~70/83/82% figures are a measurement over one private
111-track set, not a guarantee for arbitrary catalogues; run the harness on your
own material to get numbers you can trust for your use.
