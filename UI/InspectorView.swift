import SwiftUI
import AppKit

struct InspectorView: View {
    @EnvironmentObject private var appState: AppViewModel
    @State private var selectedTab: Tab = .info
    
    enum Tab {
        case info
        case metadata
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tabs
            HStack(spacing: 0) {
                InspectorTabButton(title: "Info", isSelected: selectedTab == .info) { selectedTab = .info }
                InspectorTabButton(title: "Metadata", isSelected: selectedTab == .metadata) { selectedTab = .metadata }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider().background(Theme.Colors.border).padding(.top, 8)
            
            if appState.selectedAudioFileCount == 0 {
                Spacer()
                Text("No track selected")
                    .foregroundStyle(Theme.Colors.textMuted)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .info:
                            InspectorInfoTab()
                        case .metadata:
                            InspectorMetadataTab()
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: Theme.Layout.inspectorWidth)
        .background(Theme.Colors.bgBase)
    }
}

// MARK: - Tabs

struct InspectorInfoTab: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        if let file = appState.library.first(where: { appState.selectedAudioFileIDs.contains($0.id) }) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    if let artworkURL = file.metadata.artworkLocation, let nsImage = NSImage(contentsOf: artworkURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.bgHover)
                            VStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                Text("No Artwork")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .frame(width: 64, height: 64)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.displayTitle)
                            .font(.inter(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(file.displayArtist)
                            .font(.inter(size: 13))
                            .foregroundStyle(Theme.Colors.accentPrimary)
                        Text(file.metadata.album?.isEmpty == false ? file.metadata.album! : "Unknown Album")
                            .font(.inter(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                
                // Waveform Placeholder
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.bgPrimary)
                        .frame(height: 40)
                        .overlay(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 20))
                                path.addLine(to: CGPoint(x: 260, y: 20))
                            }
                            .stroke(Theme.Colors.accentPrimary, style: StrokeStyle(lineWidth: 1, dash: [2]))
                        )
                    HStack {
                        Text("0:00").font(.inter(size: 10))
                        Spacer()
                        Text(file.displayDuration).font(.inter(size: 10))
                    }
                    .foregroundStyle(Theme.Colors.textMuted)
                }
                
                // Tech Grid
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 16) {
                    TechInfoCell(label: "Key", value: file.analysis?.musicalKey?.rawValue ?? "-")
                    TechInfoCell(label: "BPM", value: file.analysis?.bpm.map { String(format: "%.0f", $0) } ?? "-")
                    TechInfoCell(label: "Loudness", value: "-")
                    TechInfoCell(label: "Format", value: file.displayCodec)
                    TechInfoCell(label: "Sample Rate", value: file.displaySampleRate)
                    TechInfoCell(label: "Bit Depth", value: "-")
                    TechInfoCell(label: "Channels", value: "Stereo")
                    TechInfoCell(label: "Bitrate", value: file.displayBitrate)
                }
            }
        }
    }
}

struct InspectorMetadataTab: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            MetadataTextField(label: "Title", field: binding(\.title))
            MetadataTextField(label: "Artist", field: binding(\.artist))
            MetadataTextField(label: "Album", field: binding(\.album))
            MetadataTextField(label: "Genre", field: binding(\.genre))
            MetadataTextField(label: "Year", field: binding(\.year))
            MetadataTextField(label: "Track", field: binding(\.trackNumber))
            MetadataTextField(label: "Comment", field: binding(\.comments))
            MetadataTextField(label: "Composer", field: binding(\.composer))
            MetadataTextField(label: "ISRC", field: binding(\.isrc))
            
            Text("Changes will be written to the original audio file.")
                .font(.inter(size: 10))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
            
            Button("Save Metadata") {
                appState.applyMetadataEditDraft()
            }
            .buttonStyle(AccentButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .onAppear(perform: appState.prepareMetadataEditDraft)
        .onChange(of: appState.selectedAudioFileIDs) { _ in
            appState.prepareMetadataEditDraft()
        }
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<MetadataEditDraft, T>) -> Binding<T> {
        Binding(
            get: { appState.metadataEditDraft[keyPath: keyPath] },
            set: { appState.metadataEditDraft[keyPath: keyPath] = $0 }
        )
    }
}



// MARK: - Components

struct InspectorTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.inter(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : Theme.Colors.textSecondary)
                
                Rectangle()
                    .fill(isSelected ? Theme.Colors.accentPrimary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct TechInfoCell: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.inter(size: 9, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
            Text(value)
                .font(.inter(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

struct MetadataTextField: View {
    let label: String
    @Binding var field: MetadataEditField
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label.uppercased())
                    .font(.inter(size: 9, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                Spacer()
                Toggle("", isOn: $field.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            
            TextField("", text: $field.value)
                .textFieldStyle(.plain)
                .font(.inter(size: 13))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.bgPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Theme.Colors.border, lineWidth: 1)
                        )
                )
                .disabled(!field.isEnabled)
                .opacity(field.isEnabled ? 1.0 : 0.5)
        }
    }
}
