import SwiftUI
import AppKit

struct BottomPlayerView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var viewModel = PlayerViewModel()
    @EnvironmentObject private var conversionQueue: ConversionQueueViewModel
    @EnvironmentObject private var loc: Localization
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Track Info
            trackInfoSection
                .frame(width: Theme.Layout.sidebarWidth + 20) // Give it enough space
            
            // Center: Player Controls & Waveform
            HStack(spacing: 16) {
                playbackControls
                
                // Энергетическая волна-скраббер
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.Colors.bgBase.opacity(0.6))
                        .hairline(8, color: Theme.Colors.borderSubtle)

                    if viewModel.currentTrack != nil {
                        if viewModel.isGeneratingWaveform {
                            ProgressView().controlSize(.small).tint(Theme.Colors.accentPrimary)
                        } else if !viewModel.waveformData.isEmpty {
                            GeometryReader { geo in
                                let progress = viewModel.duration > 0 ? CGFloat(viewModel.currentPosition / viewModel.duration) : 0

                                EnergyWaveformView(samples: viewModel.waveformData, progress: progress)
                                    .animation(.linear(duration: 0.1), value: progress)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let percentage = max(0, min(1, (value.location.x - 8) / (geo.size.width - 16)))
                                                viewModel.seek(to: viewModel.duration * Double(percentage))
                                            }
                                    )
                            }
                        } else {
                            Path { path in
                                path.move(to: CGPoint(x: 8, y: 20))
                                path.addLine(to: CGPoint(x: 1000, y: 20))
                            }
                            .stroke(Theme.Colors.textMuted.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                        }

                        // Тайминги
                        HStack {
                            Text(formatTime(viewModel.currentPosition))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(formatTime(viewModel.duration))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)
                    }
                }
                .frame(height: 48)
                
                // Volume
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").font(.inter(size: 10))
                    Slider(value: $viewModel.volume, in: 0...1).frame(width: 80)
                        .tint(Theme.Colors.accentPrimary)
                    Image(systemName: "speaker.wave.3.fill").font(.inter(size: 10))
                }
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 16)
            
            // Right: Conversion Status
            conversionStatusSection
                .frame(width: Theme.Layout.inspectorWidth)
        }
        .frame(height: Theme.Layout.playerHeight)
        .background(Theme.Colors.bgBase)
        .onChange(of: appState.selectedAudioFileIDs) { _ in
            viewModel.handleSelectionChange(selectedFiles: appState.selectedAudioFiles)
        }
        .onChange(of: appState.requestedPlaybackTrackID) { newID in
            if newID != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.play()
                }
            }
        }
        .onChange(of: appState.playbackToggleTrigger) { _ in
            viewModel.togglePlayback()
        }
        .onAppear {
            viewModel.handleSelectionChange(selectedFiles: appState.selectedAudioFiles)
        }
    }
    
    // MARK: - Sections
    
    private var trackInfoSection: some View {
        HStack(spacing: 12) {
            if let track = viewModel.currentTrack, let artworkURL = track.metadata.artworkLocation, let nsImage = NSImage(contentsOf: artworkURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.bgHover)
                    Image(systemName: "music.note")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .frame(width: 50, height: 50)
            }
            
            if let track = viewModel.currentTrack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(track.displayTitle)
                            .font(.inter(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "star")
                            .font(.inter(size: 10))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    
                    Text(track.displayArtist)
                        .font(.inter(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(track.displayCodec)
                        Text("|")
                        Text(track.displaySampleRate)
                        Text("|")
                        Text("Stereo")
                    }
                    .font(.inter(size: 9))
                    .foregroundStyle(Theme.Colors.textMuted)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc["Трек не выбран"])
                        .font(.inter(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            Spacer()
        }
        .padding(.leading, 16)
    }
    
    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button(action: {}) {
                Image(systemName: "shuffle")
                    .font(.inter(size: 14))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                if viewModel.currentPosition > 2.0 {
                    viewModel.seek(to: 0)
                } else {
                    appState.selectPreviousTrack()
                }
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.inter(size: 14))
                    .foregroundStyle(viewModel.currentTrack == nil ? Theme.Colors.textMuted : Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentTrack == nil)
            
            Button(action: { viewModel.togglePlayback() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    // White reads on the violet gradient; on the inactive grey
                    // circle fall back to a themed colour so it stays visible in
                    // light mode.
                    .foregroundStyle(viewModel.currentTrack == nil ? Theme.Colors.textSecondary : .white)
                    .frame(width: 40, height: 40)
                    .background(
                        ZStack {
                            Circle().fill(viewModel.currentTrack == nil
                                ? AnyShapeStyle(Theme.Colors.bgHover)
                                : AnyShapeStyle(Theme.Colors.accentGradient))
                            Circle().fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                                         startPoint: .top, endPoint: .bottom))
                        }
                    )
                    .accentGlow(viewModel.currentTrack == nil ? 0 : 0.8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentTrack == nil)
            
            Button(action: {
                appState.selectNextTrack()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.inter(size: 14))
                    .foregroundStyle(viewModel.currentTrack == nil ? Theme.Colors.textMuted : Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentTrack == nil)
            
            Button(action: {}) {
                Image(systemName: "repeat")
                    .font(.inter(size: 14))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var conversionStatusSection: some View {
        HStack {
            Spacer()
            
            if conversionQueue.totalJobs > 0 {
                HStack(spacing: 12) {
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Theme.Colors.bgHover, lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: conversionQueue.overallProgress)
                            .stroke(Theme.Colors.accentPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(conversionQueue.overallProgress * 100))%")
                            .font(.inter(size: 9, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc["Очередь конвертации"])
                            .font(.inter(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        
                        Text("\(conversionQueue.completedJobs)/\(conversionQueue.totalJobs) \(loc["файлов"])")
                            .font(.inter(size: 10))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: conversionQueue.isProcessing ? "pause.fill" : "play.fill")
                            .font(.inter(size: 12))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(8)
                            .background(Circle().fill(Theme.Colors.bgPrimary))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 24)
            } else {
                Text(loc["Очередь пуста"])
                    .font(.inter(size: 11))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.trailing, 24)
            }
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
