// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Convertra",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Convertra", targets: ["Convertra"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Convertra",
            path: ".",
            exclude: [
                "Tests",
                "handoff",
                "README.md"
            ],
            sources: [
                "App/ConvertraApp.swift",
                "App/AppViewModel.swift",
                "App/ContentView.swift",
                "Features/Library/LibraryView.swift",
                "Features/Metadata/MetadataEditorView.swift",
                "Core/Audio/SupportedAudioFormat.swift",
                "Core/Services/AudioLibraryScanner.swift",
                "Core/Services/AudioTechnicalMetadataExtractor.swift",
                "Core/Services/AudioMetadataExtractor.swift",
                "Core/Services/ArtworkCache.swift",
                "Core/Services/LibraryPersistenceStore.swift",
                "Core/Models/AudioFile.swift",
                "Core/Models/AudioMetadata.swift",
                "Core/Models/MetadataEditDraft.swift",
                "Core/Models/AudioAnalysis.swift",
                "Core/Models/ConversionJob.swift",
                "Core/Audio/AudioPlayerEngine.swift",
                "Features/Player/PlayerViewModel.swift",
                "Features/Player/PlayerView.swift",
                "Core/Services/FFmpegCommandRunner.swift",
                "Core/Services/AudioMetadataWriter.swift",
                "Core/Services/AudioConversionEngine.swift",
                "Core/Services/WaveformAnalyzer.swift",
                "Features/Conversion/ConversionQueueViewModel.swift",
                "Features/Conversion/ConversionQueueView.swift",
                "Core/Services/AudioAnalyzerEngine.swift"
            ]
        ),
        .testTarget(
            name: "ConvertraTests",
            dependencies: ["Convertra"],
            path: "Tests/ConvertraTests"
        )
    ]
)
