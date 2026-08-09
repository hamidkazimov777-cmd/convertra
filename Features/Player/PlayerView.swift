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
            
            // Waveform placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(height: 120)
                
                Text("Waveform Preview (Future)")
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            
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
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentTrack == nil)
                    
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentTrack == nil)
                    
                    // Volume
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.volume, in: 0...1)
                            .frame(width: 80)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
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
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
