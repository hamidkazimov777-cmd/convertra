import Foundation

enum FFmpegError: Error, LocalizedError {
    case binaryNotFound
    case executionFailed(exitCode: Int, errorOutput: String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "The 'ffmpeg' command-line tool is missing. Convertra requires FFmpeg for conversion and metadata editing. Please install it (e.g., 'brew install ffmpeg') or place the binary in the app bundle."
        case let .executionFailed(code, output):
            return "FFmpeg execution failed with code \(code):\n\(output)"
        }
    }
}

actor FFmpegCommandRunner {
    private var ffmpegURL: URL? {
        // Look in bundle first
        if let bundleURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            return bundleURL
        }
        
        // Fallbacks for local development
        let paths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }

    func run(arguments: [String]) async throws -> String {
        guard let executableURL = ffmpegURL else {
            throw FFmpegError.binaryNotFound
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        // FFmpeg writes almost everything (including progress) to stderr.
        // We'll capture both stdout and stderr together.
        process.standardError = pipe
        process.standardOutput = pipe

        try process.run()

        // Terminate the ffmpeg process if the surrounding Task is cancelled
        // (e.g. the user stops the conversion job).
        return try await withTaskCancellationHandler {
            var outputData = Data()
            // Read asynchronously to prevent pipe buffer deadlock
            for try await byte in pipe.fileHandleForReading.bytes {
                outputData.append(byte)
            }

            process.waitUntilExit()

            if Task.isCancelled {
                throw CancellationError()
            }

            let outputString = String(decoding: outputData, as: UTF8.self)

            if process.terminationStatus == 0 {
                return outputString
            } else {
                throw FFmpegError.executionFailed(
                    exitCode: Int(process.terminationStatus),
                    errorOutput: outputString
                )
            }
        } onCancel: {
            process.terminate()
        }
    }
}
