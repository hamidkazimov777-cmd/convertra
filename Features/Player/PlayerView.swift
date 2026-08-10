import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            // Track Info
            VStack(spacing: 8) {
                if let track = viewModel.currentTrack {
                    Text(track.metadata.title ?? track.url.lastPathComponent)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Text(track.metadata.artist ?? "Unknown Artist")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No Track Selected")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Select a track in the library")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Waveform
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                if viewModel.isGeneratingWaveform {
                    ProgressView()
                        .controlSize(.regular)
                } else if !viewModel.waveformData.isEmpty {
                    GeometryReader { geo in
                        let progress = viewModel.duration > 0 ? CGFloat(viewModel.currentPosition / viewModel.duration) : 0
                        
                        WaveformShape(samples: viewModel.waveformData)
                            .fill(Color.secondary.opacity(0.2))
                        
                        WaveformShape(samples: viewModel.waveformData)
                            .fill(LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .mask(
                                Rectangle()
                                    .frame(width: geo.size.width * progress)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            )
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 24))
                        Text("No Waveform Data")
                            .font(.callout)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 140)
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Controls
            VStack(spacing: 24) {
                // Scrubber
                HStack {
                    Text(formatTime(viewModel.currentPosition))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    
                    Slider(
                        value: Binding(
                            get: { viewModel.currentPosition },
                            set: { viewModel.seek(to: $0) }
                        ),
                        in: 0...(viewModel.duration > 0 ? viewModel.duration : 1)
                    )
                    .disabled(viewModel.currentTrack == nil || viewModel.duration == 0)
                    
                    Text(formatTime(viewModel.duration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                }
                
                // Playback Buttons
                HStack(spacing: 32) {
                    Button(action: { viewModel.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentTrack == nil)
                    .accessibilityLabel("Stop Playback")
                    
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(viewModel.currentTrack == nil ? .secondary.opacity(0.5) : Color.accentColor)
                            .shadow(color: viewModel.isPlaying ? Color.accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentTrack == nil)
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                    
                    // Volume
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        Slider(value: $viewModel.volume, in: 0...1)
                            .frame(width: 100)
                            .tint(.secondary)
                            .accessibilityLabel("Volume")
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding(.leading, 16)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding()
        .onChange(of: appState.selectedAudioFileIDs) { _ in
            viewModel.handleSelectionChange(selectedFiles: appState.selectedAudioFiles)
        }
        .onAppear {
            viewModel.handleSelectionChange(selectedFiles: appState.selectedAudioFiles)
        }
        .navigationTitle("Player")
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WaveformShape: Shape {
    let samples: [Float]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }
        
        let width = rect.width / CGFloat(samples.count)
        let midY = rect.midY
        let height = rect.height
        
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * width
            let sampleHeight = CGFloat(sample) * height
            
            let barRect = CGRect(
                x: x,
                y: midY - sampleHeight / 2,
                width: max(1, width - 1),
                height: max(2, sampleHeight)
            )
            
            path.addRoundedRect(in: barRect, cornerSize: CGSize(width: 2, height: 2))
        }
        
        return path
    }
}
