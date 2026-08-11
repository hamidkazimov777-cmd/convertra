import Foundation
import Combine
import SwiftUI

@MainActor
final class ConversionQueueViewModel: ObservableObject {
    @Published private(set) var jobs: [ConversionJob] = []
    @Published var selectedTargetFormat: ConversionSettings.OutputFormat = .mp3
    /// Last destination folder chosen this session — reused so batch conversions
    /// don't re-prompt for a folder every single time.
    @Published var lastOutputFolder: URL?
    
    private let engine = AudioConversionEngine()
    /// Running conversion tasks by job id, so a job can be cancelled mid-flight.
    private var tasks: [UUID: Task<Void, Never>] = [:]

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
        let newJobs = files.map { file in
            let destURL = getDestinationURL(for: file, settings: settings, outputFolder: outputFolder)
            return ConversionJob(
                sourceURL: file.url,
                destinationURL: destURL,
                settings: settings
            )
        }
        jobs.append(contentsOf: newJobs)
        startAll()
    }
    
    func startAll() {
        let pendingJobs = jobs.filter { $0.status == .queued || $0.status == .failed }
        for job in pendingJobs {
            updateStatus(for: job.id, status: .preparing)
            let id = job.id
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
                await self.clearTask(id)
            }
        }
    }

    /// Stop a single job (kills the ffmpeg process if it is already running).
    func cancel(job: ConversionJob) {
        if let task = tasks[job.id] {
            task.cancel()
        } else if job.status == .queued || job.status == .preparing {
            updateStatus(for: job.id, status: .cancelled)
        }
    }

    /// Stop every job that hasn't finished yet.
    func cancelAll() {
        for task in tasks.values { task.cancel() }
    }

    var hasActiveJobs: Bool {
        jobs.contains { $0.status == .queued || $0.status == .preparing || $0.status == .converting }
    }

    private func clearTask(_ id: UUID) {
        tasks[id] = nil
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
    
    private func getDestinationURL(for file: AudioFile, settings: ConversionSettings, outputFolder: URL) -> URL {
        let sourceURL = file.url
        let newName = sourceURL.deletingPathExtension().lastPathComponent
        return outputFolder.appendingPathComponent(newName).appendingPathExtension(settings.outputFormat.rawValue)
    }
}
