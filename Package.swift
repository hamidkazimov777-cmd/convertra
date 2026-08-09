// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Convertra",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Convertra", targets: ["Convertra"])
    ],
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
                "Core/Audio/SupportedAudioFormat.swift",
                "Core/Services/AudioLibraryScanner.swift",
                "Core/Services/AudioTechnicalMetadataExtractor.swift",
                "Core/Models/AudioFile.swift",
                "Core/Models/AudioMetadata.swift",
                "Core/Models/AudioAnalysis.swift",
                "Core/Models/ConversionJob.swift"
            ]
        ),
        .testTarget(
            name: "ConvertraTests",
            dependencies: ["Convertra"],
            path: "Tests/ConvertraTests"
        )
    ]
)
