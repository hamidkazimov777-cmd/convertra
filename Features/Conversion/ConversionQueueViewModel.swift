import Foundation
import Combine
import SwiftUI

@MainActor
final class ConversionQueueViewModel: ObservableObject {
    @Published private(set) var jobs: [ConversionJob] = []
    @Published var selectedTargetFormat: ConversionSettings.OutputFormat = .mp3
    
    private let engine = AudioConversionEngine()
    
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
            Task {
                do {
                    updateStatus(for: job.id, status: .converting)
                    try await engine.convert(job: job)
                    updateStatus(for: job.id, status: .completed, progress: 1.0)
                } catch {
                    updateStatus(for: job.id, status: .failed, error: error.localizedDescription)
                }
            }
        }
    }
    
    func clearCompleted() {
        jobs.removeAll { $0.status == .completed }
    }
    
    func remove(job: ConversionJob) {
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
