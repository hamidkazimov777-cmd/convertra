import Foundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var currentTrack: AudioFile?
    @Published private(set) var waveformData: [Float] = []
    @Published private(set) var isGeneratingWaveform = false
    
    @Published private(set) var isPlaying = false
    @Published var currentPosition: TimeInterval = 0 {
        didSet {
            // Only seek if the user is scrubbing, not from normal playback updates
            // In a real app we'd differentiate between user interaction and engine updates,
            // but for simplicity we'll add a separate seek method.
        }
    }
    @Published private(set) var duration: TimeInterval = 0
    @Published var volume: Float = 1.0 {
        didSet {
            engine.volume = volume
        }
    }
    
    private let engine = AudioPlayerEngine()
    private let waveformAnalyzer = WaveformAnalyzer()
    private var waveformGenerationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var isEngineUpdatingPosition = false
    
    init() {
        engine.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPlaying)
            
        engine.$currentPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.isEngineUpdatingPosition = true
                self?.currentPosition = position
                self?.isEngineUpdatingPosition = false
            }
            .store(in: &cancellables)
            
        engine.$duration
            .receive(on: DispatchQueue.main)
            .assign(to: &$duration)
            
        volume = engine.volume
    }
    
    func handleSelectionChange(selectedFiles: [AudioFile]) {
        let firstFile = selectedFiles.first
        if currentTrack?.id != firstFile?.id {
            waveformGenerationTask?.cancel()
            waveformData = []
            
            currentTrack = firstFile
            if let url = firstFile?.url {
                engine.load(url: url)
                generateWaveform(for: url)
            } else {
                engine.stop()
            }
        }
    }
    
    private func generateWaveform(for url: URL) {
        isGeneratingWaveform = true
        waveformGenerationTask = Task {
            do {
                let data = try await waveformAnalyzer.generateWaveform(for: url, targetSampleCount: 150)
                if !Task.isCancelled {
                    self.waveformData = data.samples
                    self.isGeneratingWaveform = false
                }
            } catch {
                if !Task.isCancelled {
                    self.isGeneratingWaveform = false
                }
            }
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
    }
    
    func play() {
        engine.play()
    }
    
    func stop() {
        engine.stop()
    }
    
    func seek(to time: TimeInterval) {
        guard !isEngineUpdatingPosition else { return }
        engine.seek(to: time)
    }
}
