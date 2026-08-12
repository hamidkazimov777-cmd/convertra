import Foundation
import Combine
import SwiftUI

@MainActor
final class ConversionQueueViewModel: ObservableObject {
    @Published private(set) var jobs: [ConversionJob] = []
    @Published var selectedTargetFormat: ConversionSettings.OutputFormat
    /// Last destination folder chosen this session — reused so batch conversions
    /// don't re-prompt for a folder every single time.
    @Published var lastOutputFolder: URL?

    private let engine = AudioConversionEngine()

    init() {
        // Seed the toolbar format from the saved default; the picker can still
        // override it for the session.
        selectedTargetFormat = AppSettings.shared.defaultOutputFormat
    }
    /// Running conversion tasks by job id, so a job can be cancelled mid-flight.
    private var tasks: [UUID: Task<Void, Never>] = [:]
    /// Conversions currently in flight, so the queue can honour the configured
    /// parallelism limit instead of starting every job at once.
    private var activeConversionCount = 0

    private var maxParallel: Int {
        max(1, AppSettings.shared.maxParallelConversions)
    }

    var totalJobs: Int { jobs.count }
    
    var completedJobs: Int {
        jobs.filter { $0.status == .completed }.count
    }
    
    var overallProgress: Double {
        guard !jobs.isEmpty else { return 0 }
        let total = jobs.reduce(0.0) { $0 + ($1.status == .completed ? 1.0 : $1.progress) }
        return total / Double(jobs.count)
    }
    
    var isProcessing: Bool {
        jobs.contains { $0.status == .preparing || $0.status == .converting }
    }
    
    func enqueue(files: [AudioFile], settings: ConversionSettings, outputFolder: URL) {
        // When preserving structure, recreate each file's path relative to the
        // batch's common ancestor under the output folder.
        let sourceRoot = settings.preserveFolderStructure
            ? Self.commonAncestor(of: files.map(\.url))
            : nil
        let newJobs = files.map { file in
            let destURL = getDestinationURL(for: file, settings: settings, outputFolder: outputFolder, sourceRoot: sourceRoot)
            return ConversionJob(
                sourceURL: file.url,
                destinationURL: destURL,
                settings: settings
            )
        }
        jobs.append(contentsOf: newJobs)
        pumpQueue()
    }

    /// Starts queued jobs until the in-flight count reaches the parallelism
    /// limit. Called after enqueue and again whenever a job finishes, so the
    /// queue drains itself one freed slot at a time.
    private func pumpQueue() {
        while activeConversionCount < maxParallel,
              let next = jobs.first(where: { $0.status == .queued }) {
            startJob(next)
        }
    }

    private func startJob(_ job: ConversionJob) {
        let id = job.id
        updateStatus(for: id, status: .preparing)
        activeConversionCount += 1
        tasks[id] = Task { [weak self] in
            guard let self else { return }
            do {
                await self.updateStatus(for: id, status: .converting)
                try await self.engine.convert(job: job)
                await self.updateStatus(for: id, status: .completed, progress: 1.0)
            } catch is CancellationError {
                await self.updateStatus(for: id, status: .cancelled)
            } catch {
                await self.updateStatus(for: id, status: .failed, error: error.localizedDescription)
            }
            await self.finishJob(id)
        }
    }

    private func finishJob(_ id: UUID) {
        tasks[id] = nil
        activeConversionCount = max(0, activeConversionCount - 1)
        pumpQueue()
    }

    /// Stop a single job (kills the ffmpeg process if it is already running).
    func cancel(job: ConversionJob) {
        if let task = tasks[job.id] {
            task.cancel()
        } else if job.status == .queued || job.status == .preparing {
            updateStatus(for: job.id, status: .cancelled)
        }
    }

    /// Stop every job that hasn't finished yet. Running jobs are cancelled via
    /// their task; jobs still waiting in the queue (no task yet) are marked
    /// cancelled directly so `pumpQueue` won't pick them up afterwards.
    func cancelAll() {
        for task in tasks.values { task.cancel() }
        for job in jobs where job.status == .queued {
            updateStatus(for: job.id, status: .cancelled)
        }
    }

    var hasActiveJobs: Bool {
        jobs.contains { $0.status == .queued || $0.status == .preparing || $0.status == .converting }
    }

    func clearCompleted() {
        jobs.removeAll { $0.status == .completed }
    }

    func remove(job: ConversionJob) {
        tasks[job.id]?.cancel()
        tasks[job.id] = nil
        jobs.removeAll { $0.id == job.id }
    }
    
    private func updateStatus(for id: UUID, status: ConversionJob.Status, progress: Double? = nil, error: String? = nil) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].status = status
            if let progress { jobs[index].progress = progress }
            if let error { jobs[index].errorDescription = error }
        }
    }
    
    private func getDestinationURL(for file: AudioFile, settings: ConversionSettings, outputFolder: URL, sourceRoot: URL?) -> URL {
        let sourceURL = file.url
        let newName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = settings.outputFormat.rawValue

        if settings.preserveFolderStructure, let root = sourceRoot {
            let relativeDir = Self.relativeDirectory(of: sourceURL, from: root)
            let targetDir = relativeDir.isEmpty ? outputFolder : outputFolder.appendingPathComponent(relativeDir)
            return targetDir.appendingPathComponent(newName).appendingPathExtension(ext)
        }
        return outputFolder.appendingPathComponent(newName).appendingPathExtension(ext)
    }

    /// Deepest directory that contains every URL in the batch. Used as the base
    /// for recreating the source folder tree under the output folder.
    private static func commonAncestor(of urls: [URL]) -> URL? {
        guard let first = urls.first else { return nil }
        var ancestor = first.deletingLastPathComponent().standardizedFileURL.pathComponents
        for url in urls.dropFirst() {
            let comps = url.deletingLastPathComponent().standardizedFileURL.pathComponents
            var i = 0
            while i < ancestor.count, i < comps.count, ancestor[i] == comps[i] { i += 1 }
            ancestor = Array(ancestor.prefix(i))
        }
        guard !ancestor.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString.path(withComponents: ancestor))
    }

    /// Path of `fileURL`'s parent directory relative to `root` (empty when the
    /// file sits directly in `root`).
    private static func relativeDirectory(of fileURL: URL, from root: URL) -> String {
        let fileDir = fileURL.deletingLastPathComponent().standardizedFileURL.pathComponents
        let rootComps = root.standardizedFileURL.pathComponents
        guard fileDir.count > rootComps.count,
              Array(fileDir.prefix(rootComps.count)) == rootComps else { return "" }
        return fileDir.suffix(fileDir.count - rootComps.count).joined(separator: "/")
    }
}
